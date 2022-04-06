// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const ADDRESSES_PATH = path.resolve(
  __dirname,
  "../../../sdk/constants/addresses.json"
);
const PACKAGE_PATH = path.resolve(__dirname, "../../../sdk/package.json");

const updateSDK = async (newAddresses) => {
  execSync(
    `find ${path.resolve(
      __dirname,
      "../../artifacts/contracts"
    )} -regex '.*[^(dbg)].json' -exec cp "{}" ${path.resolve(
      __dirname,
      "../../../sdk/artifacts/"
    )} \\;`
  );
  const addresses = JSON.parse(fs.readFileSync(ADDRESSES_PATH));
  newAddresses.forEach((na) => {
    addresses.testnet[na[0]] = na[1];
  });
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
      "../../../sdk"
    )} && git add . && git commit -m "version ${newVersion}" && git push`
  );

  console.log("New version: " + newVersion);
};

module.exports = {
  updateSDK,
};
