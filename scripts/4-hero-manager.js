// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { sleep } = require("./utils/sleep");
const { addHeroesMetadata } = require("./utils/metadata");

const TOKEN_ADDRESS = "0x28ee3E2826264b9c55FcdD122DFa93680916c9b8";
const NFT_ADDRESS = "0x76b713ff56b9CAD82b2820202537A98182b5A0EC";

async function main() {
  // We get the contract to deploy
  const HeroManager = await hre.ethers.getContractFactory("HeroManager");
  const heroManager = await HeroManager.deploy(TOKEN_ADDRESS, NFT_ADDRESS);
  await heroManager.deployed();

  await addHeroesMetadata(heroManager);

  await sleep(60000);

  try {
    await hre.run("verify:verify", {
      address: heroManager.address,
      contract: "contracts/game/HeroManager.sol:HeroManager",
      constructorArguments: [TOKEN_ADDRESS, NFT_ADDRESS],
    });
  } catch (err) {
    console.log(err);
  }

  console.log("HeroManager deployed to: " + heroManager.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
