// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

const TOKEN_ADDRESS = "0xdb56B2922c7C275167A9A3129d36351Fd385Ed21";

async function main() {
  const [admin, proposer, executor] = await hre.ethers.getSigners();
  console.log(admin.address, proposer.address, executor.address);

  // We get the contract to deploy
  const HeroInfinityICO = await hre.ethers.getContractFactory(
    "HeroInfinityICO"
  );
  const ico = await HeroInfinityICO.deploy(6500, admin.address, TOKEN_ADDRESS);

  await ico.deployed();

  console.log("ICO deployed to: " + ico.address);

  await hre.run("verify:verify", {
    address: ico.address,
    constructorArguments: [6500, admin.address, TOKEN_ADDRESS],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
