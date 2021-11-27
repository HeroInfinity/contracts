//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract HeroInfinityICO is ReentrancyGuard, Context, Ownable {
  using SafeMath for uint256;

  mapping(address => uint256) public contributions;

  IERC20 public token;
  address payable public payWallet;
  uint256 public rate;
  uint256 public tokenDecimals;
  uint256 public weiRaised;
  uint256 public endICO;
  uint256 public minPurchase;
  uint256 public maxPurchase;
  uint256 public hardCap;
  uint256 public softCap;
  uint256 public availableTokensICO;
  bool public startRefund = false;
  uint256 public refundStartDate;

  event TokensPurchased(
    address purchaser,
    address beneficiary,
    uint256 value,
    uint256 amount
  );
  event Refund(address recipient, uint256 amount);

  constructor(
    uint256 _rate,
    address payable _wallet,
    IERC20 _token
  ) {
    require(_rate > 0, "Pre-Sale: rate is 0");
    require(_wallet != address(0), "Pre-Sale: wallet is the zero address");
    require(
      address(_token) != address(0),
      "Pre-Sale: token is the zero address"
    );

    rate = _rate;
    payWallet = _wallet;
    token = _token;
  }

  receive() external payable {
    if (endICO > 0 && block.timestamp < endICO) {
      _buyTokens(_msgSender());
    } else {
      revert("Pre-Sale is closed");
    }
  }

  //Start Pre-Sale
  function startICO(
    uint256 endDate,
    uint256 _minPurchase,
    uint256 _maxPurchase,
    uint256 _softCap,
    uint256 _hardCap
  ) external onlyOwner icoNotActive {
    startRefund = false;
    refundStartDate = 0;
    availableTokensICO = token.balanceOf(address(this));
    require(endDate > block.timestamp, "duration should be > 0");
    require(_softCap < _hardCap, "Softcap must be lower than Hardcap");
    require(
      _minPurchase < _maxPurchase,
      "minPurchase must be lower than maxPurchase"
    );
    require(availableTokensICO > 0, "availableTokens must be > 0");
    require(_minPurchase > 0, "_minPurchase should > 0");
    endICO = endDate;
    minPurchase = _minPurchase;
    maxPurchase = _maxPurchase;
    softCap = _softCap;
    hardCap = _hardCap;
    weiRaised = 0;
  }

  function stopICO() external onlyOwner icoActive {
    endICO = 0;
    if (weiRaised >= softCap) {
      _forwardFunds();
    } else {
      startRefund = true;
      refundStartDate = block.timestamp;
    }
  }

  //Pre-Sale
  function buyTokens() public payable nonReentrant icoActive {
    _buyTokens(msg.sender);
  }

  function _buyTokens(address beneficiary) internal {
    uint256 weiAmount = msg.value;
    _preValidatePurchase(beneficiary, weiAmount);
    uint256 tokens = _getTokenAmount(weiAmount);
    weiRaised = weiRaised.add(weiAmount);
    availableTokensICO = availableTokensICO - tokens;
    contributions[beneficiary] = contributions[beneficiary].add(weiAmount);
    emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);
  }

  function _preValidatePurchase(address beneficiary, uint256 weiAmount)
    internal
    view
  {
    require(
      beneficiary != address(0),
      "Crowdsale: beneficiary is the zero address"
    );
    require(weiAmount != 0, "Crowdsale: weiAmount is 0");
    require(weiAmount >= minPurchase, "have to send at least: minPurchase");
    require(
      contributions[beneficiary].add(weiAmount) <= maxPurchase,
      "can't buy more than: maxPurchase"
    );
    require((weiRaised + weiAmount) <= hardCap, "Hard Cap reached");
    this;
  }

  function claimTokens() external icoNotActive {
    require(startRefund == false, "Claim disabled");
    uint256 tokensAmt = _getTokenAmount(contributions[msg.sender]);
    contributions[msg.sender] = 0;
    token.transfer(msg.sender, tokensAmt);
  }

  function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
    return weiAmount.mul(rate);
  }

  function _forwardFunds() internal {
    payWallet.transfer(address(this).balance);
  }

  function withdraw() external onlyOwner icoNotActive {
    require(
      startRefund == false || (refundStartDate + 3 days) < block.timestamp,
      "Withdraw disabled"
    );
    require(address(this).balance > 0, "Contract has no money");
    payWallet.transfer(address(this).balance);
  }

  function checkContribution(address addr) public view returns (uint256) {
    return contributions[addr];
  }

  function setRate(uint256 newRate) external onlyOwner icoNotActive {
    rate = newRate;
  }

  function setAvailableTokens(uint256 amount) public onlyOwner icoNotActive {
    availableTokensICO = amount;
  }

  function setWalletReceiver(address payable newWallet) external onlyOwner {
    payWallet = newWallet;
  }

  function setHardCap(uint256 value) external onlyOwner {
    hardCap = value;
  }

  function setSoftCap(uint256 value) external onlyOwner {
    softCap = value;
  }

  function setMaxPurchase(uint256 value) external onlyOwner {
    maxPurchase = value;
  }

  function setMinPurchase(uint256 value) external onlyOwner {
    minPurchase = value;
  }

  function takeTokens(IERC20 tokenAddress) public onlyOwner icoNotActive {
    IERC20 tokenBEP = tokenAddress;
    uint256 tokenAmt = tokenBEP.balanceOf(address(this));
    require(tokenAmt > 0, "BEP-20 balance is 0");
    tokenBEP.transfer(payWallet, tokenAmt);
  }

  function refundMe() public icoNotActive {
    require(startRefund == true, "no refund available");
    uint256 amount = contributions[msg.sender];
    if (address(this).balance >= amount) {
      contributions[msg.sender] = 0;
      if (amount > 0) {
        address payable recipient = payable(msg.sender);
        recipient.transfer(amount);
        weiRaised = weiRaised.sub(amount);
        emit Refund(msg.sender, amount);
      }
    }
  }

  modifier icoActive() {
    require(
      endICO > 0 && block.timestamp < endICO && availableTokensICO > 0,
      "ICO must be active"
    );
    _;
  }

  modifier icoNotActive() {
    require(endICO < block.timestamp, "ICO should not be active");
    _;
  }
}
