// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { time } = require("@openzeppelin/test-helpers");

const MINDELAY = time.duration.days(1).toString(); // 1 day timelock
const TOKEN_ADDRESS = "0xdb56B2922c7C275167A9A3129d36351Fd385Ed21";

async function main() {
  const [admin, proposer, executor] = await hre.ethers.getSigners();
  console.log(admin.address, proposer.address, executor.address);

  const TokenGovernor = await hre.ethers.getContractFactory("TokenGovernor");
  const governor = await TokenGovernor.deploy(
    TOKEN_ADDRESS,
    MINDELAY,
    [proposer.address],
    [executor.address]
  );

  await governor.deployed();

  await hre.run("verify:verify", {
    address: governor.address,
    constructorArguments: [
      TOKEN_ADDRESS,
      MINDELAY,
      [proposer.address],
      [executor.address],
    ],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
