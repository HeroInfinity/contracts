// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";

library GameFi {
  struct Hero {
    uint8 level;
    uint8 primaryAttribute; // 0: strength, 1: agility, 2: intelligence
    uint8 strength;
    uint8 strengthGain;
    uint8 agility;
    uint8 agilityGain;
    uint8 intelligence;
    uint8 intelligenceGain;
  }
}
