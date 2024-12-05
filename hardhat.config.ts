import * as dotenv from "dotenv";
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");

dotenv.config();

let deployPrivateKey = process.env.PV_KEY as string;
if (!deployPrivateKey) {
  // default first account deterministically created by local nodes like `npx hardhat node` or `anvil`
  throw "No deployer private key set in .env";
}

module.exports = {
  solidity: {
    version: "0.8.20",
    evmVersion: "paris",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10000,
      },
      viaIR: true,
    },
    // @ts-ignore
  },
  networks: {
    iotex: {
      chainId: 4689,
      url: "https://babel-api.mainnet.iotex.io",
      accounts: [deployPrivateKey],
    },
    tangle: {
      chainId: 5845,
      url: "https://rpc.tangle.tools",
      accounts: [deployPrivateKey],
    },
  },
  etherscan: {
    apiKey: {
      iotex: "empty",
      tangle: "empty",
    },
    customChains: [
      {
        network: "iotex",
        chainId: 4689,
        urls: {
          apiURL: "https://IoTeXscout.io/api",
          browserURL: "https://IoTeXscan.io",
        },
      },
      {
        network: "tangle",
        chainId: 5845,
        urls: {
          apiURL: "https://explorer.tangle.tools/api",
          browserURL: "http://explorer.tangle.tools",
        },
      },
    ],
  },
};
