// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
// const { MINDELAY } = require("./constants");

const TOKEN_ADDRESS = "0xD0055DEaa682334e806623130C0566d634D8A5Ee";
// const GOVERNOR_ADDRESS = "0xD48a20B653CC8f6485f9655f72BF2b81cF12c4c3";
const NODE_POOL_ADDRESS = "0xD48a20B653CC8f6485f9655f72BF2b81cF12c4c3";

async function main() {
  // const [, proposer, executor] = await hre.ethers.getSigners();

  try {
    await hre.run("verify:verify", {
      address: TOKEN_ADDRESS,
      contract: "contracts/HeroInfinityToken.sol:HeroInfinityToken",
    });
  } catch (err) {
    console.log(err);
  }

  // try {
  //   await hre.run("verify:verify", {
  //     address: GOVERNOR_ADDRESS,
  //     constructorArguments: [MINDELAY, [proposer.address], [executor.address]],
  //   });
  // } catch (err) {
  //   console.log(err);
  // }

  try {
    await hre.run("verify:verify", {
      address: NODE_POOL_ADDRESS,
      contract: "contracts/HeroInfinityNodePool.sol:HeroInfinityNodePool",
    });
  } catch (err) {
    console.log(err);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
