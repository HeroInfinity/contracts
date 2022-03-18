// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract HeroInfinityToken is ERC20, Ownable {
  using SafeMath for uint256;

  IUniswapV2Router02 public immutable uniswapV2Router;
  address public immutable uniswapV2Pair;

  bool private swapping;

  address public marketingWallet;
  address public buybackWallet;
  address public liquidityWallet;

  uint256 public maxTransactionAmount;
  uint256 public swapTokensAtAmount;
  uint256 public maxWallet;

  bool public limitsInEffect = true;
  bool public tradingActive = false;
  bool public swapEnabled = false;

  bool private gasLimitActive = true;
  uint256 private gasPriceLimit = 561 * 1 gwei; // do not allow over x gwei for launch

  // Anti-bot and anti-whale mappings and variables
  mapping(address => uint256) private _holderLastTransferTimestamp; // to hold last Transfers temporarily during launch
  bool public transferDelayEnabled = true;

  uint256 public buyTotalFees;
  uint256 public buyMarketingFee;
  uint256 public buyLiquidityFee;
  uint256 public buyBuyBackFee;
  uint256 public buyDevFee;

  uint256 public sellTotalFees;
  uint256 public sellMarketingFee;
  uint256 public sellLiquidityFee;
  uint256 public sellBuyBackFee;
  uint256 public sellDevFee;

  uint256 public tokensForMarketing;
  uint256 public tokensForLiquidity;
  uint256 public tokensForBuyBack;
  uint256 public tokensForDev;

  /******************/

  // exlcude from fees and max transaction amount
  mapping(address => bool) private _isExcludedFromFees;
  mapping(address => bool) public _isExcludedMaxTransactionAmount;

  // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
  // could be subject to a maximum transfer amount
  mapping(address => bool) public automatedMarketMakerPairs;

  event UpdateUniswapV2Router(
    address indexed newAddress,
    address indexed oldAddress
  );

  event ExcludeFromFees(address indexed account, bool isExcluded);

  event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

  event MarketingWalletUpdated(
    address indexed newWallet,
    address indexed oldWallet
  );

  event BuybackWalletUpdated(
    address indexed newWallet,
    address indexed oldWallet
  );

  event LiquidityWalletUpdated(
    address indexed newWallet,
    address indexed oldWallet
  );

  event SwapAndLiquify(
    uint256 tokensSwapped,
    uint256 ethReceived,
    uint256 tokensIntoLiquidity
  );

  event BuyBackTriggered(uint256 amount);

  event OwnerForcedSwapBack(uint256 timestamp);

  constructor() ERC20("Hero Infinity Token", "HRI") {
    IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
      0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D // rinkeby UniswapV2Router02 address
    );

    excludeFromMaxTransaction(address(_uniswapV2Router), true);
    uniswapV2Router = _uniswapV2Router;

    uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
      address(this),
      _uniswapV2Router.WETH()
    );
    excludeFromMaxTransaction(address(uniswapV2Pair), true);
    _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);

    uint256 _buyMarketingFee = 6;
    uint256 _buyLiquidityFee = 7;
    uint256 _buyBuyBackFee = 0;
    uint256 _buyDevFee = 2;

    uint256 _sellMarketingFee = 6;
    uint256 _sellLiquidityFee = 17;
    uint256 _sellBuyBackFee = 0;
    uint256 _sellDevFee = 2;

    uint256 totalSupply = 1 * 1e9 * 1e18;

    maxTransactionAmount = (totalSupply * 5) / 1000; // 0.5% maxTransactionAmountTxn
    maxWallet = (totalSupply * 2) / 100; // 2% maxWallet
    swapTokensAtAmount = (totalSupply * 5) / 10000; // 0.05% swap wallet

    buyMarketingFee = _buyMarketingFee;
    buyLiquidityFee = _buyLiquidityFee;
    buyBuyBackFee = _buyBuyBackFee;
    buyDevFee = _buyDevFee;
    buyTotalFees =
      buyMarketingFee +
      buyLiquidityFee +
      buyBuyBackFee +
      buyDevFee;

    sellMarketingFee = _sellMarketingFee;
    sellLiquidityFee = _sellLiquidityFee;
    sellBuyBackFee = _sellBuyBackFee;
    sellDevFee = _sellDevFee;
    sellTotalFees =
      sellMarketingFee +
      sellLiquidityFee +
      sellBuyBackFee +
      sellDevFee;

    marketingWallet = msg.sender;
    buybackWallet = msg.sender;
    liquidityWallet = msg.sender;

    // exclude from paying fees or having max transaction amount
    excludeFromFees(owner(), true);
    excludeFromFees(address(this), true);
    excludeFromFees(address(0xdead), true);
    excludeFromFees(buybackWallet, true);

    excludeFromMaxTransaction(owner(), true);
    excludeFromMaxTransaction(address(this), true);
    excludeFromMaxTransaction(buybackWallet, true);
    excludeFromMaxTransaction(address(0xdead), true);

    /*
      _mint is an internal function in ERC20.sol that is only called here,
      and CANNOT be called ever again
    */
    _mint(msg.sender, totalSupply);
  }

  receive() external payable {}

  // once enabled, can never be turned off
  function enableTrading() external onlyOwner {
    tradingActive = true;
    swapEnabled = true;
  }

  // remove limits after token is stable
  function removeLimits() external onlyOwner returns (bool) {
    limitsInEffect = false;
    gasLimitActive = false;
    transferDelayEnabled = false;
    return true;
  }

  // disable Transfer delay - cannot be reenabled
  function disableTransferDelay() external onlyOwner returns (bool) {
    transferDelayEnabled = false;
    return true;
  }

  // change the minimum amount of tokens to sell from fees
  function updateSwapTokensAtAmount(uint256 newAmount)
    external
    onlyOwner
    returns (bool)
  {
    require(
      newAmount >= (totalSupply() * 1) / 100000,
      "Swap amount cannot be lower than 0.001% total supply."
    );
    require(
      newAmount <= (totalSupply() * 5) / 1000,
      "Swap amount cannot be higher than 0.5% total supply."
    );
    swapTokensAtAmount = newAmount;
    return true;
  }

  function updateMaxAmount(uint256 newNum) external onlyOwner {
    require(
      newNum >= ((totalSupply() * 5) / 1000) / 1e18,
      "Cannot set maxTransactionAmount lower than 0.5%"
    );
    maxTransactionAmount = newNum * (10**18);
  }

  function excludeFromMaxTransaction(address updAds, bool isEx)
    public
    onlyOwner
  {
    _isExcludedMaxTransactionAmount[updAds] = isEx;
  }

  // only use to disable contract sales if absolutely necessary (emergency use only)
  function updateSwapEnabled(bool enabled) external onlyOwner {
    swapEnabled = enabled;
  }

  function updateBuyFees(
    uint256 _marketingFee,
    uint256 _liquidityFee,
    uint256 _buyBackFee,
    uint256 _devFee
  ) external onlyOwner {
    buyMarketingFee = _marketingFee;
    buyLiquidityFee = _liquidityFee;
    buyBuyBackFee = _buyBackFee;
    buyDevFee = _devFee;
    buyTotalFees =
      buyMarketingFee +
      buyLiquidityFee +
      buyBuyBackFee +
      buyDevFee;
  }

  function updateSellFees(
    uint256 _marketingFee,
    uint256 _liquidityFee,
    uint256 _buyBackFee,
    uint256 _devFee
  ) external onlyOwner {
    sellMarketingFee = _marketingFee;
    sellLiquidityFee = _liquidityFee;
    sellBuyBackFee = _buyBackFee;
    sellDevFee = _devFee;
    sellTotalFees =
      sellMarketingFee +
      sellLiquidityFee +
      sellBuyBackFee +
      sellDevFee;
  }

  function excludeFromFees(address account, bool excluded) public onlyOwner {
    _isExcludedFromFees[account] = excluded;
    emit ExcludeFromFees(account, excluded);
  }

  function setAutomatedMarketMakerPair(address pair, bool value)
    public
    onlyOwner
  {
    require(
      pair != uniswapV2Pair,
      "The pair cannot be removed from automatedMarketMakerPairs"
    );

    _setAutomatedMarketMakerPair(pair, value);
  }

  function _setAutomatedMarketMakerPair(address pair, bool value) private {
    automatedMarketMakerPairs[pair] = value;

    emit SetAutomatedMarketMakerPair(pair, value);
  }

  function updateMarketingWallet(address newMarketingWallet)
    external
    onlyOwner
  {
    emit MarketingWalletUpdated(newMarketingWallet, marketingWallet);
    marketingWallet = newMarketingWallet;
  }

  function updateBuybackWallet(address newWallet) external onlyOwner {
    emit BuybackWalletUpdated(newWallet, buybackWallet);
    buybackWallet = newWallet;
  }

  function updateliquidityWallet(address newWallet) external onlyOwner {
    emit LiquidityWalletUpdated(newWallet, liquidityWallet);
    liquidityWallet = newWallet;
  }

  function isExcludedFromFees(address account) public view returns (bool) {
    return _isExcludedFromFees[account];
  }

  event BoughtEarly(address indexed sniper);

  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    require(from != address(0), "ERC20: transfer from the zero address");
    require(to != address(0), "ERC20: transfer to the zero address");

    if (amount == 0) {
      super._transfer(from, to, 0);
      return;
    }

    if (limitsInEffect) {
      if (
        from != owner() &&
        to != owner() &&
        to != address(0) &&
        to != address(0xdead) &&
        !swapping
      ) {
        if (!tradingActive) {
          require(
            _isExcludedFromFees[from] || _isExcludedFromFees[to],
            "Trading is not active."
          );
        }

        // only use to prevent sniper buys in the first blocks.
        if (gasLimitActive && automatedMarketMakerPairs[from]) {
          require(tx.gasprice <= gasPriceLimit, "Gas price exceeds limit.");
        }

        // at launch if the transfer delay is enabled, ensure the block timestamps for purchasers is set -- during launch.
        if (transferDelayEnabled) {
          if (
            to != owner() &&
            to != address(uniswapV2Router) &&
            to != address(uniswapV2Pair)
          ) {
            require(
              _holderLastTransferTimestamp[tx.origin] < block.number,
              "_transfer:: Transfer Delay enabled.  Only one purchase per block allowed."
            );
            _holderLastTransferTimestamp[tx.origin] = block.number;
          }
        }

        //when buy
        if (
          automatedMarketMakerPairs[from] &&
          !_isExcludedMaxTransactionAmount[to]
        ) {
          require(
            amount <= maxTransactionAmount,
            "Buy transfer amount exceeds the maxTransactionAmount."
          );
          require(amount + balanceOf(to) <= maxWallet, "Max wallet exceeded");
        }
        //when sell
        else if (
          automatedMarketMakerPairs[to] &&
          !_isExcludedMaxTransactionAmount[from]
        ) {
          require(
            amount <= maxTransactionAmount,
            "Sell transfer amount exceeds the maxTransactionAmount."
          );
        } else {
          require(amount + balanceOf(to) <= maxWallet, "Max wallet exceeded");
        }
      }
    }

    uint256 contractTokenBalance = balanceOf(address(this));

    bool canSwap = contractTokenBalance >= swapTokensAtAmount;

    if (
      canSwap &&
      swapEnabled &&
      !swapping &&
      !automatedMarketMakerPairs[from] &&
      !_isExcludedFromFees[from] &&
      !_isExcludedFromFees[to]
    ) {
      swapping = true;

      swapBack();

      swapping = false;
    }

    bool takeFee = !swapping;

    // if any account belongs to _isExcludedFromFee account then remove the fee
    if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
      takeFee = false;
    }

    uint256 fees = 0;
    // only take fees on buys/sells, do not take on wallet transfers
    if (takeFee) {
      // on sell
      if (automatedMarketMakerPairs[to] && sellTotalFees > 0) {
        fees = amount.mul(sellTotalFees).div(100);
        tokensForLiquidity += (fees * sellLiquidityFee) / sellTotalFees;
        tokensForBuyBack += (fees * sellBuyBackFee) / sellTotalFees;
        tokensForDev += (fees * sellDevFee) / sellTotalFees;
        tokensForMarketing += (fees * sellMarketingFee) / sellTotalFees;
      }
      // on buy
      else if (automatedMarketMakerPairs[from] && buyTotalFees > 0) {
        fees = amount.mul(buyTotalFees).div(100);
        tokensForLiquidity += (fees * buyLiquidityFee) / buyTotalFees;
        tokensForBuyBack += (fees * buyBuyBackFee) / buyTotalFees;
        tokensForDev += (fees * buyDevFee) / buyTotalFees;
        tokensForMarketing += (fees * buyMarketingFee) / buyTotalFees;
      }

      if (fees > 0) {
        super._transfer(from, address(this), fees);
      }

      amount -= fees;
    }

    super._transfer(from, to, amount);
  }

  function swapTokensForEth(uint256 tokenAmount) private {
    // generate the uniswap pair path of token -> weth
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = uniswapV2Router.WETH();

    _approve(address(this), address(uniswapV2Router), tokenAmount);

    // make the swap
    uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
      tokenAmount,
      0, // accept any amount of ETH
      path,
      address(this),
      block.timestamp
    );
  }

  function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
    // approve token transfer to cover all possible scenarios
    _approve(address(this), address(uniswapV2Router), tokenAmount);

    // add the liquidity
    uniswapV2Router.addLiquidityETH{ value: ethAmount }(
      address(this),
      tokenAmount,
      0, // slippage is unavoidable
      0, // slippage is unavoidable
      liquidityWallet,
      block.timestamp
    );
  }

  function swapBack() private {
    uint256 contractBalance = balanceOf(address(this));
    uint256 totalTokensToSwap = tokensForLiquidity +
      tokensForMarketing +
      tokensForBuyBack +
      tokensForDev;

    if (contractBalance == 0 || totalTokensToSwap == 0) {
      return;
    }

    // Halve the amount of liquidity tokens
    uint256 liquidityTokens = (contractBalance * tokensForLiquidity) /
      totalTokensToSwap /
      2;
    uint256 amountToSwapForETH = contractBalance.sub(liquidityTokens);

    uint256 initialETHBalance = address(this).balance;

    swapTokensForEth(amountToSwapForETH);

    uint256 ethBalance = address(this).balance.sub(initialETHBalance);

    uint256 ethForMarketing = ethBalance.mul(tokensForMarketing).div(
      totalTokensToSwap
    );
    uint256 ethForDev = ethBalance.mul(tokensForDev).div(totalTokensToSwap);
    uint256 ethForBuyBack = ethBalance.mul(tokensForBuyBack).div(
      totalTokensToSwap
    );

    uint256 ethForLiquidity = ethBalance -
      ethForMarketing -
      ethForDev -
      ethForBuyBack;

    tokensForLiquidity = 0;
    tokensForMarketing = 0;
    tokensForBuyBack = 0;
    tokensForDev = 0;

    (bool success, ) = address(marketingWallet).call{ value: ethForMarketing }(
      ""
    );
    (success, ) = address(marketingWallet).call{ value: ethForDev }("");

    if (liquidityTokens > 0 && ethForLiquidity > 0) {
      addLiquidity(liquidityTokens, ethForLiquidity);
      emit SwapAndLiquify(
        amountToSwapForETH,
        ethForLiquidity,
        tokensForLiquidity
      );
    }

    // keep leftover ETH for buyback only if there is a buyback fee, if not, send the remaining ETH to the marketing wallet if it accumulates

    if (
      buyBuyBackFee == 0 &&
      sellBuyBackFee == 0 &&
      address(this).balance >= 1 ether
    ) {
      (success, ) = address(marketingWallet).call{
        value: address(this).balance
      }("");
    }
  }

  // force Swap back if slippage above 49% for launch.
  function forceSwapBack() external onlyOwner {
    uint256 contractBalance = balanceOf(address(this));
    require(
      contractBalance >= totalSupply() / 100,
      "Can only swap back if more than 1% of tokens stuck on contract"
    );
    swapBack();
    emit OwnerForcedSwapBack(block.timestamp);
  }

  // useful for buybacks or to reclaim any ETH on the contract in a way that helps holders.
  function buyBackTokens(uint256 ethAmountInWei) external onlyOwner {
    // generate the uniswap pair path of weth -> eth
    address[] memory path = new address[](2);
    path[0] = uniswapV2Router.WETH();
    path[1] = address(this);

    // make the swap
    uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{
      value: ethAmountInWei
    }(
      0, // accept any amount of Ethereum
      path,
      buybackWallet,
      block.timestamp
    );
    emit BuyBackTriggered(ethAmountInWei);
  }
}
