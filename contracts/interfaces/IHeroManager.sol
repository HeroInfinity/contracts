// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

interface IHeroManager {
  function heroes(uint256 heroId)
    external
    view
    returns (
      uint8 level,
      uint8 primaryAttribute,
      uint8 strength,
      uint8 strengthGain,
      uint8 agility,
      uint8 agilityGain,
      uint8 intelligence,
      uint8 intelligenceGain
    );

  function heroPower(uint256 heroId) external view returns (uint256);

  function heroPrimaryAttribute(uint256 heroId) external view returns (uint8);

  function heroLevel(uint256 heroId) external view returns (uint8);
}
