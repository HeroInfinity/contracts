// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { sleep } = require("./utils/sleep");

async function main() {
  // We get the contract to deploy
  const Randomness = await hre.ethers.getContractFactory("Randomness");
  // const randomness = await Randomness.deploy();

  // await randomness.deployed();

  // const HeroManager = await hre.ethers.getContractFactory("HeroManager");
  // const heroManager = await HeroManager.deploy();

  // await randomness.deployed();
  // await heroManager.deployed();

  // await sleep(30000);

  // try {
  //   await hre.run("verify:verify", {
  //     address: randomness.address,
  //     contract: "contracts/game/Randomness.sol:Randomness",
  //   });
  // } catch (err) {
  //   console.log(err);
  // }
  try {
    await hre.run("verify:verify", {
      address: "0x23672E1565593bF54E89BEAF3E380eCa1cB3Bd09",
      contract: "contracts/game/HeroManager.sol:HeroManager",
    });
  } catch (err) {
    console.log(err);
  }

  // console.log("Randomness deployed to: " + randomness.address);
  // console.log("HeroManager deployed to: " + heroManager.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
