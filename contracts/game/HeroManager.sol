// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "./Randomness.sol";
import "../libraries/GameFi.sol";

/** Contract handles every single Hero data */
contract HeroManager is Ownable, Multicall, Randomness {
  IERC20 public token;
  IERC721 public nft;

  address public lobbyBattleAddress;

  uint256 public baseLevelUpFee = 50000 * 10**18; // 50,000 $HRI
  uint256 public bonusLevelUpFee = 10000 * 10**18; // 10,000 $HRI
  uint8 public heroMaxLevel = 30;

  uint256 public primaryPowerMultiplier = 10;
  uint256 public secondaryMultiplier = 8;
  uint256 public thirdMultiplier = 6;

  uint8 public bonusExp = 30; // From Level 1, every battle win will give 30 exp to the hero. And as level goes up, this will be reduced. Level 1 -> 2: 30, Lv 2 -> 3: 29, ...., Lv 29 -> 30: 2

  mapping(uint256 => GameFi.Hero) public heroes;

  constructor() {}

  function addHero(uint256 heroId, GameFi.Hero calldata hero)
    external
    onlyOwner
  {
    heroes[heroId] = hero;
  }

  function levelUp(uint256 heroId, uint8 levels) public {
    require(nft.ownerOf(heroId) == msg.sender, "HeroManager: not a NFT owner");

    GameFi.Hero memory hero = heroes[heroId];

    require(hero.level < heroMaxLevel, "HeroManager: hero max level");
    require(
      hero.level + levels <= heroMaxLevel,
      "HeroManager: too many levels up"
    );

    uint256 nextLevelUpFee = baseLevelUpFee +
      bonusLevelUpFee *
      (hero.level - 1);

    uint256 totalLevelUpFee = nextLevelUpFee *
      levels +
      ((((levels - 1) * levels) / 2) * bonusLevelUpFee);

    require(
      token.transferFrom(msg.sender, address(this), totalLevelUpFee),
      "HeroManager: not enough fee"
    );

    hero.level += levels;
    hero.strength += hero.strengthGain * levels;
    hero.agility += hero.agilityGain * levels;
    hero.strength += hero.intelligenceGain * levels;

    heroes[heroId] = hero;
  }

  function heroPower(uint256 heroId) public view returns (uint256) {
    GameFi.Hero memory hero = heroes[heroId];

    uint256 stat1;
    uint256 stat2;
    uint256 stat3;

    if (hero.primaryAttribute == 0) {
      stat1 = hero.strength;
      stat2 = hero.intelligence;
      stat3 = hero.agility;
    }
    if (hero.primaryAttribute == 1) {
      stat1 = hero.agility;
      stat2 = hero.strength;
      stat3 = hero.intelligence;
    }
    if (hero.primaryAttribute == 2) {
      stat1 = hero.intelligence;
      stat2 = hero.agility;
      stat3 = hero.strength;
    }

    uint256 power = stat1 *
      primaryPowerMultiplier +
      stat2 *
      secondaryMultiplier +
      stat3 *
      thirdMultiplier;

    return power;
  }

  function heroPrimaryAttribute(uint256 heroId) public view returns (uint8) {
    return heroes[heroId].primaryAttribute;
  }

  function heroLevel(uint256 heroId) public view returns (uint8) {
    return heroes[heroId].level;
  }

  function heroBonusExp(uint256 heroId) public view returns (uint8) {
    return bonusExp - heroes[heroId].level + 1;
  }

  function expUp(uint256 heroId) public {
    require(
      msg.sender == lobbyBattleAddress || msg.sender == address(this),
      "HeroManager: callable by lobby battle only"
    );

    if (heroes[heroId].level < 30) {
      uint8 gainedExp = heroBonusExp(heroId);
      heroes[heroId].experience += gainedExp;
      if (heroes[heroId].experience >= 100) {
        heroes[heroId].experience -= 100;
        heroes[heroId].level += 1;
      }
    }
  }

  function bulkExpUp(uint256[] calldata heroIds) external {
    require(
      msg.sender == lobbyBattleAddress,
      "HeroManager: callable by lobby battle only"
    );

    for (uint8 i = 0; i < heroIds.length; i++) {
      expUp(heroIds[i]);
    }
  }

  function expDown(uint256 heroId) public {
    require(
      msg.sender == lobbyBattleAddress || msg.sender == address(this),
      "HeroManager: callable by lobby battle only"
    );

    if (heroes[heroId].level > 1 || heroes[heroId].experience > 0) {
      uint8 gainedExp = heroBonusExp(heroId) / 2;
      heroes[heroId].experience -= gainedExp;
      if (heroes[heroId].experience < 0) {
        if (heroes[heroId].level == 1) {
          heroes[heroId].experience = 0;
        } else {
          heroes[heroId].experience += 100;
          heroes[heroId].level -= 1;
        }
      }
    }
  }

  function bulkExpDown(uint256[] calldata heroIds) external {
    require(
      msg.sender == lobbyBattleAddress,
      "HeroManager: callable by lobby battle only"
    );

    for (uint8 i = 0; i < heroIds.length; i++) {
      expDown(heroIds[i]);
    }
  }

  function setLobbyBattle(address lbAddr) external onlyOwner {
    lobbyBattleAddress = lbAddr;
  }
}
