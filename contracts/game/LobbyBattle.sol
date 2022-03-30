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
    uint256 winner; // 1: host, 2 : client, 0: in-progress
  }

  struct LobbyRefreshInfo {
    uint256 updatedAt;
    uint256 limit;
  }

  Counters.Counter private lobbyIterator;

  IHeroManager public heroManager;

  IERC20 public token;
  IERC721 public nft;

  address public rewardsPayeer;

  uint256 private benefitMultiplier = 250;

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
      token.transferFrom(msg.sender, rewardsPayeer, lobbyFees[lobby.capacity]),
      "LobbyBattle: not enough fee"
    );

    validateHeroIds(heroIds);

    lobby.client = msg.sender;
    lobby.finishedAt = block.timestamp;

    if (lobby.capacity == 1) {
      lobby.winner = contest1vs1(lobby.hostHeros, heroIds);
      if (lobby.winner == 1) {
        heroManager.bulkExpUp(lobby.hostHeros);
        heroManager.bulkExpDown(heroIds);
      } else {
        heroManager.bulkExpDown(lobby.hostHeros);
        heroManager.bulkExpUp(heroIds);
      }
    }

    lobby.clientHeros = heroIds;
    lobbies[lobbyId] = lobby;

    token.transferFrom(
      rewardsPayeer,
      lobby.winner == 1 ? lobby.host : lobby.client,
      (lobbyFees[lobby.capacity] * benefitMultiplier) / 100
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

  function getLobbies(
    address account,
    uint256 hostOrClient,
    uint256 runningOrDone
  ) public view returns (uint256[] memory) {
    uint256[] memory lobbyIds;
    if (hostOrClient == 0) {
      // all
      uint256 index = 0;
      for (uint256 i = 1; i <= lobbyIterator.current(); i++) {
        if (runningOrDone == 0) {
          lobbyIds[i - 1] = i;
        } else if (runningOrDone == 1) {
          // running
          if (lobbies[i].startedAt != 0 && lobbies[i].finishedAt == 0) {
            lobbyIds[index++] = i;
          }
        } else {
          // done
          if (lobbies[i].startedAt != 0 && lobbies[i].finishedAt != 0) {
            lobbyIds[index++] = i;
          }
        }
      }
    } else if (hostOrClient == 1) {
      // lobbies I created
      uint256 index = 0;
      for (uint256 i = 1; i <= lobbyIterator.current(); i++) {
        if (lobbies[i].host == account) {
          if (runningOrDone == 0) {
            lobbyIds[index++] = i;
          } else if (runningOrDone == 1) {
            if (lobbies[i].startedAt != 0 && lobbies[i].finishedAt == 0) {
              lobbyIds[index++] = i;
            }
          } else {
            // done
            if (lobbies[i].startedAt != 0 && lobbies[i].finishedAt != 0) {
              lobbyIds[index++] = i;
            }
          }
        }
      }
    } else if (hostOrClient == 2) {
      // lobbies I joined
      uint256 index = 0;
      for (uint256 i = 1; i <= lobbyIterator.current(); i++) {
        if (lobbies[i].client == account) {
          if (runningOrDone == 0) {
            lobbyIds[index++] = i;
          } else if (runningOrDone == 1) {
            if (lobbies[i].startedAt != 0 && lobbies[i].finishedAt == 0) {
              lobbyIds[index++] = i;
            }
          } else {
            // done
            if (lobbies[i].startedAt != 0 && lobbies[i].finishedAt != 0) {
              lobbyIds[index++] = i;
            }
          }
        }
      }
    }

    return lobbyIds;
  }

  function setRewardsPayeer(address payer) external onlyOwner {
    rewardsPayeer = payer;
  }
}
