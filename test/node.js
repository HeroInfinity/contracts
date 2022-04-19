const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseEther } = require("ethers/lib/utils");
const { constants } = require("ethers");

describe("Node Pool", function () {
  let token;
  let node;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    const Token = await ethers.getContractFactory("TestToken");
    token = await Token.deploy();
    await token.deployed();

    const Node = await ethers.getContractFactory("HeroInfinityNodePoolV2");
    node = await Node.deploy(token.address);
    await node.deployed();
  });

  it("create nodes", async function () {
    const [, user] = await ethers.getSigners();

    await token.transfer(user.address, parseEther("100000000"));

    await token.connect(user).approve(node.address, constants.MaxUint256);

    await node.connect(user).createNode("testnode", 1);
    const fee = await node.feeAmount();

    await ethers.provider.send("evm_increaseTime", [29 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");
    await node.connect(user).payAllNodesFee({
      value: fee,
    });

    await ethers.provider.send("evm_increaseTime", [29 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");
    await node.connect(user).payAllNodesFee({
      value: fee,
    });

    await ethers.provider.send("evm_increaseTime", [29 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");
    await node.connect(user).payAllNodesFee({
      value: fee,
    });

    await ethers.provider.send("evm_increaseTime", [29 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");
    await node.connect(user).payAllNodesFee({
      value: fee,
    });

    await ethers.provider.send("evm_increaseTime", [29 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");
    await node.connect(user).payAllNodesFee({
      value: fee,
    });

    await ethers.provider.send("evm_increaseTime", [29 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");
    await node.connect(user).payAllNodesFee({
      value: fee,
    });

    await ethers.provider.send("evm_increaseTime", [29 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");
    await node.connect(user).payAllNodesFee({
      value: fee,
    });

    await ethers.provider.send("evm_increaseTime", [29 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");
    const totalAmount = await node.getRewardTotalAmountOf(user.address);
    console.log(totalAmount);
  });
});
