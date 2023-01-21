
/**
* @type import('hardhat/config').HardhatUserConfig
*/
require("@nomiclabs/hardhat-ethers");
require('dotenv').config();
const { PRIVATE_KEY,API_URL_POLYGON_MUMBAI,API_URL_GOERLI,API_URL,API_URL_ETH,ETHERSCAN_API_KEY } = process.env;

module.exports = {
  defaultNetwork: "PolygonMumbai",
  networks: {
    hardhat: {
    },
    PolygonMumbai: {
      url: API_URL_POLYGON_MUMBAI,
      accounts: [PRIVATE_KEY]
    },
    goerli : {
      url: API_URL_GOERLI,
      accounts: [PRIVATE_KEY]
    },
    Polygon : {
      url : API_URL,
      accounts : [PRIVATE_KEY]
    },
    ETH : {
      url : API_URL_ETH,
      accounts : [PRIVATE_KEY]
    }
  },
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },

}