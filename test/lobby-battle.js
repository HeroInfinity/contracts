const { expect } = require("chai");
const { ethers } = require("hardhat");
const fetch = require("node-fetch");
const { chunk } = require("lodash");
const { formatBytes32String, parseEther } = require("ethers/lib/utils");
const { constants } = require("ethers");
const { HERO_LIST } = require("@heroinfinity/sdk/lib/hero");

const NFT_NUMBER = 50;
const BASE_URI =
  "https://heroinfinity.mypinata.cloud/ipfs/QmdpC8hrgY5gVCTaNnn3vCzfXaeMLu1THxoGvBJrRPv165";
const RARITY_MAP = {
  Common: 0,
  Rare: 1,
  Mythical: 2,
  Legendary: 3,
  Immortal: 4,
};
const ATTRIBUTE_MAP = {
  Strength: 0,
  Agility: 1,
  Intelligence: 2,
};
const ATTACK_CAPABILITY_MAP = {
  Melee: 1,
  Ranged: 2,
};

const fetchAPI = (url) => {
  return new Promise((resolve) => {
    fetch(url)
      .then((data) => data.json())
      .then((data) => resolve(data));
  });
};

describe("Lobby Manager", function () {
  let token;
  let nft;
  let node;
  let heroManager;
  let lobbyManager;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    const [admin, user1, user2] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("TestToken");
    token = await Token.deploy();
    await token.deployed();

    const Node = await ethers.getContractFactory("TestNodePool");
    node = await Node.deploy(token.address);
    await node.deployed();

    const HeroInfinityNFT = await ethers.getContractFactory("HeroInfinityNFT");
    nft = await HeroInfinityNFT.deploy();
    await nft.deployed();

    await nft.setNodePool(node.address);
    await nft.setTimestamps(1664959669);
    await nft.setBaseURI(BASE_URI + "/");

    const mintPrice = await nft.mintPrice(admin.address);
    await nft.connect(admin).mint(5, { value: mintPrice.mul(5) });
    await nft.connect(user1).mint(5, { value: mintPrice.mul(5) });
    await nft.connect(user2).mint(5, { value: mintPrice.mul(5) });

    const HeroManager = await ethers.getContractFactory("HeroManager");
    heroManager = await HeroManager.deploy(token.address, nft.address);
    await heroManager.deployed();

    const LobbyManager = await ethers.getContractFactory("LobbyManager");
    lobbyManager = await LobbyManager.deploy();
    await lobbyManager.deployed();

    const Battle1vs1 = await ethers.getContractFactory("Battle1vs1");
    const battle1vs1 = await Battle1vs1.deploy(
      heroManager.address,
      lobbyManager.address
    );
    await battle1vs1.deployed();

    await heroManager.setLobbyManager(lobbyManager.address);
    await heroManager.setRewardsPayeer(admin.address);
    await lobbyManager.setHeroManager(heroManager.address);
    await lobbyManager.setHeroManager(heroManager.address);
    await lobbyManager.setBattleAddress(1, battle1vs1.address);

    const nftIds = Array(NFT_NUMBER)
      .fill(0)
      .map((v, index) => index);

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
            RARITY_MAP[heroesMetadata[index].attributes[0].value],
            ATTRIBUTE_MAP[heroesMetadata[index].attributes[1].value],
            ATTACK_CAPABILITY_MAP[heroesMetadata[index].attributes[2].value],
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
  });

  it("create lobby costs fee", async function () {
    const [, user] = await ethers.getSigners();

    await token.transfer(user.address, parseEther("100000000"));
    const beforeBalance = await token.balanceOf(user.address);

    const nftId = await nft.tokenOfOwnerByIndex(user.address, 0);

    console.log(nftId);

    await token
      .connect(user)
      .approve(lobbyManager.address, constants.MaxUint256);

    await lobbyManager
      .connect(user)
      .createLobby(
        formatBytes32String("lb1"),
        formatBytes32String("avatar1"),
        1,
        [nftId]
      );

    const fee = await lobbyManager.lobbyFees(1);
    const afterBalance = await token.balanceOf(user.address);

    expect(beforeBalance.sub(fee)).to.equal(afterBalance);
  });

  it("create lobby reduce hero energy", async function () {
    const [admin] = await ethers.getSigners();
    const nft1 = await nft.tokenOfOwnerByIndex(admin.address, 0);
    await token.approve(lobbyManager.address, constants.MaxUint256);
    await lobbyManager.createLobby(
      formatBytes32String("lb1"),
      formatBytes32String("avatar1"),
      1,
      [nft1]
    );
    await lobbyManager.createLobby(
      formatBytes32String("lb2"),
      formatBytes32String("avatar2"),
      1,
      [nft1]
    );
    await lobbyManager.createLobby(
      formatBytes32String("lb3"),
      formatBytes32String("avatar3"),
      1,
      [nft1]
    );
    await lobbyManager.createLobby(
      formatBytes32String("lb4"),
      formatBytes32String("avatar4"),
      1,
      [nft1]
    );
    await lobbyManager.createLobby(
      formatBytes32String("lb5"),
      formatBytes32String("avatar5"),
      1,
      [nft1]
    );

    const energy = await heroManager.heroEnergy(nft1);

    expect(energy.toNumber()).to.equal(0);
    expect(
      lobbyManager.createLobby(
        formatBytes32String("lb6"),
        formatBytes32String("avatar6"),
        1,
        [nft1]
      )
    ).to.be.revertedWith("HeroManager: not enough energy");

    ethers.provider.send("evm_increaseTime", [1 * 24 * 60 * 60]);
    await lobbyManager.createLobby(
      formatBytes32String("lb6"),
      formatBytes32String("avatar6"),
      1,
      [nft1]
    );

    const energyAfterday = await heroManager.heroEnergy(nft1);
    expect(energyAfterday.toNumber()).to.equal(4);
  });

  // it("join lobby costs fee", async function () {
  //   const [admin, user] = await ethers.getSigners();

  //   await token.transfer(user.address, parseEther("100000000"));

  //   const nft1 = await nft.tokenOfOwnerByIndex(admin.address, 0);
  //   const nft2 = await nft.tokenOfOwnerByIndex(user.address, 0);

  //   console.log((await token.balanceOf(user.address)).toString());

  //   console.log(nft2);
  //   await token.approve(lobbyManager.address, constants.MaxUint256);
  //   await token
  //     .connect(user)
  //     .approve(lobbyManager.address, constants.MaxUint256);

  //   await lobbyManager.createLobby(
  //     formatBytes32String("lb1"),
  //     formatBytes32String("avatar1"),
  //     1,
  //     [nft1]
  //   );

  //   await lobbyManager.connect(user).joinLobby(1, [nft2]);

  //   const lobby = await lobbyManager.lobbies(1);
  //   console.log(lobby);

  //   console.log(await heroManager.heroes(nft1));
  //   console.log(await heroManager.heroes(nft2));
  // });
});
