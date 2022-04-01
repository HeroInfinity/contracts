// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { sleep } = require("./utils/sleep");

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

  console.log("LobbyBattle deployed to: " + lobbyBattle.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});