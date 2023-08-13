import '@nomicfoundation/hardhat-toolbox';
import '@nomiclabs/hardhat-solhint';
import 'hardhat-dependency-compiler';
import { HardhatUserConfig } from 'hardhat/config';
import * as dotenv from "dotenv";
dotenv.config();


const config: HardhatUserConfig = {
  networks: {
    hardhat: {
      accounts: {
        count: 20,
        accountsBalance: '10000000000000000000000000000000000000000000000'
      },
      allowUnlimitedContractSize: true
    },
    sepolia: {
      url: process.env.SEPOLIA_API_KEY_URL,
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
  },

  solidity: {
    compilers: [
      {
        version: '0.8.21',
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000000
          },
          metadata: {
            bytecodeHash: 'none'
          }
        }
      },
      {
        version: '0.8.19',
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000000
          },
          metadata: {
            bytecodeHash: 'none'
          }
        }
      }
    ]
  },

  dependencyCompiler: {
    paths: [
      '@ethereum-attestation-service/eas-contracts/contracts/EAS.sol',
      '@ethereum-attestation-service/eas-contracts/contracts/SchemaRegistry.sol'
    ]
  },

  typechain: {
    target: 'ethers-v6'
  },

  mocha: {
    color: true,
    bail: true
  }
};

export default config;
