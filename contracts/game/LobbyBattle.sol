// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "./HeroManager.sol";
import "./Randomness.sol";
import "../interfaces/IHeroManager.sol";

/** Logic for lobby battle */
contract LobbyBattle is Ownable, Multicall, Randomness {
  using Counters for Counters.Counter;

  struct Lobby {
    bytes32 name;
    bytes32 avatar;
    address host;
    address client;
    uint256 id;
    uint256 capacity;
    uint256 startedAt;
    uint256 finishedAt;
    uint256 winner; // 1: host, 2 : client, 0: in-progress
    uint256 fee;
    uint256 rewards;
    uint256[] hostHeros;
    uint256[] clientHeros;
  }

  struct LobbyRefreshInfo {
    uint256 updatedAt;
    uint256 limit;
  }

  Counters.Counter private lobbyIterator;

  IHeroManager public heroManager =
    IHeroManager(0x0c966628e4828958376a24ee66F5278A71c96aeE);

  IERC20 public token;
  IERC721 public nft;

  address public rewardsPayeer;

  uint256 private benefitMultiplier = 250;

  uint256 public bonusExp = 30; // From Level 1, every battle win will give 30 exp to the hero. And as level goes up, this will be reduced. Level 1 -> 2: 30, Lv 2 -> 3: 29, ...., Lv 29 -> 30: 2

  // lobbiesRefreshed[capacity (1, 3, 5)][address] = LobbyRefreshInfo
  mapping(uint256 => mapping(address => LobbyRefreshInfo))
    public lobbiesRefreshed;

  mapping(uint256 => uint256) public lobbyFees;

  mapping(uint256 => Lobby) public lobbies;

  constructor() {
    lobbyFees[1] = 5000 * 10**18;
    lobbyFees[3] = 25000 * 10**18;
    lobbyFees[5] = 50000 * 10**18;
  }

  function createLobby(
    uint256 capacity,
    bytes32 name,
    bytes32 avatar,
    uint256[] calldata heroIds
  ) public {
    validateHeroIds(heroIds);

    require(capacity == heroIds.length, "LobbyBattle: wrong parameters");
    require(lobbyFees[capacity] > 0, "LobbyBattle: wrong lobby capacity");
    require(
      token.transferFrom(msg.sender, rewardsPayeer, lobbyFees[capacity]),
      "LobbyBattle: not enough fee"
    );

    uint256[] memory emptyArray;

    lobbyIterator.increment();

    uint256 lobbyId = lobbyIterator.current();

    Lobby memory lobby = Lobby(
      name,
      avatar,
      msg.sender,
      address(0),
      lobbyId,
      capacity,
      block.timestamp,
      0,
      0,
      lobbyFees[capacity],
      0,
      heroIds,
      emptyArray
    );

    lobbies[lobbyId] = lobby;
  }

  function joinLobby(uint256 lobbyId, uint256[] calldata heroIds) public {
    require(lobbies[lobbyId].id == lobbyId, "LobbyBattle: lobby doesn't exist");
    require(
      lobbies[lobbyId].capacity == heroIds.length,
      "LobbyBattle: wrong heroes"
    );
    require(lobbies[lobbyId].finishedAt == 0, "LobbyBattle: already finished");
    require(
      token.transferFrom(
        msg.sender,
        rewardsPayeer,
        lobbyFees[lobbies[lobbyId].capacity]
      ),
      "LobbyBattle: not enough fee"
    );

    validateHeroIds(heroIds);

    lobbies[lobbyId].client = msg.sender;
    lobbies[lobbyId].finishedAt = block.timestamp;

    if (lobbies[lobbyId].capacity == 1) {
      lobbies[lobbyId].winner = contest1vs1(
        lobbies[lobbyId].hostHeros,
        heroIds
      );
      if (lobbies[lobbyId].winner == 1) {
        heroManager.bulkExpUp(
          lobbies[lobbyId].hostHeros,
          heroBonusExp(lobbies[lobbyId].hostHeros[0])
        );
        heroManager.bulkExpUp(
          lobbies[lobbyId].clientHeros,
          heroBonusExp(lobbies[lobbyId].clientHeros[0]) / 2
        );
      } else {
        heroManager.bulkExpUp(
          lobbies[lobbyId].hostHeros,
          heroBonusExp(lobbies[lobbyId].hostHeros[0]) / 2
        );
        heroManager.bulkExpUp(
          lobbies[lobbyId].clientHeros,
          heroBonusExp(lobbies[lobbyId].clientHeros[0])
        );
      }
    }

    lobbies[lobbyId].clientHeros = heroIds;
    lobbies[lobbyId].rewards =
      (lobbyFees[lobbies[lobbyId].capacity] * benefitMultiplier) /
      100;

    token.transferFrom(
      rewardsPayeer,
      lobbies[lobbyId].winner == 1
        ? lobbies[lobbyId].host
        : lobbies[lobbyId].client,
      lobbies[lobbyId].rewards
    );
  }

  function validateHeroIds(uint256[] calldata heroIds) public view {
    for (uint256 i = 0; i < heroIds.length; i++) {
      require(
        nft.ownerOf(heroIds[i]) == msg.sender,
        "LobbyBattle: not hero owner"
      );
    }
  }

  function contest1vs1(
    uint256[] memory hostHeroes,
    uint256[] memory clientHeroes
  ) internal view returns (uint256) {
    uint256 hostHero = hostHeroes[0];
    uint256 clientHero = clientHeroes[0];

    uint256 hostHeroPower = heroManager.heroPower(hostHero);
    uint256 clientHeroPower = heroManager.heroPower(clientHero);

    uint256 hostHeroPrimaryAttribute = heroManager.heroPrimaryAttribute(
      hostHero
    );
    uint256 hostHeroLevel = heroManager.heroLevel(hostHero);

    uint256 clientHeroPrimaryAttribute = heroManager.heroPrimaryAttribute(
      clientHero
    );
    uint256 clientHeroLevel = heroManager.heroLevel(clientHero);

    // strength vs strength, agility vs agility or intelligence vs intelligence
    if (hostHeroPrimaryAttribute == clientHeroPrimaryAttribute) {
      if (hostHeroLevel > clientHeroLevel) {
        if (hostHeroPower > clientHeroPower) {
          return 1; // host win
        } else if (hostHeroPower == clientHeroPower) {
          uint256 dice = random(1, 100);
          if (dice <= 60) {
            return 1; // host win
          }
          return 2; // client win
        } else {
          uint256 dice = random(1, 100);
          if (dice <= 70) {
            return 2; // client win
          }
          return 1; // host win
        }
      } else if (hostHeroLevel == clientHeroLevel) {
        if (hostHeroPower > clientHeroPower) {
          uint256 dice = random(1, 100);
          if (dice <= 70) {
            return 1; // host win
          }
          return 2; // client win
        } else if (hostHeroPower == clientHeroPower) {
          return uint256(random(1, 2));
        } else {
          uint256 dice = random(1, 100);
          if (dice <= 70) {
            return 2; // client win
          }
          return 1; // host win
        }
      } else {
        if (hostHeroPower < clientHeroPower) {
          return 2; // client win
        } else if (hostHeroPower == clientHeroPower) {
          uint256 dice = random(1, 100);
          if (dice <= 60) {
            return 2; // client win
          }
          return 1; // host win
        } else {
          uint256 dice = random(1, 100);
          if (dice <= 70) {
            return 1; // host win
          }
          return 2; // client win
        }
      }
    } else {
      // same level
      if (hostHeroLevel == clientHeroLevel) {
        if (hostHeroPower > clientHeroPower) {
          // same level but strength's power is greater than agility: 70% chance for strength, 30% for agility

          uint256 dice = random(1, 100);
          if (dice > 70) {
            return 1; // host: strength win
          }
          return 2; // client: agility win
        } else if (hostHeroPower == clientHeroPower) {
          // same level and same power

          return uint256(random(1, 2)); // 50%:50%
        } else {
          // same level but agility's power is greater than strength: 80% chance for agility, 20% for strength
          uint256 dice = random(1, 100);
          if (dice <= 20) {
            return 1; // host: strength win
          }
          return 2; // client: agility win
        }
      } else if (hostHeroLevel > clientHeroLevel) {
        // strength level is higher

        if (hostHeroPower > clientHeroPower) {
          // strength's level and power is greater than agility
          return 1; // strength win always
        } else {
          // strength level is greater than agility but power is less than or equal: 40% for strength, 60% for agility
          uint256 dice = random(1, 100);
          if (dice <= 40) {
            return 1; // host: strength win
          }
          return 2; // client: agility win
        }
      } else {
        // agility level is higher

        if (hostHeroPower < clientHeroPower) {
          return 2; // agility win
        } else if (hostHeroPower == clientHeroPower) {
          // same power. 70% for agility and 30% for strength

          uint256 dice = random(1, 100);
          if (dice <= 30) {
            return 1; // host: strength win
          }
          return 2; // client: agility win
        } else {
          // agility level is higher but power is less

          uint256 dice = random(1, 100);
          if (dice <= 60) {
            return 1; // host: strength win
          }
          return 2; // client: agility win
        }
      }
    }
  }

  function getActiveLobbies(address myAddr)
    public
    view
    returns (uint256[] memory)
  {
    uint256[] memory lobbyIds;

    uint256 baseIndex = 0;
    for (uint256 i = 1; i <= lobbyIterator.current(); i++) {
      if (lobbies[i].finishedAt == 0 && lobbies[i].host != myAddr) {
        lobbyIds[baseIndex++] = i;
      }
    }

    return lobbyIds;
  }

  function getMyLobbies(address myAddr) public view returns (uint256[] memory) {
    uint256[] memory lobbyIds;

    uint256 baseIndex = 0;
    for (uint256 i = 1; i <= lobbyIterator.current(); i++) {
      if (lobbies[i].finishedAt == 0 && lobbies[i].host == myAddr) {
        lobbyIds[baseIndex++] = i;
      }
    }

    return lobbyIds;
  }

  function getMyHistory(address myAddr) public view returns (uint256[] memory) {
    uint256[] memory lobbyIds;

    uint256 baseIndex = 0;
    for (uint256 i = 1; i <= lobbyIterator.current(); i++) {
      if (
        lobbies[i].finishedAt > 0 &&
        (lobbies[i].host == myAddr || lobbies[i].client == myAddr)
      ) {
        lobbyIds[baseIndex++] = i;
      }
    }

    return lobbyIds;
  }

  function getAllHistory() public view returns (uint256[] memory) {
    uint256[] memory lobbyIds;

    uint256 baseIndex = 0;
    for (uint256 i = 1; i <= lobbyIterator.current(); i++) {
      if (lobbies[i].finishedAt > 0) {
        lobbyIds[baseIndex++] = i;
      }
    }

    return lobbyIds;
  }

  function heroBonusExp(uint256 heroId) public view returns (uint256) {
    return bonusExp - heroManager.heroLevel(heroId) + 1;
  }

  function setRewardsPayeer(address payer) external onlyOwner {
    rewardsPayeer = payer;
  }

  function setBonusExp(uint256 value) external onlyOwner {
    bonusExp = value;
  }
}
