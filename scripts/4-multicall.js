// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { sleep } = require("./utils/sleep");

async function main() {
  const HeroInfinityMulticall = await hre.ethers.getContractFactory(
    "HeroInfinityMulticall"
  );
  const multicall = await HeroInfinityMulticall.deploy();
  await multicall.deployed();

  console.log("HeroInfinityMulticall deployed to: " + multicall.address);

  await sleep(60000);

  try {
    await hre.run("verify:verify", {
      address: multicall.address,
      contract: "contracts/HeroInfinityMulticall.sol:HeroInfinityMulticall",
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
