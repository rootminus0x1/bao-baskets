import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";

const zeroAddress = '0x0000000000000000000000000000000000000000';
const zeroBytes32 = '0x0000000000000000000000000000000000000000000000000000000000000000';
const zeroBigNumber = BigNumber.from(0);

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

      const ownerAddress = await lendingRegistry.owner();
      expect(ownerAddress).to.equal(owner.address);
      expect(ownerAddress).to.equal('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266');

      const bestApr = await lendingRegistry.getBestApr(zeroAddress, []);
      
      expect(bestApr[0]).to.eql(zeroBigNumber);
      expect(bestApr[1]).to.equal(zeroBytes32);
      // can access the result by array index or by field name
      expect(bestApr.apr).to.eql(zeroBigNumber);
      expect(bestApr.protocol).to.equal(zeroBytes32);
    });

  })
});
