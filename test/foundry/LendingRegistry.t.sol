// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.1;

// solhint-disable func-name-mixedcase
// solhint-disable no-console
import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";

import {LendingRegistry} from "contracts/LendingRegistry.sol";

import {TestData} from "./TestData.t.sol";

contract UnititialisedLendingRegistry is Test, TestData {
    LendingRegistry private lendingRegistry;

    event WrappedToProtocolSet(address indexed wrapped, bytes32 indexed protocol);

    function setUp() public virtual {
        lendingRegistry = new LendingRegistry();
    }

    function test_Initialises() public {
        assertEq(lendingRegistry.owner(), address(this));

        uint256 bestApr;
        bytes32 bestProtocol;
        bytes32[] memory selectedProtocols;
        (bestApr, bestProtocol) = lendingRegistry.getBestApr(zeroAddress, selectedProtocols);

        assertEq(bestApr, zeroBigNumber);
        assertEq(bestProtocol, zeroBytes32);
    }

    function test_Emits() public {
        vm.expectEmit(true, true, false, false);
        // expected event
        emit WrappedToProtocolSet(zeroAddress, zeroBytes32);
        // actual event
        lendingRegistry.setWrappedToProtocol(zeroAddress, zeroBytes32);

        // TODO:
        // event WrappedToUnderlyingSet(address indexed wrapped, address indexed underlying);
        // event ProtocolToLogicSet(bytes32 indexed protocol, address indexed logic);
        // event UnderlyingToProtocolWrappedSet(address indexed underlying, bytes32 indexed protocol, address indexed wrapped);
    }

    function testFail_CallerIsNotOwner() public {
        vm.prank(address(0));
        lendingRegistry.setWrappedToProtocol(zeroAddress, zeroBytes32);
    }

    function test_RevertWhen_CallerIsNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0));
        lendingRegistry.setWrappedToProtocol(zeroAddress, zeroBytes32);
    }
}
