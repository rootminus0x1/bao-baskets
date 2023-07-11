import { ethers } from "hardhat";

import { LendingRegistry } from "../typechain-types/LendingManager.sol";

export async function deployLendingRegistry() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const LendingRegistryFactory = await ethers.getContractFactory("contracts/LendingRegistry.sol:LendingRegistry");
    const lendingRegistry = <LendingRegistry> await LendingRegistryFactory.deploy();

    return { lendingRegistry, owner, otherAccount };
}
