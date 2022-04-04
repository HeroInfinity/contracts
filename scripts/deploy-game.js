// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

const { HERO_LIST } = require("@heroinfinity/sdk/lib/hero");
const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const fetch = require("node-fetch");
const hre = require("hardhat");
const { chunk } = require("lodash");
const { formatBytes32String } = require("ethers/lib/utils");
const { sleep } = require("./utils/sleep");

const NFT_NUMBER = 100;

const ADDRESSES_PATH = path.resolve(
  __dirname,
  "../../sdk/constants/addresses.json"
);
const PACKAGE_PATH = path.resolve(__dirname, "../../sdk/package.json");
const BASE_URI =
  "https://heroinfinity.mypinata.cloud/ipfs/QmdpC8hrgY5gVCTaNnn3vCzfXaeMLu1THxoGvBJrRPv165";

const fetchAPI = (url) => {
  return new Promise((resolve) => {
    fetch(url)
      .then((data) => data.json())
      .then((data) => resolve(data));
  });
};

const rarityMap = {
  Common: 0,
  Rare: 1,
  Mythical: 2,
  Legendary: 3,
  Immortal: 4,
};
const attributeMap = {
  Strength: 0,
  Agility: 1,
  Intelligence: 2,
};
const attackCapabilityMap = {
  Melee: 1,
  Ranged: 2,
};

async function main() {
  const HeroManager = await hre.ethers.getContractFactory("HeroManager");
  const heroManager = await HeroManager.deploy();

  await heroManager.deployed();

  const LobbyBattle = await hre.ethers.getContractFactory("LobbyBattle");
  const lobbyBattle = await LobbyBattle.deploy();

  await lobbyBattle.deployed();

  await heroManager.setLobbyBattle(lobbyBattle.address);
  await lobbyBattle.setHeroManager(heroManager.address);

  console.log("Contracts deployed!");

  const nftIds = Array(NFT_NUMBER)
    .fill(0)
    .map((v, index) => index);

  let it = 1;

  for (const ck of chunk(nftIds, 100)) {
    const heroesMetadata = await Promise.all(
      ck.map((value) => fetchAPI(`${BASE_URI}/${value}.json`))
    );
    const methods = ck.map((value, index) =>
      heroManager.interface.encodeFunctionData("addHero", [
        value,
        [
          formatBytes32String(
            HERO_LIST.find(
              (hero) => hero.fullName === heroesMetadata[index].name
            ).name
          ),
          1,
          rarityMap[heroesMetadata[index].attributes[0].value],
          attributeMap[heroesMetadata[index].attributes[1].value],
          attackCapabilityMap[heroesMetadata[index].attributes[2].value],
          (heroesMetadata[index].attributes[3].value * 10 ** 18).toString(),
          (heroesMetadata[index].attributes[6].value * 10 ** 18).toString(),
          (heroesMetadata[index].attributes[4].value * 10 ** 18).toString(),
          (heroesMetadata[index].attributes[7].value * 10 ** 18).toString(),
          (heroesMetadata[index].attributes[5].value * 10 ** 18).toString(),
          (heroesMetadata[index].attributes[8].value * 10 ** 18).toString(),
          0,
        ],
      ])
    );

    await (await heroManager.multicall(methods)).wait();
    console.log("Metadata initiated: " + it++);
  }

  console.log("Metadata fully initiated!");

  execSync(
    `find ${path.resolve(
      __dirname,
      "../artifacts/contracts"
    )} -regex '.*[^(dbg)].json' -exec cp "{}" ${path.resolve(
      __dirname,
      "../../sdk/artifacts/"
    )} \\;`
  );
  const addresses = JSON.parse(fs.readFileSync(ADDRESSES_PATH));
  addresses.testnet.heroManager = heroManager.address;
  addresses.testnet.lobbyBattle = lobbyBattle.address;
  fs.writeFileSync(ADDRESSES_PATH, JSON.stringify(addresses, undefined, 2));

  const package = JSON.parse(fs.readFileSync(PACKAGE_PATH));
  const versions = package.version.split(".");
  const newVersion =
    versions[0] + "." + versions[1] + "." + (parseInt(versions[2]) + 1);
  package.version = newVersion;
  fs.writeFileSync(PACKAGE_PATH, JSON.stringify(package, undefined, 2));

  execSync(
    `cd ${path.resolve(
      __dirname,
      "../../sdk"
    )} && git add . && git commit -m "version ${newVersion}" && git push`
  );

  console.log("HeroManager deployed to: " + heroManager.address);
  console.log("LobbyBattle deployed to: " + lobbyBattle.address);
  console.log("New version: " + newVersion);

  await sleep(100000);

  let heroManagerVerified = false;
  do {
    try {
      await hre.run("verify:verify", {
        address: heroManager.address,
        contract: "contracts/game/HeroManager.sol:HeroManager",
      });
      heroManagerVerified = true;
    } catch (err) {}
  } while (!heroManagerVerified);

  let lobbyBattleVerified = false;
  do {
    try {
      await hre.run("verify:verify", {
        address: lobbyBattle.address,
        contract: "contracts/game/LobbyBattle.sol:LobbyBattle",
      });
      lobbyBattleVerified = true;
    } catch (err) {}
  } while (!lobbyBattleVerified);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
