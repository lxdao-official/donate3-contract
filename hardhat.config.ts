import * as dotenv from "dotenv";

import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "hardhat-abi-exporter";

dotenv.config();

//add proxy to ethersacn api
// const { setGlobalDispatcher, ProxyAgent } = require('undici');
// const proxyAgent = new ProxyAgent('http://172.23.240.1:7890');
// setGlobalDispatcher(proxyAgent);

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    localhost: {
      url: "http://localhost:8545",
    },
    polygonMumbai:{
      url: process.env.MUMBAI_API_KEY_URL,
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    goerli: {
      url: process.env.GOERLI_API_KEY_URL,
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    mainnet: {
      url: process.env.ETH_MAINNER_API_KEY_URL,
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
  },
  etherscan: {
    apiKey: {
      polygonMumbai: process.env.POLYGONSCAN_KEY,
      goerli: process.env.ETHERSCAN_API_KEY,
    },
//     customChains: [
//       {
//         network: "polygonMumbai",
//         chainId: 80001,
//         urls: {
//           apiURL: "https://api-mumbai.polygonscan.com//api",  // https => http
//           browserURL: "https://api-mumbai.polygonscan.com"
//         }
//       }
//     ]
  },
};

export default config;
