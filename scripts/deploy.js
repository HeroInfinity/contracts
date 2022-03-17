// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { MINDELAY } = require("./constants");

async function main() {
  const [admin, proposer, executor] = await hre.ethers.getSigners();
  console.log(admin.address, proposer.address, executor.address);

  // We get the contract to deploy
  const HeroInfinityToken = await hre.ethers.getContractFactory(
    "HeroInfinityToken"
  );
  const token = await HeroInfinityToken.deploy();

  await token.deployed();

  const TokenGovernor = await hre.ethers.getContractFactory("TokenGovernor");
  const governor = await TokenGovernor.deploy(
    MINDELAY,
    [proposer.address],
    [executor.address]
  );

  await governor.deployed();

  console.log("Token deployed to: " + token.address);
  console.log("Governor deployed to: " + governor.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

module.exports = {
  MINDELAY,
};
