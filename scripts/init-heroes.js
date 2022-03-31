// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const fetch = require("node-fetch");
const { HERO_LIST } = require("@heroinfinity/sdk/lib/hero");
const { formatBytes32String } = require("ethers/lib/utils");

const HERO_MANAGER_ADDRESS = "0x0c966628e4828958376a24ee66F5278A71c96aeE";
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
  // We get the contract to deploy
  const HeroManager = await hre.ethers.getContractFactory("HeroManager");
  const heroManager = await HeroManager.attach(HERO_MANAGER_ADDRESS);

  const nftIds = Array(29)
    .fill(0)
    .map((value, index) => index);
  const metadataPromises = nftIds.map((value) =>
    fetchAPI(`${BASE_URI}/${value}.json`)
  );
  const heroesMetadata = await Promise.all(metadataPromises);

  const methods = nftIds.map((value, index) =>
    heroManager.interface.encodeFunctionData("addHero", [
      value,
      [
        formatBytes32String(
          HERO_LIST.find((hero) => hero.fullName === heroesMetadata[index].name)
            .name
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
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
