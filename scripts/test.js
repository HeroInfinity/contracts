// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { constants } = require("ethers");
const hre = require("hardhat");

const HERO_MANAGER_ADDRESS = "0xb1C55A4ADA7E00E8682761faC0dEE6b8f48BEC02";

async function main() {
  // We get the contract to deploy
  console.log(constants.MaxUint256.toString());

  const HeroManager = await hre.ethers.getContractFactory("HeroManager");
  const heroManager = await HeroManager.attach(HERO_MANAGER_ADDRESS);

  await heroManager.levelUp(4, 20);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
