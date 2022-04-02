// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { sleep } = require("./utils/sleep");

const HERO_MANAGER_ADDRESS = "0x0c966628e4828958376a24ee66F5278A71c96aeE";

async function main() {
  // We get the contract to deploy
  const LobbyBattle = await hre.ethers.getContractFactory("LobbyBattle");
  const lobbyBattle = await LobbyBattle.deploy();

  await lobbyBattle.deployed();

  await sleep(60000);

  try {
    await hre.run("verify:verify", {
      address: lobbyBattle.address,
      contract: "contracts/game/LobbyBattle.sol:LobbyBattle",
    });
  } catch (err) {
    console.log(err);
  }

  const HeroManager = await hre.ethers.getContractFactory("HeroManager");
  const heroManager = HeroManager.attach(HERO_MANAGER_ADDRESS);

  await heroManager.setLobbyBattle(lobbyBattle.address);

  console.log("LobbyBattle deployed to: " + lobbyBattle.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
