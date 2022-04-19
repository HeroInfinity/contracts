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
  const randomness = await Randomness.deploy();

  await randomness.deployed();

  for (let i = 0; i < 10000; i++) {
    const randomNumber = await randomness.random(1, 2);
    console.log(randomNumber);
    await sleep(1000);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
