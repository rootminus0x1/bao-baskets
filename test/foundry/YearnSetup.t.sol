// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.5.1;

// solhint-disable func-name-mixedcase
// solhint-disable no-console
import {console2 as console} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

import {LendingRegistry} from "contracts/LendingRegistry.sol";
import {LendingLogicYearn} from "contracts/Strategies/LendingLogicYearn.sol";

import {Deployed} from "./Deployed.sol";
import {TestLendingLogic} from "./TestLendingLogic.sol";
import {TestData} from "./TestData.t.sol";
import {Dai} from "./Dai.t.sol";

contract TestYearnLusd is TestLendingLogic {
    bytes32 public constant PROTOCOLYEARN = 0x0000000000000000000000000000000000000000000000000000000000000004;
    LendingLogicYearn public lendingLogicYearn;
    address public LENDINGLOGICYEARN;

    constructor() {
        startLogging("TestYearnLusd");
    }

    function setUp() public {
        lendingLogicYearn = new LendingLogicYearn(address(lendingRegistry), PROTOCOLYEARN);
        LENDINGLOGICYEARN = address(lendingLogicYearn);

        // console.log("transferring ownership to %s", Deployed.OWNER);
        lendingLogicYearn.transferOwnership(Deployed.OWNER);
        vm.startPrank(Deployed.OWNER);
        // set up the lending logic
        // console.log("adding strategy %s for wrapped %s", YVLUSDSTRATEGY1, YVLUSD.addr);
        // TODO: uncomment this if we can't get the strategies from withdrawal queue
        // lendingLogicYearn.addStrategyFor(YVLUSD.addr, YVLUSDSTRATEGY1); // we get the returns from this

        // set up the lending registry
        // console.log("setting up lendingRegistry for yearn");
        lendingRegistry.setWrappedToProtocol(YVLUSD.addr, PROTOCOLYEARN);
        lendingRegistry.setWrappedToUnderlying(YVLUSD.addr, LUSD.addr);
        lendingRegistry.setProtocolToLogic(PROTOCOLYEARN, LENDINGLOGICYEARN);
        lendingRegistry.setUnderlyingToProtocolWrapped(LUSD.addr, PROTOCOLYEARN, YVLUSD.addr);
        vm.stopPrank();

        TestLendingLogic.create(LENDINGLOGICYEARN, PROTOCOLYEARN, Deployed.YVLUSD.addr, Deployed.LUSD.addr);
        // console.log("setUp done.");
    }
}

