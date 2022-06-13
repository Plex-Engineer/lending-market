import "@nomiclabs/hardhat-ethers";
//import "@nomiclabs/hardhat-waffle";
import {HardhatUserConfig} from 'hardhat/types';
import "hardhat-deploy";
import "ethereum-waffle";

const config: HardhatUserConfig = {
  networks: {
    localhost: {
      url: "http://localhost:8545",
      accounts: [
        "2cf9ac82be406c018b48192b01ae1cc59775f65a0c155a54f78d15b6191ef90f",
      ]
    },
    canto : {
      url: "http://143.198.3.19:8545/",
      accounts: [
        "a9543ab2356f3cff70de65239509831865c2c1e0f4c6b315ed51c2c93af453b7"
      ]
    }
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