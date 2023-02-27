require("dotenv").config();
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("@nomiclabs/hardhat-etherscan");

const TESTNET_PRIVATE_KEY = process.env.TESTNET_PRIVATE_KEY;
const BSC_RPC = process.env.BSC_RPC;
const BSCSCAN_API_KEY = process.env.BSCSCAN_API_KEY;

module.exports = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1,
      },
    },
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
    // BSCTestnet: {
    //   url: `${BSC_RPC}`,
    //   accounts: [`0x${BSCTESTNET_PRIVATE_KEY}`],
    //   allowUnlimitedContractSize: true,
    // },
  },
  // gasReporter: {
  //   currency: "USD",
  //   token: "BNB",
  //   gasPriceApi: "https://api.bscscan.com/api?module=proxy&action=eth_gasPrice",
  //   coinmarketcap: "0431b70e-ffff-4061-81b0-fa361384d36c",
  //   // enabled: (process.env.REPORT_GAS) ? true : false
  // },
  // etherscan: {
  //   apiKey: BSCSCAN_API_KEY,
  // },
};

// https://api.bscscan.com/api?module=proxy&action=eth_gasPrice
// https://api.polygonscan.com/api?module=proxy&action=eth_gasPrice
// https://api.etherscan.io/api?module=proxy&action=eth_gasPrice