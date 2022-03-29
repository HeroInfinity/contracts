// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { sleep } = require("./utils/sleep");

async function main() {
  // We get the contract to deploy
  const HeroInfinityNFT = await hre.ethers.getContractFactory(
    "HeroInfinityNFT"
  );

  const nodepool = "0xFAd5Ef0F347eb7bB89E798B5d026F60aFA3E2bF4";

  const nft = await HeroInfinityNFT.deploy(nodepool);

  await nft.deployed();

  await sleep(30000);

  try {
    await hre.run("verify:verify", {
      address: nft.address,
      constructorArguments: [nodepool],
    });
  } catch (err) {
    console.log(err);
  }

  console.log("NFT deployed to: " + nft.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
