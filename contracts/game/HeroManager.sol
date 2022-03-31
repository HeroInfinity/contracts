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
  IERC20 public token = IERC20(0x28ee3E2826264b9c55FcdD122DFa93680916c9b8);
  IERC721 public nft = IERC721(0xef5A8AF5148a53a4ef4749595fe44E3E08754b8B);

  address public lobbyBattleAddress;

  uint256 public constant HERO_MAX_LEVEL = 30;
  uint256 public constant HERO_MAX_EXP = 100;

  uint256 public baseLevelUpFee = 50000 * 10**18; // 50,000 $HRI
  uint256 public bonusLevelUpFee = 10000 * 10**18; // 10,000 $HRI

  uint256 public primaryPowerMultiplier = 10;
  uint256 public secondaryMultiplier = 8;
  uint256 public thirdMultiplier = 6;

  uint256 public rarityPowerBooster = 110;

  mapping(uint256 => GameFi.Hero) public heroes;

  constructor() {}

  function addHero(uint256 heroId, GameFi.Hero calldata hero)
    external
    onlyOwner
  {
    heroes[heroId] = hero;
  }

  function levelUp(uint256 heroId, uint256 levels) public {
    require(nft.ownerOf(heroId) == msg.sender, "HeroManager: not a NFT owner");
    require(
      heroes[heroId].level < HERO_MAX_LEVEL,
      "HeroManager: hero max level"
    );
    require(
      heroes[heroId].level + levels <= HERO_MAX_LEVEL,
      "HeroManager: too many levels up"
    );

    uint256 nextLevelUpFee = baseLevelUpFee +
      bonusLevelUpFee *
      (heroes[heroId].level - 1);

    uint256 totalLevelUpFee = nextLevelUpFee *
      levels +
      ((((levels - 1) * levels) / 2) * bonusLevelUpFee);

    require(
      token.transferFrom(msg.sender, address(this), totalLevelUpFee),
      "HeroManager: not enough fee"
    );

    heroes[heroId].level += levels;
    heroes[heroId].strength += heroes[heroId].strengthGain * levels;
    heroes[heroId].agility += heroes[heroId].agilityGain * levels;
    heroes[heroId].intelligence += heroes[heroId].intelligenceGain * levels;
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

    if (hero.rarity == 1) {
      // Rare
      power = (power * rarityPowerBooster) / 100;
    } else if (hero.rarity == 2) {
      // Mythical
      power = (power * (rarityPowerBooster**2)) / (100**2);
    } else if (hero.rarity == 3) {
      // Legendary
      power = (power * (rarityPowerBooster**3)) / (100**3);
    } else if (hero.rarity == 4) {
      // Immortal
      power = (power * (rarityPowerBooster**4)) / (100**4);
    }

    return power;
  }

  function heroPrimaryAttribute(uint256 heroId) public view returns (uint256) {
    return heroes[heroId].primaryAttribute;
  }

  function heroLevel(uint256 heroId) public view returns (uint256) {
    return heroes[heroId].level;
  }

  function expUp(uint256 heroId, uint256 exp) public {
    require(
      msg.sender == lobbyBattleAddress || msg.sender == address(this),
      "HeroManager: callable by lobby battle only"
    );

    if (heroes[heroId].level < HERO_MAX_LEVEL) {
      heroes[heroId].experience += exp;
      if (heroes[heroId].experience >= HERO_MAX_EXP) {
        heroes[heroId].experience -= HERO_MAX_EXP;
        heroes[heroId].level += 1;
      }
    }
  }

  function bulkExpUp(uint256[] calldata heroIds, uint256 exp) external {
    require(
      msg.sender == lobbyBattleAddress,
      "HeroManager: callable by lobby battle only"
    );

    for (uint256 i = 0; i < heroIds.length; i++) {
      expUp(heroIds[i], exp);
    }
  }

  function setLobbyBattle(address lbAddr) external onlyOwner {
    lobbyBattleAddress = lbAddr;
  }

  function setRarityPowerBooster(uint256 value) external onlyOwner {
    rarityPowerBooster = value;
  }

  function setPrimaryPowerMultiplier(uint256 value) external onlyOwner {
    primaryPowerMultiplier = value;
  }

  function setSecondaryMultiplier(uint256 value) external onlyOwner {
    secondaryMultiplier = value;
  }

  function setThirdMultiplier(uint256 value) external onlyOwner {
    thirdMultiplier = value;
  }

  function setBaseLevelUpFee(uint256 value) external onlyOwner {
    baseLevelUpFee = value;
  }

  function setBonusLevelUpFee(uint256 value) external onlyOwner {
    bonusLevelUpFee = value;
  }

  function setToken(address tokenAddress) external onlyOwner {
    token = IERC20(tokenAddress);
  }

  function setNFT(address nftAddress) external onlyOwner {
    nft = IERC721(nftAddress);
  }

  function withdrawDustETH(address payable recipient) external onlyOwner {
    recipient.transfer(address(this).balance);
  }

  receive() external payable {}
}
