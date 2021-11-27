//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interface/IDividendDistributor.sol";
import "./interface/IDEXRouter.sol";

contract WBNBDistributor is IDividendDistributor, ReentrancyGuard {
  using SafeMath for uint256;

  address private _token;

  struct Share {
    uint256 amount;
    uint256 totalExcluded;
    uint256 totalRealised;
  }

  address private wbnb;
  IDEXRouter private router;

  mapping(address => uint256) private _shareAmount;
  mapping(address => uint256) private _shareEntry;
  mapping(address => uint256) private _accured;
  uint256 private _totalShared;
  uint256 private _totalReward;
  uint256 private _totalAccured;
  uint256 private _stakingMagnitude;

  uint256 private minAmount = 0;

  modifier onlyToken() {
    require(msg.sender == _token, "Caller must be token");
    _;
  }

  constructor(
    address _wbnb,
    address _router,
    uint256 _totalSupply
  ) {
    wbnb = _wbnb;
    router = IDEXRouter(_router);
    _token = msg.sender;
    _stakingMagnitude = _totalSupply;
  }

  function setShare(address shareholder, uint256 amount)
    external
    override
    onlyToken
  {
    if (_shareAmount[shareholder] > 0) {
      _accured[shareholder] = currentRewards(shareholder);
    }

    _totalShared = _totalShared.sub(_shareAmount[shareholder]).add(amount);
    _shareAmount[shareholder] = amount;

    _shareEntry[shareholder] = _totalAccured;
  }

  function getWalletShare(address shareholder) public view returns (uint256) {
    return _shareAmount[shareholder];
  }

  function deposit(uint256 amount) external override onlyToken {
    _totalReward = _totalReward + amount;
    _totalAccured = _totalAccured + (amount * _stakingMagnitude) / _totalShared;
  }

  function distributeDividend(address shareholder, address receiver)
    internal
    nonReentrant
  {
    if (_shareAmount[shareholder] == 0) {
      return;
    }

    _accured[shareholder] = currentRewards(shareholder);
    require(
      _accured[shareholder] > minAmount,
      "Reward amount has to be more than minimum amount"
    );

    payable(receiver).transfer(_accured[shareholder]);
    _totalReward = _totalReward - _accured[shareholder];
    _accured[shareholder] = _accured[shareholder] - _accured[shareholder];

    _shareEntry[shareholder] = _totalAccured;
  }

  function claimDividend(address shareholder) external override onlyToken {
    uint256 amount = currentRewards(shareholder);
    if (amount == 0) {
      return;
    }

    distributeDividend(shareholder, shareholder);
  }

  function _calculateReward(address addy) private view returns (uint256) {
    return
      (_shareAmount[addy] * (_totalAccured - _shareEntry[addy])) /
      _stakingMagnitude;
  }

  function currentRewards(address addy) public view returns (uint256) {
    uint256 totalRewards = address(this).balance;

    uint256 calcReward = _accured[addy] + _calculateReward(addy);

    // Fail safe to ensure rewards are never more than the contract holding.
    if (calcReward > totalRewards) {
      return totalRewards;
    }

    return calcReward;
  }

  receive() external payable {}
}
