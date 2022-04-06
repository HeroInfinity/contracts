// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import "hardhat/console.sol";
import "./HeroManager.sol";
import "./Randomness.sol";
import "../interfaces/IHeroManager.sol";
import "../interfaces/IVersusBattle.sol";
import "../libraries/UnsafeMath.sol";

/** lobby management */
contract LobbyManager is Ownable, Multicall, Randomness {
  using UnsafeMath for uint256;

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

  uint256 private lobbyIterator;

  IHeroManager public heroManager;

  address public rewardsPayeer = 0x0cCA7943409260455CeEF6BE46c69B3fc808e24F;

  uint256 private benefitMultiplier = 250;

  uint256 public totalPlayers;
  mapping(uint256 => address) public uniquePlayers;
  mapping(address => bool) public registeredPlayers;
  mapping(address => uint256) public playersFees;
  mapping(address => uint256) public playersRewards;

  mapping(uint256 => mapping(address => mapping(uint256 => uint256)))
    public lobbyHeroes;
  mapping(uint256 => Lobby) public lobbies;
  mapping(uint256 => uint256) public lobbyFees;

  mapping(uint256 => IVersusBattle) public battles;

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
    uint256[] calldata heroIds
  ) public {
    address host = msg.sender;
    uint256 fee = lobbyFees[capacity];
    heroManager.validateHeroIds(heroIds, host);
    heroManager.validateHeroEnergies(heroIds);
    IERC20 token = IERC20(heroManager.token());

    require(capacity == heroIds.length, "LobbyManager: wrong parameters");
    require(fee > 0, "LobbyManager: wrong lobby capacity");
    require(
      token.transferFrom(host, rewardsPayeer, fee),
      "LobbyManager: not enough fee"
    );

    registerUniquePlayers(host);

    playersFees[host] = playersFees[host].add(fee);

    uint256 lobbyId = lobbyIterator.add(1);
    lobbyIterator = lobbyId;

    Lobby memory lobby = Lobby(
      name,
      avatar,
      host,
      address(0),
      lobbyId,
      capacity,
      block.timestamp,
      0,
      0,
      fee,
      0
    );

    lobbies[lobbyId] = lobby;

    for (uint256 i = 0; i < heroIds.length; i = i.add(1)) {
      lobbyHeroes[lobbyId][host][i] = heroIds[i];
      heroManager.spendHeroEnergy(heroIds[i]);
    }
  }

  function joinLobby(uint256 lobbyId, uint256[] calldata heroIds) external {
    address client = msg.sender;
    address host = lobbies[lobbyId].host;
    uint256 capacity = lobbies[lobbyId].capacity;

    heroManager.validateHeroIds(heroIds, client);
    heroManager.validateHeroEnergies(heroIds);

    require(
      lobbies[lobbyId].id == lobbyId,
      "LobbyManager: lobby doesn't exist"
    );
    require(capacity == heroIds.length, "LobbyManager: wrong heroes");
    require(lobbies[lobbyId].finishedAt == 0, "LobbyManager: already finished");

    IERC20 token = IERC20(heroManager.token());
    uint256 fee = lobbyFees[capacity];
    require(
      token.transferFrom(client, rewardsPayeer, fee),
      "LobbyManager: not enough fee"
    );

    registerUniquePlayers(client);

    playersFees[client] = playersFees[client].add(fee);

    lobbies[lobbyId].client = client;
    lobbies[lobbyId].finishedAt = block.timestamp;

    uint256[] memory hostHeroes = getPlayerHeroesOnLobby(lobbyId, host);

    uint256 reward = fee.mul(benefitMultiplier).div(100);
    lobbies[lobbyId].rewards = reward;

    IVersusBattle battle = battles[capacity];
    uint256 winner = battle.contest(hostHeroes, heroIds);
    lobbies[lobbyId].winner = winner;

    battleResultProcess(lobbyId, winner, hostHeroes, heroIds, client);

    address winnerAddress = winner == 1 ? host : client;
    token.transferFrom(rewardsPayeer, winnerAddress, reward);
    playersRewards[winnerAddress] = playersRewards[winnerAddress].add(reward);

    emit BattleFinished(lobbyId, host, client);
  }

  function registerUniquePlayers(address player) internal {
    if (!registeredPlayers[player]) {
      uniquePlayers[totalPlayers] = player;
      registeredPlayers[player] = true;
      totalPlayers = totalPlayers.add(1);
    }
  }

  function battleResultProcess(
    uint256 lobbyId,
    uint256 winner,
    uint256[] memory hostHeroes,
    uint256[] memory clientHeroes,
    address client
  ) internal {
    for (uint256 i = 0; i < hostHeroes.length; i = i.add(1)) {
      heroManager.expUp(hostHeroes[i], winner == 1);
      heroManager.expUp(clientHeroes[i], winner == 2);
      heroManager.spendHeroEnergy(clientHeroes[i]);
      lobbyHeroes[lobbyId][client][i] = clientHeroes[i];
    }
  }

  function getPlayerHeroesOnLobby(uint256 lobbyId, address player)
    public
    view
    returns (uint256[] memory)
  {
    uint256 count = 0;
    while (lobbyHeroes[lobbyId][player][count] > 0) {
      count++;
    }
    uint256[] memory heroes = new uint256[](count);

    for (uint256 i = 0; i < count; i = i.add(1)) {
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

  function getLobbyPower(uint256 lobbyId)
    external
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
    for (uint256 i = 0; i < hostHeroes.length; i = i.add(1)) {
      uint256 hostHeroPower = heroManager.heroPower(hostHeroes[i]);
      hostPower = hostPower.add(hostHeroPower);

      if (client != address(0)) {
        uint256 clientHeroPower = heroManager.heroPower(clientHeroes[i]);
        clientPower = clientPower.add(clientHeroPower);
      }
    }

    return (host, hostPower, client, clientPower);
  }

  function getHeroesPower(uint256[] memory heroes)
    external
    view
    returns (uint256)
  {
    uint256 power;
    for (uint256 i = 0; i < heroes.length; i = i.add(1)) {
      power = power.add(heroManager.heroPower(heroes[i]));
    }
    return power;
  }

  function getActiveLobbies(address myAddr, uint256 capacity)
    external
    view
    returns (uint256[] memory)
  {
    uint256 count;

    for (uint256 i = 1; i <= lobbyIterator; i++) {
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
    for (uint256 i = 1; i <= lobbyIterator; i++) {
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
    external
    view
    returns (uint256[] memory)
  {
    uint256 count;

    for (uint256 i = 1; i <= lobbyIterator; i++) {
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
    for (uint256 i = 1; i <= lobbyIterator; i++) {
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
    external
    view
    returns (uint256[] memory)
  {
    uint256 count;

    for (uint256 i = 1; i <= lobbyIterator; i++) {
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
    for (uint256 i = 1; i <= lobbyIterator; i++) {
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
    external
    view
    returns (uint256[] memory)
  {
    uint256 count;

    for (uint256 i = 1; i <= lobbyIterator; i++) {
      if (lobbies[i].finishedAt > 0 && lobbies[i].capacity == capacity) {
        count++;
      }
    }

    uint256 baseIndex = 0;
    uint256[] memory result = new uint256[](count);
    for (uint256 i = 1; i <= lobbyIterator; i++) {
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

  function setBenefitMultiplier(uint256 multiplier) external onlyOwner {
    benefitMultiplier = multiplier;
  }

  function setBattleAddress(uint256 capacity, address battleAddress)
    external
    onlyOwner
  {
    battles[capacity] = IVersusBattle(battleAddress);
  }
}
