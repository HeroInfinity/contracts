// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { sleep } = require("./utils/sleep");

async function main() {
  const HeroInfinityWallet = await hre.ethers.getContractFactory(
    "HeroInfinityWallet"
  );
  const wallet = await HeroInfinityWallet.deploy();
  await wallet.deployed();

  console.log("HeroInfinityWallet deployed to: " + wallet.address);

  await sleep(60000);

  try {
    await hre.run("verify:verify", {
      address: wallet.address,
      contract: "contracts/HeroInfinityWallet.sol:HeroInfinityWallet",
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
