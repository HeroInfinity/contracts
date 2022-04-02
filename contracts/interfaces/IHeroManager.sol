// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

interface IHeroManager {
  function heroPower(uint256 heroId) external view returns (uint256);

  function heroPrimaryAttribute(uint256 heroId) external view returns (uint256);

  function heroLevel(uint256 heroId) external view returns (uint256);

  function bulkExpUp(uint256[] calldata heroIds, bool won) external;
}
