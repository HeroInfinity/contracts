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
  }

  struct LobbyRefreshInfo {
    uint256 updatedAt;
    uint256 limit;
  }

  Counters.Counter private lobbyIterator;

  IHeroManager public heroManager =
    IHeroManager(0x51624b86523c95175d4b3d145F2Ed9f884C683E2);

  IERC20 public token = IERC20(0x28ee3E2826264b9c55FcdD122DFa93680916c9b8);
  IERC721 public nft = IERC721(0xef5A8AF5148a53a4ef4749595fe44E3E08754b8B);

  address public rewardsPayeer = 0x0cCA7943409260455CeEF6BE46c69B3fc808e24F;

  uint256 private benefitMultiplier = 250;

  uint256 public heroPowerRange = 150 * 10**18;

  uint256 public totalPlayers;
  mapping(uint256 => address) public uniquePlayers;
  mapping(address => bool) public registeredPlayers;
  mapping(address => uint256) public playersFees;
  mapping(address => uint256) public playersRewards;

  mapping(uint256 => mapping(address => mapping(uint256 => uint256)))
    public lobbyHeroes;
  mapping(uint256 => mapping(address => uint256)) public lobbyHeroesCount;
  mapping(uint256 => mapping(address => mapping(uint256 => uint256)))
    public lobbyPowers;
  mapping(uint256 => Lobby) public lobbies;
  mapping(uint256 => uint256) public lobbyFees;

  event BattleFinished(
    uint256 indexed lobbyId,
    address indexed host,
    address indexed client
  );

  constructor() {
    lobbyFees[1] = 5000 * 10**18;
    lobbyFees[3] = 25000 * 10**18;
    lobbyFees[5] = 50000 * 10**18;
  }

  function createLobby(
    bytes32 name,
    bytes32 avatar,
    uint256 capacity,
    uint256 minPower,
    uint256 maxPower,
    uint256[] calldata heroIds
  ) public {
    validateHeroIds(heroIds, msg.sender);
    require(capacity == heroIds.length, "LobbyBattle: wrong parameters");
    uint256 teamPower = getHeroesPower(heroIds);
    require(
      minPower <= teamPower &&
        maxPower >= teamPower &&
        maxPower - minPower == heroPowerRange,
      "LobbyBattle: wrong power range"
    );
    require(lobbyFees[capacity] > 0, "LobbyBattle: wrong lobby capacity");
    require(
      token.transferFrom(msg.sender, rewardsPayeer, lobbyFees[capacity]),
      "LobbyBattle: not enough fee"
    );

    if (!registeredPlayers[msg.sender]) {
      uniquePlayers[totalPlayers] = msg.sender;
      registeredPlayers[msg.sender] = true;
      totalPlayers += 1;
    }
    playersFees[msg.sender] += lobbyFees[capacity];

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
      0
    );
    lobbyPowers[lobbyId][msg.sender][0] = minPower;
    lobbyPowers[lobbyId][msg.sender][1] = maxPower;

    lobbies[lobbyId] = lobby;

    for (uint256 i = 0; i < heroIds.length; i++) {
      lobbyHeroes[lobbyId][msg.sender][i] = heroIds[i];
    }
    lobbyHeroesCount[lobbyId][msg.sender] = heroIds.length;
  }

  function joinLobby(
    uint256 lobbyId,
    uint256 minPower,
    uint256 maxPower,
    uint256[] calldata heroIds
  ) public {
    validateHeroIds(heroIds, msg.sender);

    require(lobbies[lobbyId].id == lobbyId, "LobbyBattle: lobby doesn't exist");
    require(
      lobbies[lobbyId].capacity == heroIds.length,
      "LobbyBattle: wrong heroes"
    );
    uint256 teamPower = getHeroesPower(heroIds);
    require(
      minPower <= teamPower &&
        maxPower >= teamPower &&
        maxPower - minPower == heroPowerRange,
      "LobbyBattle: wrong power range"
    );
    require(lobbies[lobbyId].finishedAt == 0, "LobbyBattle: already finished");

    uint256 fee = lobbyFees[lobbies[lobbyId].capacity];
    require(
      token.transferFrom(msg.sender, rewardsPayeer, fee),
      "LobbyBattle: not enough fee"
    );

    if (!registeredPlayers[msg.sender]) {
      uniquePlayers[totalPlayers] = msg.sender;
      registeredPlayers[msg.sender] = true;
      totalPlayers += 1;
    }
    playersFees[msg.sender] += fee;

    lobbies[lobbyId].client = msg.sender;
    lobbies[lobbyId].finishedAt = block.timestamp;
    lobbyPowers[lobbyId][msg.sender][0] = minPower;
    lobbyPowers[lobbyId][msg.sender][1] = maxPower;

    uint256[] memory hostHeroes = new uint256[](heroIds.length);

    for (uint256 i = 0; i < heroIds.length; i++) {
      lobbyHeroes[lobbyId][msg.sender][i] = heroIds[i];
      hostHeroes[i] = lobbyHeroes[lobbyId][lobbies[lobbyId].host][i];
    }
    lobbyHeroesCount[lobbyId][msg.sender] = heroIds.length;

    lobbies[lobbyId].rewards =
      (lobbyFees[lobbies[lobbyId].capacity] * benefitMultiplier) /
      100;

    if (lobbies[lobbyId].capacity == 1) {
      lobbies[lobbyId].winner = contest1vs1(hostHeroes, heroIds);
      if (lobbies[lobbyId].winner == 1) {
        heroManager.bulkExpUp(hostHeroes, true);
        heroManager.bulkExpUp(heroIds, false);

        playersRewards[lobbies[lobbyId].host] += lobbies[lobbyId].rewards;
      } else {
        heroManager.bulkExpUp(hostHeroes, false);
        heroManager.bulkExpUp(heroIds, true);

        playersRewards[msg.sender] += lobbies[lobbyId].rewards;
      }
    }

    token.transferFrom(
      rewardsPayeer,
      lobbies[lobbyId].winner == 1
        ? lobbies[lobbyId].host
        : lobbies[lobbyId].client,
      lobbies[lobbyId].rewards
    );

    emit BattleFinished(lobbyId, lobbies[lobbyId].host, msg.sender);
  }

  function validateHeroIds(uint256[] calldata heroIds, address owner)
    public
    view
    returns (bool)
  {
    for (uint256 i = 0; i < heroIds.length; i++) {
      require(nft.ownerOf(heroIds[i]) == owner, "LobbyBattle: not hero owner");
    }
    return true;
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

  function getPlayerHeroesOnLobby(uint256 lobbyId, address player)
    public
    view
    returns (uint256[] memory)
  {
    uint256 count = lobbyHeroesCount[lobbyId][player];
    uint256[] memory heroes = new uint256[](count);

    for (uint256 i = 0; i < count; i++) {
      heroes[i] = lobbyHeroes[lobbyId][player][i];
    }
    return heroes;
  }

  function getLobbyHeroes(uint256 lobbyId)
    public
    view
    returns (
      address,
      uint256[] memory,
      address,
      uint256[] memory
    )
  {
    address host = lobbies[lobbyId].host;
    address client = lobbies[lobbyId].client;
    return (
      host,
      getPlayerHeroesOnLobby(lobbyId, host),
      client,
      getPlayerHeroesOnLobby(lobbyId, client)
    );
  }

  function getLobbyPowerRange(uint256 lobbyId)
    public
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    address host = lobbies[lobbyId].host;
    address client = lobbies[lobbyId].client;

    return (
      lobbyPowers[lobbyId][host][0],
      lobbyPowers[lobbyId][host][1],
      lobbyPowers[lobbyId][client][0],
      lobbyPowers[lobbyId][client][1]
    );
  }

  function getLobbyPower(uint256 lobbyId)
    public
    view
    returns (
      address,
      uint256,
      address,
      uint256
    )
  {
    (
      address host,
      uint256[] memory hostHeroes,
      address client,
      uint256[] memory clientHeroes
    ) = getLobbyHeroes(lobbyId);

    uint256 hostPower;
    uint256 clientPower;
    for (uint256 i = 0; i < hostHeroes.length; i++) {
      uint256 hostHeroPower = heroManager.heroPower(hostHeroes[i]);
      hostPower += hostHeroPower;

      if (client != address(0)) {
        uint256 clientHeroPower = heroManager.heroPower(clientHeroes[i]);
        clientPower += clientHeroPower;
      }
    }

    return (host, hostPower, client, clientPower);
  }

  function getHeroesPower(uint256[] memory heroes)
    public
    view
    returns (uint256)
  {
    uint256 power;
    for (uint256 i = 0; i < heroes.length; i++) {
      power += heroManager.heroPower(heroes[i]);
    }
    return power;
  }

  function getActiveLobbies(address myAddr, uint256 capacity)
    public
    view
    returns (uint256[] memory)
  {
    uint256 count;

    for (uint256 i = 1; i <= lobbyIterator.current(); i++) {
      if (
        lobbies[i].finishedAt == 0 &&
        lobbies[i].capacity == capacity &&
        lobbies[i].host != myAddr
      ) {
        count++;
      }
    }

    uint256 baseIndex = 0;
    uint256[] memory result = new uint256[](count);
    for (uint256 i = 1; i <= lobbyIterator.current(); i++) {
      if (
        lobbies[i].finishedAt == 0 &&
        lobbies[i].capacity == capacity &&
        lobbies[i].host != myAddr
      ) {
        result[baseIndex] = i;
        baseIndex++;
      }
    }

    return result;
  }

  function getMyLobbies(address myAddr, uint256 capacity)
    public
    view
    returns (uint256[] memory)
  {
    uint256 count;

    for (uint256 i = 1; i <= lobbyIterator.current(); i++) {
      if (
        lobbies[i].finishedAt == 0 &&
        lobbies[i].capacity == capacity &&
        lobbies[i].host == myAddr
      ) {
        count++;
      }
    }

    uint256 baseIndex = 0;
    uint256[] memory result = new uint256[](count);
    for (uint256 i = 1; i <= lobbyIterator.current(); i++) {
      if (
        lobbies[i].finishedAt == 0 &&
        lobbies[i].capacity == capacity &&
        lobbies[i].host == myAddr
      ) {
        result[baseIndex] = i;
        baseIndex++;
      }
    }

    return result;
  }

  function getMyHistory(address myAddr, uint256 capacity)
    public
    view
    returns (uint256[] memory)
  {
    uint256 count;

    for (uint256 i = 1; i <= lobbyIterator.current(); i++) {
      if (
        lobbies[i].finishedAt > 0 &&
        lobbies[i].capacity == capacity &&
        (lobbies[i].host == myAddr || lobbies[i].client == myAddr)
      ) {
        count++;
      }
    }

    uint256 baseIndex = 0;
    uint256[] memory result = new uint256[](count);
    for (uint256 i = 1; i <= lobbyIterator.current(); i++) {
      if (
        lobbies[i].finishedAt > 0 &&
        lobbies[i].capacity == capacity &&
        (lobbies[i].host == myAddr || lobbies[i].client == myAddr)
      ) {
        result[baseIndex] = i;
        baseIndex++;
      }
    }

    return result;
  }

  function getAllHistory(uint256 capacity)
    public
    view
    returns (uint256[] memory)
  {
    uint256 count;

    for (uint256 i = 1; i <= lobbyIterator.current(); i++) {
      if (lobbies[i].finishedAt > 0 && lobbies[i].capacity == capacity) {
        count++;
      }
    }

    uint256 baseIndex = 0;
    uint256[] memory result = new uint256[](count);
    for (uint256 i = 1; i <= lobbyIterator.current(); i++) {
      if (lobbies[i].finishedAt > 0 && lobbies[i].capacity == capacity) {
        result[baseIndex] = i;
        baseIndex++;
      }
    }

    return result;
  }

  function setRewardsPayeer(address payer) external onlyOwner {
    rewardsPayeer = payer;
  }

  function setHeroManager(address hmAddr) external onlyOwner {
    heroManager = IHeroManager(hmAddr);
  }

  function setLobbyFee(uint256 capacity, uint256 fee) external onlyOwner {
    lobbyFees[capacity] = fee;
  }

  function withdrawDustETH(address payable recipient) external onlyOwner {
    recipient.transfer(address(this).balance);
  }

  function setBenefitMultiplier(uint256 multiplier) external onlyOwner {
    benefitMultiplier = multiplier;
  }

  function setHeroPowerRange(uint256 range) external onlyOwner {
    heroPowerRange = range;
  }

  receive() external payable {}
}
