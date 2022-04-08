// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

interface IRandomness {
  // Generates random number between min and max (include)
  function random(uint256 min, uint256 max) external view returns (uint256);
}
