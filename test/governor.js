const { ethers } = require("hardhat");
const { constants, time } = require("@openzeppelin/test-helpers");
const { ZERO_BYTES32 } = constants;

const MINDELAY = time.duration.days(1).toString();

const sleep = (seconds) =>
  new Promise((resolve) => setTimeout(resolve, seconds * 1000));

describe("Timelock", function () {
  this.timeout(99999999);
  it("Timelock Execute", async function () {
    const [admin, proposer, executor] = await ethers.getSigners();

    const HeroInfinityToken = await ethers.getContractFactory(
      "HeroInfinityToken"
    );
    const token = await HeroInfinityToken.attach(
      "0xdb56B2922c7C275167A9A3129d36351Fd385Ed21"
    );

    const HeroInfinityICO = await ethers.getContractFactory("HeroInfinityICO");
    const ico = await HeroInfinityICO.attach(
      "0x93C01cCc4FAf5a1254fe789c110e59229167CF19"
    );

    const TokenGovernor = await ethers.getContractFactory("TokenGovernor");
    const governor = await TokenGovernor.attach(
      "0xD5c0675aA28A2033e98b6e88b2068ae9568Fadf8"
    );

    const calldata = ico.interface.encodeFunctionData("takeTokens", [
      "0xdb56B2922c7C275167A9A3129d36351Fd385Ed21",
    ]);

    const SALT =
      "0x025e7b0be353a74631ad648c667493c0e1cd31caa4cc2d3520fdc171ea0cc100";

    // await governor
    //   .connect(proposer)
    //   .schedule(ico.address, 0, calldata, ZERO_BYTES32, SALT, MINDELAY);

    // try {
      await governor
        .connect(executor)
        .execute(ico.address, 0, calldata, ZERO_BYTES32, SALT);
    // } catch (err) {
    //   console.log(err);
    // }
  });

  // it("Should deploy DotaToken", async function () {
  //   const [admin, proposer, executor] = await ethers.getSigners();

  //   const HeroInfinityToken = await ethers.getContractFactory(
  //     "HeroInfinityToken"
  //   );
  //   const token = await HeroInfinityToken.attach(
  //     "0x4A705cDBec34a0918B010bc74fa8d8923F25dE99"
  //   );

  //   const TokenGovernor = await ethers.getContractFactory("TokenGovernor");
  //   const governor = await TokenGovernor.attach(
  //     "0xEe263De4bF8708A4de3B7B1c4CDD91145f6b36Cf"
  //   );

  //   const calldata = governor.interface.encodeFunctionData("tokenTransfer", [
  //     "0x6C52304efF12b7c0fBacf60bA7bC106BD03FE964",
  //     "10000000000000000000000",
  //   ]);
  //   // const calldata = governor.interface.encodeFunctionData("updateDelay", [
  //   //   MINDELAY,
  //   // ]);

  //   const SALT =
  //     "0x025e7b0be353a74631ad648c667493c0e1cd31caa4cc2d3520fdc171ea0cc100";

  //   console.log(MINDELAY);

  //   this.operation = genOperation(
  //     token.address,
  //     0,
  //     calldata,
  //     ZERO_BYTES32,
  //     SALT
  //   );
  //   console.log(this.operation);

  //   await governor
  //     .connect(proposer)
  //     .schedule(governor.address, 0, calldata, ZERO_BYTES32, SALT, MINDELAY);
  //   console.log("Scheduled!");

  //   await sleep(10);

  //   try {
  //     await governor
  //       .connect(executor)
  //       .execute(governor.address, 0, calldata, ZERO_BYTES32, SALT);
  //   } catch (err) {
  //     console.log(err);
  //   }

  //   // await expectRevert(
  //   //   governor
  //   //     .connect(executor)
  //   //     .execute(token.address, 0, calldata, ZERO_BYTES32, SALT),
  //   //   "Test"
  //   // );

  //   // const setGreetingTx = await greeter.setGreeting("Hola, mundo!");

  //   // // wait until the transaction is mined
  //   // await setGreetingTx.wait();

  //   // expect(await greeter.greet()).to.equal("Hola, mundo!");
  // });
});
