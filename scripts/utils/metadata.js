// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

const { HERO_LIST } = require("@heroinfinity/sdk/lib/hero");
const fetch = require("node-fetch");
const { chunk } = require("lodash");
const { formatBytes32String } = require("ethers/lib/utils");

const NFT_NUMBER = 100;
const BASE_URI =
  "https://heroinfinity.mypinata.cloud/ipfs/QmShqcYMpJQLZnyNqxqGZqb9zaE2CXPntuMVx4v6idNHas";

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

const addHeroesMetadata = async (heroManager) => {
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
};

module.exports = {
  addHeroesMetadata,
};
