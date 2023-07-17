import * as dotenv from "dotenv";

import "@nomicfoundation/hardhat-ethers";
import { HardhatUserConfig, task } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
//import "hardhat-preprocessor";
//import fs from "fs";

dotenv.config();

/* this is prescribed by foundry to make hardhat still work but, instead, it breaks hardhat :-/
 * this goes along with the commented out preporocess: block in HardhatUserConfig below
 * and the hardhat-preprocessor import above.
function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean) // remove empty lines
    .map((line) => line.trim().split("="));
}
*/
// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

task("wrappedtoprotocol", "Prints the list of wrappedtoprotocol, use with --network <network containing a forked, e.g. mainnet>", async (taskArgs, hre) => {
  const LendingRegistryAddress = '0x08a2b7D713e388123dc6678168656659d297d397';

  const logs = await hre.ethers.provider.getLogs({
    address: LendingRegistryAddress,
    topics: [
      hre.ethers.id('WrappedToProtocolSet(address,bytes32)'), //'0x8d6c4851f1ff74632094f71fe39e4b0603cfd53a02524b0f56e077ec1a624644'
    ],
    fromBlock: 0,
    toBlock: 'latest',
  });

  console.log("WrappedToProtocolSet events:");
  for (let log of logs) {
    console.log("Wrapped: %s, Protocol: %d", log.topics[1], log.topics[2]);
  }
});

// event WrappedToProtocolSet(address indexed wrapped, bytes32 indexed protocol);
task("wrappedtoprotocol", "Prints the list of wrappedtoprotocol, use with --network <network containing a forked, e.g. mainnet>", async (taskArgs, hre) => {
  const LendingRegistryAddress = '0x08a2b7D713e388123dc6678168656659d297d397';

  const logs = await hre.ethers.provider.getLogs({
    address: LendingRegistryAddress,
    topics: [
      hre.ethers.id('WrappedToProtocolSet(address,bytes32)'), //'0x8d6c4851f1ff74632094f71fe39e4b0603cfd53a02524b0f56e077ec1a624644'
    ],
    fromBlock: 0,
    toBlock: 'latest',
  });

  console.log("WrappedToProtocolSet events:");
  for (let log of logs) {
    console.log("Wrapped: %s, Protocol: %d", log.topics[1], log.topics[2]);
  }
});

// event WrappedToUnderlyingSet(address indexed wrapped, address indexed underlying);
task("wrappedtounderlying", "Prints the list of wrappedtounderlying, use with --network <network containing a forked, e.g. mainnet>", async (taskArgs, hre) => {
  const LendingRegistryAddress = '0x08a2b7D713e388123dc6678168656659d297d397';

  const logs = await hre.ethers.provider.getLogs({
    address: LendingRegistryAddress,
    topics: [
      hre.ethers.id('WrappedToUnderlyingSet(address,address)'), // '0xcff55967603e193c0ecb65c41c4fa6f4032a9053d0fad30061ec89105cc7b5c2',
    ],
    fromBlock: 0,
    toBlock: 'latest',
  });

  console.log("WrappedToUnderlyingSet events:");
  for (let log of logs) {
    console.log("Wrapped: %s, Protocol: %s", log.topics[1], log.topics[2]);
  }
});

//event ProtocolToLogicSet(bytes32 indexed protocol, address indexed logic);
task("protocoltologic", "Prints the list of protocoltologic, use with --network <network containing a forked, e.g. mainnet>", async (taskArgs, hre) => {
  const LendingRegistryAddress = '0x08a2b7D713e388123dc6678168656659d297d397';

  const logs = await hre.ethers.provider.getLogs({
    address: LendingRegistryAddress,
    topics: [
      hre.ethers.id('ProtocolToLogicSet(bytes32,address)'),  //'0x05b94fa6d67a57a259499d28d3f8fd0eb8131cda46ea8c527ce24199839cb664', 
    ],
    fromBlock: 0,
    toBlock: 'latest',
  });

  console.log("ProtocolToLogicSet events:");
  for (let log of logs) {
    console.log("Protocol: %d, Logic: %s", log.topics[1], log.topics[2]);
  }
});
//event UnderlyingToProtocolWrappedSet(address indexed underlying, bytes32 indexed protocol, address indexed wrapped);
task("underlyingtoprotocolwrapped", "Prints the list of protocoltologic, use with --network <network containing a forked, e.g. mainnet>", async (taskArgs, hre) => {
  const LendingRegistryAddress = '0x08a2b7D713e388123dc6678168656659d297d397';

  const logs = await hre.ethers.provider.getLogs({
    address: LendingRegistryAddress,
    topics: [
      hre.ethers.id('UnderlyingToProtocolWrappedSet(address,bytes32,address)'), //'0x00f16cac75566114cbfffaff7857b8fff8050ff0820a182eac3b236f0b62ac2b', //hre.ethers.id('UnderlyingToProtocolWrappedSet'),
    ],
    fromBlock: 0,
    toBlock: 'latest',
  });

  console.log("UnderlyingToProtocolWrappedSet events:");
  for (let log of logs) {
    console.log("Underlying: %s, Protocol: %d, Wrapped: %s", log.topics[1], log.topics[2], log.topics[3]);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  networks: {
    localhost: {
      //Requires start of local network at port:
      url: "http://127.0.0.1:8545"
    },
    hardhat: {},
    ropsten: {
      url: process.env.ROPSTEN_URL || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
  },
  /*
  preprocess: {
    eachLine: (hre) => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          for (const [from, to] of getRemappings()) {
            if (line.includes(from)) {
              line = line.replace(from, to);
              break;
            }
          }
        }
        return line;
      },
    }),
  },
  */
  paths: {
    sources: "./contracts",
    cache: "./cache_hardhat",
  },
  solidity: {
    compilers: [
      {
        version: "0.7.1",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        },
      },
      {
        version: "0.8.1",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
        },
      },
      {
        version: "0.8.7",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
        },
      },
      {
        version: "0.6.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
        },
      },
    ],
  },
  mocha: {
    timeout: 10000000
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
