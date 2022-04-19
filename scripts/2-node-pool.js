// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { sleep } = require("./utils/sleep");

async function main() {
  const HeroInfinityNodePoolV2 = await hre.ethers.getContractFactory(
    "HeroInfinityNodePoolV2"
  );
  const nodePool = await HeroInfinityNodePoolV2.deploy();
  await nodePool.deployed();

  await sleep(60000);

  try {
    await hre.run("verify:verify", {
      address: nodePool.address,
      contract: "contracts/HeroInfinityNodePoolV2.sol:HeroInfinityNodePoolV2",
    });
  } catch (err) {
    console.log(err);
  }

  console.log("NodePool deployed to: " + nodePool.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
