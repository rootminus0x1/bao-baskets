import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("LendingRegistry", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const LendingRegistryFactory = await ethers.getContractFactory("contracts/LendingRegistry.sol:LendingRegistry");
    const lendingRegistry = await LendingRegistryFactory.deploy();

    return { lendingRegistry, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should not fail", async function () {
      const { lendingRegistry, owner, otherAccount } = await loadFixture(deployFixture);

      // expect no errors;
    });

    it("Should set the right owner", async function () {
      const { lendingRegistry, owner } = await loadFixture(deployFixture);

      expect(await lendingRegistry.owner()).to.equal(owner.address);
    });
  })
});
