//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract HeroInfinityToken is ERC20, Ownable {
  mapping (address => bool) private bots;

  constructor() ERC20("Hero Infinity Token", "HRI") {
    _mint(msg.sender, 10**(9 + 18)); // 1B total supply
  }

  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal override {
    require(amount > 0, "HRI: transfer amount must be greater than zero");
    require(!bots[sender] && !bots[recipient], "HRI: transfer by bot");

    super._transfer(sender, recipient, amount);
  }

  function setBots(address[] memory addrs) public onlyOwner {
    for (uint i = 0; i < addrs.length; i++) {
      bots[addrs[i]] = true;
    }
  }

  function unsetBots(address[] memory addrs) public onlyOwner {
    for (uint i = 0; i < addrs.length; i++) {
      bots[addrs[i]] = false;
    }
  }
}