contract TestYearnLogicBasics is Test, TestData {
    bytes32 public constant PROTOCOLYEARN = 0x0000000000000000000000000000000000000000000000000000000000000004;
    LendingLogicYearn public lendingLogicYearn;

    function setUp() public {
        lendingLogicYearn = new LendingLogicYearn(address(new LendingRegistry()), PROTOCOLYEARN);
    }

    function contains(address[] memory _list, address _element) private pure returns (bool found) {
        found = false;
        for (uint256 index = 0; index < _list.length; index++) {
            if (_list[index] == _element) {
                found = true;
                break;
            }
        }
    }

    /*
    // this is for the implementation without List.sol
    function getElements(address wrapped) private view returns (address[] memory result) {
        clog("getting elements");
        uint256 index = 0;
        while (lendingLogicYearn.wrappedToStrategies(wrapped, index) != address(0)) {
            index++;
        }
        result = new address[](index);
        index = 0;
        while (lendingLogicYearn.wrappedToStrategies(wrapped, index) != address(0)) {
            result[index] = lendingLogicYearn.wrappedToStrategies(wrapped, index);
            index++;
        }
    }

    // this is for with List.sol 
    function getElements(address wrapped) private view returns (address[] memory result) {
        result = lendingLogicYearn.wrappedToStrategies(testWrapped1).getElements();
    }

    function testStrategiesList() public {
        address testWrapped1 = address(0xA);
        address testWrapped2 = address(0xB);
        address testStrategy1 = address(0x100);
        address testStrategy2 = address(0x200);
        address testStrategy3 = address(0x300);

        //
        // single adds and removes
        //
        // check empty handling
        assertEq(getElements(testWrapped1).length, 0, "expected empty array");
        assertEq(getElements(testWrapped1).length, 0, "expected empty array"); // call twice
        assertEq(getElements(testWrapped2).length, 0, "expected empty array");

        // remove from ampty lendingLogicYearn
        lendingLogicYearn.revokeStrategyFor(testWrapped1, testStrategy1);
        assertEq(getElements(testWrapped1).length, 0, "expected empty array");
        assertEq(getElements(testWrapped2).length, 0, "expected empty array");

        // add one and check its there
        lendingLogicYearn.addStrategyFor(testWrapped1, testStrategy1);
        address[] memory strategies = getElements(testWrapped1);
        assertEq(strategies.length, 1, "expected length=1");
        assertTrue(contains(strategies, testStrategy1), "should contain testStrategy1");
        assertEq(getElements(testWrapped2).length, 0, "expected empty array");

        // remove one that's there
        lendingLogicYearn.revokeStrategyFor(testWrapped1, testStrategy1);
        strategies = getElements(testWrapped1);
        assertEq(getElements(testWrapped1).length, 0, "expected empty array");
        assertEq(getElements(testWrapped2).length, 0, "expected empty array");

        // remove one that's there again
        lendingLogicYearn.revokeStrategyFor(testWrapped1, testStrategy1);
        strategies = getElements(testWrapped1);
        assertEq(getElements(testWrapped1).length, 0, "expected empty array");
        assertEq(getElements(testWrapped2).length, 0, "expected empty array");

        // add one again and check its there
        lendingLogicYearn.addStrategyFor(testWrapped1, testStrategy1);
        strategies = getElements(testWrapped1);
        assertEq(strategies.length, 1, "expected length=1");
        assertTrue(contains(strategies, testStrategy1));
        assertEq(getElements(testWrapped2).length, 0, "expected empty array");

        // add the same one again and check its only there once
        lendingLogicYearn.addStrategyFor(testWrapped1, testStrategy1);
        strategies = getElements(testWrapped1);
        assertEq(strategies.length, 1, "expected length=1");
        assertTrue(contains(strategies, testStrategy1), "should contain testStrategy1");
        assertEq(getElements(testWrapped2).length, 0, "expected empty array");

        //
        // multiple adds and removes
        //
        lendingLogicYearn.addStrategyFor(testWrapped1, testStrategy1);
        lendingLogicYearn.addStrategyFor(testWrapped1, testStrategy2);
        lendingLogicYearn.addStrategyFor(testWrapped1, testStrategy3);
        strategies = getElements(testWrapped1);
        assertEq(strategies.length, 3, "expected length=3");
        // returns them in reverse insertion order
        // (implementation detail but relying on this on a test makes the test easier)
        assertTrue(contains(strategies, testStrategy1), "should contain testStrategy1");
        assertTrue(contains(strategies, testStrategy2), "should contain testStrategy2");
        assertTrue(contains(strategies, testStrategy3), "should contain testStrategy3");

        // revoke head
        lendingLogicYearn.revokeStrategyFor(testWrapped1, testStrategy3);
        strategies = getElements(testWrapped1);
        assertEq(strategies.length, 2, "expected length=2 after head revoke");
        assertTrue(contains(strategies, testStrategy1), "should contain testStrategy1");
        assertTrue(contains(strategies, testStrategy2), "should contain testStrategy2");

        // add it back and revoke tail
        lendingLogicYearn.addStrategyFor(testWrapped1, testStrategy3);
        strategies = getElements(testWrapped1);
        assertEq(strategies.length, 3, "expected length=3");
        assertTrue(contains(strategies, testStrategy1), "should contain testStrategy1");
        assertTrue(contains(strategies, testStrategy2), "should contain testStrategy2");
        assertTrue(contains(strategies, testStrategy3), "should contain testStrategy3");
        lendingLogicYearn.revokeStrategyFor(testWrapped1, testStrategy1);
        strategies = getElements(testWrapped1);
        assertEq(strategies.length, 2, "expected length=2 after tail revoke");
        assertTrue(contains(strategies, testStrategy2), "should contain testStrategy2");
        assertTrue(contains(strategies, testStrategy3), "should contain testStrategy3");
    }

    */
}
