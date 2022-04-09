// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { addHeroesMetadata } = require("./utils/metadata");

const HERO_MANAGER_ADDRESS = "0xc04fe537b99ADFDAc0647834E022b5a8B3dec9bF";

async function main() {
  // We get the contract to deploy
  const HeroManager = await hre.ethers.getContractFactory("HeroManager");
  const heroManager = await HeroManager.attach(HERO_MANAGER_ADDRESS);

  await addHeroesMetadata(heroManager);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
