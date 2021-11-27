//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interface/IBEP20.sol";
import "./interface/IDEXRouter.sol";
import "./interface/IDEXFactory.sol";
import "./WBNBDistributor.sol";

contract HeroInfinityToken is Context, IBEP20, Ownable {
  using SafeMath for uint256;

  address public dexAddress = 0x10ED43C718714eb63d5aA57B78B54704E256024E; // Pancakeswap V2 router address
  address public wbnbAddress = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // WBNB address
  address public deadAddress = 0x000000000000000000000000000000000000dEaD;
  address public zeroAddress = 0x0000000000000000000000000000000000000000;

  string private constant NAME = "Hero Infinity Token";
  string private constant SYMBOL = "HRI";
  uint8 private constant DECIMALS = 18;

  uint256 private constant TOTAL_SUPPLY = 10**(9 + DECIMALS); // 1 Billion

  mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) private _allowances;

  mapping(address => bool) public isFeeExempt;
  mapping(address => bool) public isTxLimitExempt;
  mapping(address => bool) public isDividendExempt;
  mapping(address => bool) public isRestricted;

  uint256 public wbnbFee = 500;
  uint256 public burnFee = 200;
  uint256 public teamFee = 300;

  uint256 public feeDenominator = 10000;

  address public teamWallet;

  IDEXRouter public router;
  address public pancakeV2WBNBPair;
  address[] public pairs;

  bool public swapEnabled = true;
  bool public feesOnNormalTransfers = true;

  WBNBDistributor private wbnbDistributor;

  bool private inSwap;
  modifier swapping() {
    inSwap = true;
    _;
    inSwap = false;
  }
  uint256 public swapThreshold = 10 * 10**DECIMALS;

  constructor() {
    address _owner = msg.sender;

    router = IDEXRouter(dexAddress);
    pancakeV2WBNBPair = IDEXFactory(router.factory()).createPair(
      wbnbAddress,
      address(this)
    );
    _allowances[address(this)][address(router)] = ~uint256(0);

    pairs.push(pancakeV2WBNBPair);
    wbnbDistributor = new WBNBDistributor(
      wbnbAddress,
      address(router),
      TOTAL_SUPPLY
    );

    isFeeExempt[_owner] = true;
    isFeeExempt[address(this)] = true;
    isFeeExempt[address(wbnbDistributor)] = true;
    isDividendExempt[pancakeV2WBNBPair] = true;
    isDividendExempt[address(this)] = true;
    isDividendExempt[deadAddress] = true;
    isDividendExempt[zeroAddress] = true;
    isDividendExempt[address(wbnbDistributor)] = true;
    isDividendExempt[_owner] = true;

    teamWallet = _owner;

    _balances[_owner] = TOTAL_SUPPLY;
    emit Transfer(address(0), _owner, TOTAL_SUPPLY);
  }

  function totalSupply() external pure override returns (uint256) {
    return TOTAL_SUPPLY;
  }

  function decimals() external pure override returns (uint8) {
    return DECIMALS;
  }

  function symbol() external pure override returns (string memory) {
    return SYMBOL;
  }

  function name() external pure override returns (string memory) {
    return NAME;
  }

  function balanceOf(address account) public view override returns (uint256) {
    return _balances[account];
  }

  function allowance(address holder, address spender)
    external
    view
    override
    returns (uint256)
  {
    return _allowances[holder][spender];
  }

  function _approve(
    address owner,
    address spender,
    uint256 amount
  ) private {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  function approve(address spender, uint256 amount)
    public
    override
    returns (bool)
  {
    _approve(msg.sender, spender, amount);
    return true;
  }

  function approveMax(address spender) external returns (bool) {
    return approve(spender, ~uint256(0));
  }

  function transfer(address recipient, uint256 amount)
    external
    override
    returns (bool)
  {
    return _transferFrom(msg.sender, recipient, amount);
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external override returns (bool) {
    if (_allowances[sender][msg.sender] != ~uint256(0)) {
      _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(
        amount,
        "Insufficient Allowance"
      );
    }

    return _transferFrom(sender, recipient, amount);
  }

  function _transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) internal returns (bool) {
    require(!isRestricted[recipient], "Address is restricted");

    if (inSwap) {
      return _basicTransfer(sender, recipient, amount);
    }

    if (shouldSwapBack()) {
      _swapBack();
    }

    require(_balances[sender].sub(amount) >= 0, "Insufficient Balance");
    _balances[sender] = _balances[sender].sub(amount);

    if (shouldTakeFee(sender, recipient)) {
      uint256 _bnbFee = amount.mul(wbnbFee).div(feeDenominator);
      uint256 _burnFee = amount.mul(burnFee).div(feeDenominator);
      uint256 _teamFee = amount.mul(teamFee).div(feeDenominator);

      uint256 _totalFee = _bnbFee + _burnFee + _teamFee;
      uint256 amountReceived = amount - _totalFee;

      _balances[address(this)] = _balances[address(this)] + _bnbFee + _teamFee;

      _balances[deadAddress] = _balances[deadAddress].add(_burnFee);
      emit Transfer(sender, deadAddress, _burnFee);

      _balances[recipient] = _balances[recipient].add(amountReceived);
      emit Transfer(sender, recipient, amountReceived);
    } else {
      _balances[recipient] = _balances[recipient].add(amount);
      emit Transfer(sender, recipient, amount);
    }

    if (!isDividendExempt[sender]) {
      try wbnbDistributor.setShare(sender, _balances[sender]) {} catch {}
    }

    if (!isDividendExempt[recipient]) {
      try wbnbDistributor.setShare(recipient, _balances[recipient]) {} catch {}
    }

    return true;
  }

  function _basicTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal returns (bool) {
    require(balanceOf(sender).sub(amount) >= 0, "Insufficient Balance");
    _balances[sender] = _balances[sender].sub(amount);
    _balances[recipient] = _balances[recipient].add(amount);
    emit Transfer(sender, recipient, amount);
    return true;
  }

  function shouldTakeFee(address sender, address recipient)
    internal
    view
    returns (bool)
  {
    if (isFeeExempt[sender] || isFeeExempt[recipient]) return false;

    address[] memory liqPairs = pairs;

    for (uint256 i = 0; i < liqPairs.length; i++) {
      if (sender == liqPairs[i] || recipient == liqPairs[i]) return true;
    }

    return feesOnNormalTransfers;
  }

  function shouldSwapBack() internal view returns (bool) {
    return
      msg.sender != pancakeV2WBNBPair &&
      !inSwap &&
      swapEnabled &&
      _balances[address(this)] >= swapThreshold;
  }

  function swapBack() external onlyOwner {
    _swapBack();
  }

  function _swapBack() internal swapping {
    uint256 balanceBefore = address(this).balance;

    uint256 amountToSwap = _balances[address(this)];

    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = router.WETH();

    _approve(address(this), address(router), amountToSwap);
    router.swapExactTokensForETHSupportingFeeOnTransferTokens(
      amountToSwap,
      0,
      path,
      address(this),
      block.timestamp
    );

    uint256 swapedBNBAmount = address(this).balance.sub(balanceBefore);

    if (swapedBNBAmount > 0) {
      uint256 bnbDenom = wbnbFee + teamFee;

      uint256 teamAmount = swapedBNBAmount.mul(teamFee).div(bnbDenom);
      payable(teamWallet).transfer(teamAmount);

      uint256 refAmount = swapedBNBAmount.mul(wbnbFee).div(bnbDenom);
      payable(wbnbDistributor).transfer(refAmount);
      wbnbDistributor.deposit(refAmount);
    }
  }

  function wbnbBalance() external view returns (uint256) {
    return address(this).balance;
  }

  function wbnbRewardbalance() external view returns (uint256) {
    return address(wbnbDistributor).balance;
  }

  function setIsDividendExempt(address holder, bool exempt) external onlyOwner {
    require(
      holder != address(this) && holder != pancakeV2WBNBPair,
      "Not allowed holder"
    );
    isDividendExempt[holder] = exempt;
    if (exempt) {
      wbnbDistributor.setShare(holder, 0);
    } else {
      wbnbDistributor.setShare(holder, _balances[holder]);
    }
  }

  function setIsFeeExempt(address holder, bool exempt) external onlyOwner {
    isFeeExempt[holder] = exempt;
  }

  function setFees(
    uint256 _wbnbFee,
    uint256 _burnFee,
    uint256 _teamFee
  ) external onlyOwner {
    wbnbFee = _wbnbFee;
    burnFee = _burnFee;
    teamFee = _teamFee;
  }

  function setSwapThreshold(uint256 threshold) external onlyOwner {
    swapThreshold = threshold;
  }

  function setSwapEnabled(bool _enabled) external onlyOwner {
    swapEnabled = _enabled;
  }

  function setTeamWallet(address _team) external onlyOwner {
    teamWallet = _team;

    isDividendExempt[_team] = true;
    isFeeExempt[_team] = true;
  }

  function getCirculatingSupply() external view returns (uint256) {
    return TOTAL_SUPPLY.sub(balanceOf(deadAddress)).sub(balanceOf(zeroAddress));
  }

  function getClaimableWBNB() external view returns (uint256) {
    return wbnbDistributor.currentRewards(msg.sender);
  }

  function getWalletClaimableWBNB(address _addr)
    external
    view
    returns (uint256)
  {
    return wbnbDistributor.currentRewards(_addr);
  }

  function getWalletShareAmount(address _addr) external view returns (uint256) {
    return wbnbDistributor.getWalletShare(_addr);
  }

  function claim() external {
    wbnbDistributor.claimDividend(msg.sender);
  }

  function addPair(address pair) external onlyOwner {
    pairs.push(pair);
  }

  function removeLastPair() external onlyOwner {
    pairs.pop();
  }

  function setFeesOnNormalTransfers(bool _enabled) external onlyOwner {
    feesOnNormalTransfers = _enabled;
  }

  function setisRestricted(address adr, bool restricted) external onlyOwner {
    isRestricted[adr] = restricted;
  }

  function walletIsDividendExempt(address adr) external view returns (bool) {
    return isDividendExempt[adr];
  }

  function walletIsTaxExempt(address adr) external view returns (bool) {
    return isFeeExempt[adr];
  }

  function walletisRestricted(address adr) external view returns (bool) {
    return isRestricted[adr];
  }

  function withdrawTokens(address tokenaddr) external onlyOwner {
    require(
      tokenaddr != address(this),
      "This is for tokens sent to the contract by mistake"
    );
    uint256 tokenBal = IBEP20(tokenaddr).balanceOf(address(this));
    if (tokenBal > 0) {
      IBEP20(tokenaddr).transfer(teamWallet, tokenBal);
    }
  }

  receive() external payable {}
}
