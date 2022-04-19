// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

const hre = require("hardhat");
const { sleep } = require("./utils/sleep");
const { addHeroesMetadata } = require("./utils/metadata");
const { updateSDK } = require("./utils/sdk");

const TOKEN_ADDRESS = "0x28ee3E2826264b9c55FcdD122DFa93680916c9b8";
const NFT_ADDRESS = "0x76b713ff56b9CAD82b2820202537A98182b5A0EC";
const NODE_ADDRESS = "0xa0f90c8111465e75e5b7e0d85de0dcdc185da1ae";

async function main() {
  const HeroManager = await hre.ethers.getContractFactory("HeroManager");
  const heroManager = await HeroManager.deploy(TOKEN_ADDRESS, NFT_ADDRESS);
  await heroManager.deployed();

  const LobbyManager = await hre.ethers.getContractFactory("LobbyManager");
  const lobbyManager = await LobbyManager.deploy(NODE_ADDRESS);
  await lobbyManager.deployed();

  const DataProcessor = await hre.ethers.getContractFactory("DataProcessor");
  const dataProcessor = await DataProcessor.deploy(
    heroManager.address,
    lobbyManager.address
  );
  await dataProcessor.deployed();

  const Randomness = await hre.ethers.getContractFactory("Randomness");
  const randomness = await Randomness.deploy();
  await randomness.deployed();

  const Battle1vs1 = await hre.ethers.getContractFactory("Battle1vs1");
  const battle1vs1 = await Battle1vs1.deploy(
    heroManager.address,
    lobbyManager.address,
    randomness.address
  );
  await battle1vs1.deployed();

  await heroManager.setLobbyManager(lobbyManager.address);
  await lobbyManager.setHeroManager(heroManager.address);
  await lobbyManager.setHeroManager(heroManager.address);
  await lobbyManager.setBattleAddress(1, battle1vs1.address);

  console.log("Contracts deployed!");

  await addHeroesMetadata(heroManager);
  await updateSDK([
    ["heroManager", heroManager.address],
    ["lobbyManager", lobbyManager.address],
    ["dataProcessor", dataProcessor.address],
  ]);

  console.log("HeroManager deployed to: " + heroManager.address);
  console.log("LobbyManager deployed to: " + lobbyManager.address);
  console.log("DataProcessor deployed to: " + dataProcessor.address);

  await sleep(100000);

  let heroManagerVerified = false;
  do {
    try {
      await hre.run("verify:verify", {
        address: heroManager.address,
        contract: "contracts/game/HeroManager.sol:HeroManager",
        constructorArguments: [TOKEN_ADDRESS, NFT_ADDRESS],
      });
      heroManagerVerified = true;
    } catch (err) {}
  } while (!heroManagerVerified);

  let lobbyManagerVerified = false;
  do {
    try {
      await hre.run("verify:verify", {
        address: LobbyManager.address,
        contract: "contracts/game/LobbyManager.sol:LobbyManager",
        constructorArguments: [NODE_ADDRESS],
      });
      lobbyManagerVerified = true;
    } catch (err) {}
  } while (!lobbyManagerVerified);

  let dataProcessorVerified = false;
  do {
    try {
      await hre.run("verify:verify", {
        address: dataProcessor.address,
        contract: "contracts/game/DataProcessor.sol:DataProcessor",
        constructorArguments: [heroManager.address, lobbyManager.address],
      });
      dataProcessorVerified = true;
    } catch (err) {}
  } while (!dataProcessorVerified);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
