// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { MINDELAY } = require("./constants");

const TOKEN_ADDRESS = "0xB4d6Ba463Bf0386761a0Eff0024B4680f7c3979a";
const GOVERNOR_ADDRESS = "0x7F3Ce95EEA1B02419d0e1bAfaA292Fe2c2591dBF";

async function main() {
  const [, proposer, executor] = await hre.ethers.getSigners();

  try {
    await hre.run("verify:verify", {
      address: TOKEN_ADDRESS,
      contract: "contracts/HeroInfinityToken.sol:HeroInfinityToken",
    });
  } catch (err) {
    console.log(err);
  }

  try {
    await hre.run("verify:verify", {
      address: GOVERNOR_ADDRESS,
      constructorArguments: [MINDELAY, [proposer.address], [executor.address]],
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
