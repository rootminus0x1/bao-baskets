import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
// import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";

import { BigNumber } from "@ethersproject/bignumber";

import { deployLendingRegistry } from "./Fixtures"
import { LendingRegistry } from "../typechain-types/LendingManager.sol";
import { LendingManager__factory } from "../typechain-types";

describe("LendingRegistry", function () {

  describe("Deployment", function () {
    const zeroAddress = '0x0000000000000000000000000000000000000000';
    const zeroBytes32 = '0x0000000000000000000000000000000000000000000000000000000000000000';
    const zeroBigNumber = BigNumber.from(0);

    it("should return safe values or errors to queries after deployment", async function () {
      const { lendingRegistry, owner, otherAccount } = await loadFixture(deployLendingRegistry);

      const ownerAddress = await lendingRegistry.owner();
      expect(ownerAddress).to.equal(owner.address);
      expect(ownerAddress).to.equal('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266');

      const bestApr = await lendingRegistry.getBestApr(zeroAddress, []);
      
      expect(bestApr[0].toString()).to.equal(zeroBigNumber.toString());
      expect(bestApr[1]).to.equal(zeroBytes32);
      // can access the result by array index or by field name
      expect(bestApr.apr.toString()).to.equal(zeroBigNumber.toString());
      expect(bestApr.protocol).to.equal(zeroBytes32);
    });

    it("should emit events", async function () {
      const { lendingRegistry, owner, otherAccount } = await loadFixture(deployLendingRegistry);
      await expect(lendingRegistry.setWrappedToProtocol(zeroAddress, zeroBytes32))
      .to.emit(lendingRegistry, "WrappedToProtocolSet")
      .withArgs(zeroAddress, zeroBytes32);

    });

  })

  describe("simulate compound", function () {
    const myWrapped = '0x0000000000000000000000000000000000000000';
    const myUnderlying = '0x0000000000000000000000000000000000000000';
    const myProtocol = '0x0000000000000000000000000000000000000000000000000000000000000000';
    const myLogic = '0x0000000000000000000000000000000000000000000000000000000000000000';
    const zeroBigNumber = BigNumber.from(0);

    async function setupLendingRegistry(lendingRegistry: LendingRegistry)
    {
      await expect(lendingRegistry.setWrappedToProtocol(myWrapped, myProtocol))
      .to.emit(lendingRegistry, "WrappedToProtocolSet")
      .withArgs(myWrapped, myProtocol);

      await expect(lendingRegistry.setWrappedToUnderlying(myWrapped, myUnderlying))
      .to.emit(lendingRegistry, "WrappedToUnderlyingSet")
      .withArgs(myWrapped, myUnderlying);

      await expect(lendingRegistry.setProtocolToLogic(myProtocol, myLogic))
      .to.emit(lendingRegistry, "ProtocolToLogicSet")
      .withArgs(myProtocol, myLogic);

      await expect(lendingRegistry.setUnderlyingToProtocolWrapped(myUnderlying, myProtocol, myWrapped))
      .to.emit(lendingRegistry, "UnderlyingToProtocolWrappedSet")
      .withArgs(myUnderlying, myProtocol, myWrapped);
    }

    it("should allow adding a protocol, strategy, underlying, and wrapped", async function () {
      const { lendingRegistry, owner, otherAccount } = await loadFixture(deployLendingRegistry);

      setupLendingRegistry(lendingRegistry);
    })

    it("should allow getting best Apr", async function () {
      const { lendingRegistry, owner, otherAccount } = await loadFixture(deployLendingRegistry);

      setupLendingRegistry(lendingRegistry);

      const bestApr = await lendingRegistry.getBestApr(myUnderlying, [myProtocol]);
      expect(bestApr[0].toString()).to.equal(zeroBigNumber.toString());
      expect(bestApr[1]).to.equal(myUnderlying);
    })
  })

});
