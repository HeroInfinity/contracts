// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

contract Randomness {
  // Generates random number between min and max (include)
  function random(uint256 min, uint256 max)
    public
    view
    virtual
    returns (uint256)
  {
    // sha3 and now have been deprecated
    uint256 randomNum = uint256(
      keccak256(
        abi.encodePacked(
          block.difficulty,
          block.timestamp,
          msg.sender,
          min,
          max
        )
      )
    );
    // convert hash to integer

    return (randomNum % (max - min + 1)) + min;
  }
}
