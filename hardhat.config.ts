import "@nomiclabs/hardhat-ethers";
//import "@nomiclabs/hardhat-waffle";
import {HardhatUserConfig} from 'hardhat/types';
import "hardhat-deploy";
import "ethereum-waffle";

const config: HardhatUserConfig = {
  networks: {
    localhost: {
      url: "http://localhost:8545",
      accounts: []
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.10",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }
    ]
  },
  namedAccounts : {
    deployer: 0, 
  },
  paths: {
    deploy: "./deploy/canto",
    sources: "./contracts",
    tests: "./test/Treasury",
    cache:"./cache",
    artifacts: "./artifacts"
  }
};

export default config;