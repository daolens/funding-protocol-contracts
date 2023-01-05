
/**
* @type import('hardhat/config').HardhatUserConfig
*/
require("@nomiclabs/hardhat-ethers");
require('dotenv').config();
const { PRIVATE_KEY,API_URL_POLYGON_MUMBAI,API_URL_GOERLI } = process.env;

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
    apiKey: "IAW3WXAPPPE6M1W8VHS1B33S1ZW748596K",
  },

}