// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  const [admin, proposer, executor] = await hre.ethers.getSigners();
  console.log(admin.address, proposer.address, executor.address);

  // We get the contract to deploy
  const HeroInfinityToken = await hre.ethers.getContractFactory(
    "HeroInfinityToken"
  );
  const token = await HeroInfinityToken.deploy();

  await token.deployed();

  console.log("Token deployed to: " + token.address);

  try {
    await hre.run("verify:verify", {
      address: token.address,
    });
  } catch (err) {}
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
