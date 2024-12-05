import * as dotenv from "dotenv";

import "@nomicfoundation/hardhat-foundry";
import "@matterlabs/hardhat-zksync";
import "@nomiclabs/hardhat-solhint";
import "@typechain/hardhat";
import fs from "fs";
import "hardhat-preprocessor";
import { HardhatUserConfig } from "hardhat/config";

dotenv.config();

let deployPrivateKey = process.env.PRIVATE_KEY as string;
if (!deployPrivateKey) {
  // default first account deterministically created by local nodes like `npx hardhat node` or `anvil`
  throw "No deployer private key set in .env";
}

/**
 * Generates hardhat network configuration
 * @type import('hardhat/config').HardhatUserConfig
 */
const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.26",
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
    sophonMainnet: {
      url: "https://rpc.sophon.xyz",
      ethNetwork: "mainnet",
      verifyURL: "https://verification-explorer.sophon.xyz/contract_verification",
      browserVerifyURL: "https://explorer.sophon.xyz/",
      enableVerifyURL: true,
      zksync: true,
      accounts: [process.env.PRIVATE_KEY as string],
      chainId: 50104,
    },
  },
  paths: {
    sources: "./contracts",
    cache: "./cache_hardhat",
  },
  zksolc: {
    version: "1.5.12",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10000,
        mode: "z",
        fallback_to_optimizing_for_size: true,
      },
    },
  },
  etherscan: {
    enabled: true,
    apiKey: {
      sophonTestnet: process.env.ETHERSCAN_SOPHON_API_KEY as string,
      sophonMainnet: process.env.ETHERSCAN_SOPHON_API_KEY as string,
    },
    customChains: [
      {
        network: "sophonTestnet",
        chainId: 531050104,
        urls: {
          apiURL: "https://api-testnet.sophscan.xyz/api",
          browserURL: "https://testnet.sophscan.xyz",
        },
      },
      {
        network: "sophonMainnet",
        chainId: 50104,
        urls: {
          apiURL: "https://api.sophscan.xyz/api",
          browserURL: "https://sophscan.xyz",
        },
      },
      {
        network: "zkSyncTestnet",
        chainId: 300,
        urls: {
          apiURL: "https://api-testnet-era.zksync.network/api",
          browserURL: "https://testnet-era.zksync.network",
        },
      },
    ],
  },
};

export default config;
