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
    uint256 id;
    address host;
    address client;
    uint256 capacity;
    uint256[] hostHeros;
    uint256[] clientHeros;
    uint256 startedAt;
    uint256 finishedAt;
    uint8 winner; // 1: host, 2 : client, 0: in-progress
  }

  struct LobbyRefreshInfo {
    uint256 updatedAt;
    uint8 limit;
  }

  Counters.Counter private lobbyIterator;

  IHeroManager public heroManager;

  IERC20 public token;
  IERC721 public nft;

  uint256 private benefitMultiplier = 2.5;

  // lobbiesRefreshed[capacity (1, 3, 5)][address] = LobbyRefreshInfo
  mapping(uint256 => mapping(address => LobbyRefreshInfo))
    public lobbiesRefreshed;

  mapping(uint256 => uint256) public lobbyFees;

  mapping(uint256 => Lobby) public lobbies;

  constructor(address heroManagerAddress) {
    heroManager = IHeroManager(heroManagerAddress);

    lobbyFees[1] = 5000 * 10**18;
    lobbyFees[3] = 25000 * 10**18;
    lobbyFees[5] = 50000 * 10**18;
  }

  function createLobby(uint256 capacity, uint256[] calldata heroIds) public {
    validateHeroIds(heroIds);

    require(capacity == heroIds.length, "LobbyBattle: wrong parameters");
    require(lobbyFees[capacity] > 0, "LobbyBattle: wrong lobby capacity");
    require(
      token.transferFrom(msg.sender, address(this), lobbyFees[capacity]),
      "LobbyBattle: not enough fee"
    );

    uint256[] memory emptyArray;

    lobbyIterator.increment();

    uint256 lobbyId = lobbyIterator.current();

    Lobby memory lobby = Lobby(
      lobbyId,
      msg.sender,
      address(0),
      capacity,
      heroIds,
      emptyArray,
      block.timestamp,
      0,
      0
    );

    lobbies[lobbyId] = lobby;
  }

  function joinLobby(uint256 lobbyId, uint256[] calldata heroIds) public {
    Lobby memory lobby = lobbies[lobbyId];
    require(lobby.id == lobbyId, "LobbyBattle: lobby doesn't exist");
    require(lobby.capacity == heroIds.length, "LobbyBattle: wrong heroes");
    require(lobby.finishedAt == 0, "LobbyBattle: already finished");
    require(
      token.transferFrom(msg.sender, address(this), lobbyFees[capacity]),
      "LobbyBattle: not enough fee"
    );

    validateHeroIds(heroIds);

    lobby.client = msg.sender;
    lobby.finishedAt = block.timestamp;
    if (lobby.capacity == 1) {
      lobby.winner = contest1vs1(lobby.hostHeros, heroIds);
    }
    lobby.clientHeros = heroIds;
    lobbies[lobbyId] = lobby;

    token.transfer(
      lobby.winner == 1 ? lobby.host : lobby.client,
      lobbyFees[capacity] * benefitMultiplier
    );
  }

  // function refreshLobby(uint256 capacity) public {
  //   LobbyRefreshInfo info = lobbiesRefreshed[capacity][msg.sender];
  //   require(
  //     info.limit < 5 || info.updatedAt + 1 days < now,
  //     "LobbyBattle: can refresh 5 times daily"
  //   );

  //   info.limit = (info.limit + 1) % 5;
  //   info.updatedAt = now;
  //   lobbiesRefreshed[capacity][msg.sender] = info;
  // }

  // function lobbiesList(uint256 capacity) public {
  //   require(
  //     info.limit < 5 || info.updatedAt + 1 days < now,
  //     "LobbyBattle: can refresh 5 times daily"
  //   );
  // }

  function validateHeroIds(uint256[] calldata heroIds) public view {
    for (uint8 i = 0; i < heroIds.length; i++) {
      require(
        nft.ownerOf(heroIds[i]) == msg.sender,
        "LobbyBattle: not hero owner"
      );
    }
  }

  function contest1vs1(
    uint256[] calldata hostHeroes,
    uint256[] calldata clientHeroes
  ) internal returns (uint8) {
    uint256 hostHero = hostHeroes[0];
    uint256 clientHero = clientHeroes[0];

    uint256 hostHeroPower = heroManager.heroPower(hostHero);
    uint256 clientHeroPower = heroManager.heroPower(clientHero);

    uint8 hostHeroPrimaryAttribute = heroManager.heroPrimaryAttribute(hostHero);
    uint8 hostHeroLevel = heroManager.heroLevel(hostHero);

    uint8 clientHeroPrimaryAttribute = heroManager.heroPrimaryAttribute(
      clientHero
    );
    uint8 clientHeroLevel = heroManager.heroLevel(clientHero);

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
          return random(1, 2);
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

          return random(1, 2); // 50%:50%
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
}
