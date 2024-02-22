require("@nomicfoundation/hardhat-toolbox");
require('hardhat-abi-exporter');
require('dotenv').config();

let dotenv = require('dotenv')
dotenv.config({ path: "./.env" })

const { ProxyAgent, setGlobalDispatcher } = require("undici")

const proxyAgent = new ProxyAgent("http://127.0.0.1:7890")
setGlobalDispatcher(proxyAgent)

/** @type import('hardhat/config').HardhatUserConfig */
const EtherscanAPIKey = process.env.ETHERSCAN_API_KEY
const SnowtraceAPIKey = process.env.SNOWTRACE_API_KEY
const OptimismscanAPIKey = process.env.OPTIMISMSCAN_API_KEY
const ArbiscanAPIKey = process.env.ARBISCAN_API_KEY
const BasescanAPIKey = process.env.BASESCAN_API_KEY
const PolygonAPIKey = process.env.POLYGON_API_KEY

const privateKey = process.env.PRIVATEKEY

module.exports = {
  solidity: "0.8.21",

  networks: {

    mainnet: {
      url: process.env.ETHEREUM_RPC_URL,
      accounts: [privateKey],
      chainId: 1,
    },

    avalanche: {
      url: process.env.AVALANCHE_RPC_URL,
      accounts: [privateKey],
      chainId: 43114,
    },

    optimisticEthereum: {
      url: process.env.OPTIMISM_RPC_URL,
      accounts: [privateKey],
      chainId: 10,
    },

    arbitrumOne: {
      url: process.env.ARBITRUM_RPC_URL,
      accounts: [privateKey],
      chainId: 42161,
    },

    base: {
      url: process.env.BASE_RPC_URL,
      accounts: [privateKey],
      chainId: 8453,
    },

    polygon: {
      url: process.env.POLYGON_RPC_URL,
      accounts: [privateKey],
      chainId: 137,
    },

    goerli: {
      url: process.env.ETHEREUM_GOERLI_RPC_URL,
      accounts: [privateKey],
      chainId: 5,
    },

    sepolia: {
      url: process.env.ETHEREUM_SEPOLIA_RPC_URL,
      accounts: [privateKey],
      chainId: 11155111,
    },

    avalancheFujiTestnet: {
      url: process.env.AVALANCHE_FUJI_RPC_URL,
      accounts: [privateKey],
      chainId: 43113,
    },

    optimisticGoerli: {
      url: process.env.OPTIMISM_GOERLI_RPC_URL,
      accounts: [privateKey],
      chainId: 420,
    },

    baseGoerli: {
      url: process.env.BASE_GOERLI_RPC_URL,
      accounts: [privateKey],
      chainId: 84531,
    },

    polygonMumbai: {
      url: process.env.POLYGON_MUMBAI_RPC_URL,
      accounts: [privateKey],
      chainId: 80001,
    },
  },


  localhost: {
    url: "http://127.0.0.1:8545"
  },
  hardhat: {
    // See its defaults
  },

  abiExporter: {
    path: './deployments/abi',
    clear: true,
    flat: true,
    only: [],
    spacing: 2,
    pretty: true,
  },


  etherscan: {
    apiKey: {
      mainnet: EtherscanAPIKey,
      avalanche: SnowtraceAPIKey,
      optimisticEthereum: OptimismscanAPIKey,
      arbitrumOne: ArbiscanAPIKey,
      base: BasescanAPIKey,
      polygon: PolygonAPIKey,
      goerli: EtherscanAPIKey,
      sepolia: EtherscanAPIKey,
      avalancheFujiTestnet: SnowtraceAPIKey,
      optimisticGoerli: OptimismscanAPIKey,
      baseGoerli: BasescanAPIKey,
      polygonMumbai: PolygonAPIKey,
    },

    customChains: [
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org/"
        }
      },

      {
        network: "baseGoerli",
        chainId: 84531,
        urls: {
          apiURL: "https://api-goerli.basescan.org/api",
          browserURL: "https://goerli.basescan.org/"
        }
      },
    ]

  },

  sourcify: {
    enabled: false,
  },

};
