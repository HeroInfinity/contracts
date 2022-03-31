// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { constants } = require("ethers");
const hre = require("hardhat");

const HERO_MANAGER_ADDRESS = "0xedAD9C02964BB613d83c01cb5c02cB4b4128551c";

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
