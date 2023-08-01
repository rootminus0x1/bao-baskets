// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.5.1;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

interface IList {
    function isStrategyFor(address wrapped, address strategy) external view returns (bool);
    function revokeStrategyFor(address wrapped, address strategy) external;
    function addStrategyFor(address wrapped, address strategy) external;
    function getStrategiesFor(address wrapped) external view returns (address[] memory result);
}

contract MapList is IList {
    // this is a mapping of wrapped to a circular linked list of strategies
    //   thanks to https://medium.com/bandprotocol/solidity-102-2-o-1-iterable-map-8d905298c1bc
    mapping(address => mapping(address => address)) public wrappedToStrategies;
    address internal constant GUARD = address(1);

    function isStrategyFor(address wrapped, address strategy) public view override returns (bool) {
        // assumes the list is initialised
        return wrappedToStrategies[wrapped][strategy] != address(0);
    }

    function revokeStrategyFor(address wrapped, address strategy) public override {
        // when strategies are revoked in Yearn, this event is generated:
        //   StrategyRevoked(strategy (indexed))

        // if not an empty list and the list contains 'strategy'
        if (wrappedToStrategies[wrapped][GUARD] != address(0) && wrappedToStrategies[wrapped][strategy] != address(0)) {
            address prev = GUARD; // start at the head
            while (wrappedToStrategies[wrapped][prev] != GUARD) {
                // not at the tail
                if (wrappedToStrategies[wrapped][prev] == strategy) {
                    // found the prev strategy to unlink
                    wrappedToStrategies[wrapped][prev] = wrappedToStrategies[wrapped][strategy];
                    wrappedToStrategies[wrapped][strategy] = address(0);
                    break;
                }
                prev = wrappedToStrategies[wrapped][prev];
            }
        }
    }

    function addStrategyFor(address wrapped, address strategy) public override {
        // when new strategies are added, you can see them via
        //       log StrategyAdded(strategy (indexed), debtRatio, minDebtPerHarvest, maxDebtPerHarvest, performanceFee)
        if (wrappedToStrategies[wrapped][GUARD] == address(0)) {
            // empty list, initialise with one entry
            wrappedToStrategies[wrapped][strategy] = GUARD;
            wrappedToStrategies[wrapped][GUARD] = strategy;
        } else if (wrappedToStrategies[wrapped][strategy] == address(0)) {
            // it's not in the list, so add it at the head
            wrappedToStrategies[wrapped][strategy] = wrappedToStrategies[wrapped][GUARD];
            wrappedToStrategies[wrapped][GUARD] = strategy;
        }
    }

    function getStrategiesFor(address wrapped) public view override returns (address[] memory result) {
        address currentStrategy = wrappedToStrategies[wrapped][GUARD];
        if (currentStrategy == address(0)) {
            // uninitialised list, so no entries
            return new address[](0);
        }
        // get length, could be 0 is current strategy is GUARD
        uint256 length = 0;
        while (currentStrategy != GUARD) {
            length++;
            currentStrategy = wrappedToStrategies[wrapped][currentStrategy];
        }

        result = new address[](length);
        currentStrategy = wrappedToStrategies[wrapped][GUARD];
        length = 0;
        while (currentStrategy != GUARD) {
            result[length] = currentStrategy;
            currentStrategy = wrappedToStrategies[wrapped][currentStrategy];
            length++;
        }

        return result;
    }
}

contract ArrayList is IList {
    mapping(address => address[]) public wrappedToStrategies;

    function _indexOf(address wrapped, address strategy) internal view returns (bool found, uint256 index) {
        found = false;
        for (index = 0; index < wrappedToStrategies[wrapped].length; index++) {
            if (wrappedToStrategies[wrapped][index] == strategy) {
                found = true;
                break;
            }
        }
    }

    function isStrategyFor(address wrapped, address strategy) public view override returns (bool found) {
        (found,) = _indexOf(wrapped, strategy);
    }

    function revokeStrategyFor(address wrapped, address strategy) public override {
        // when strategies are revoked in Yearn, this event is generated:
        //   StrategyRevoked(strategy (indexed))
        (bool found, uint256 index) = _indexOf(wrapped, strategy);
        if (found) {
            if (index < wrappedToStrategies[wrapped].length - 1) {
                // copy the last one over it
                wrappedToStrategies[wrapped][index] =
                    wrappedToStrategies[wrapped][wrappedToStrategies[wrapped].length - 1];
            }
            // shorten the array
            wrappedToStrategies[wrapped].pop();
        }
    }

    function addStrategyFor(address wrapped, address strategy) public override {
        (bool found,) = _indexOf(wrapped, strategy);
        if (!found) {
            wrappedToStrategies[wrapped].push(strategy);
        }
    }

    function getStrategiesFor(address wrapped) public view override returns (address[] memory result) {
        result = new address[](wrappedToStrategies[wrapped].length);
        for (uint256 index = 0; index < wrappedToStrategies[wrapped].length; index++) {
            result[index] = wrappedToStrategies[wrapped][index];
        }
    }
}

abstract contract TestList is Test {
    address testWrapped1 = address(0xA);
    address testWrapped2 = address(0xB);
    address testWrapped3 = address(0xC);
    address testStrategy1 = address(0x100);
    address testStrategy2 = address(0x200);
    address testStrategy3 = address(0x300);

    IList list;

    constructor(IList _list) {
        list = _list;
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

    function test_addAndRemove1() public {
        //
        // single adds and removes
        //
        // check empty handling
        assertTrue(!list.isStrategyFor(testWrapped1, testStrategy1), "no strategies");
        assertEq(list.getStrategiesFor(testWrapped1).length, 0, "expected empty array");
        assertEq(list.getStrategiesFor(testWrapped1).length, 0, "expected empty array"); // call twice
        assertEq(list.getStrategiesFor(testWrapped2).length, 0, "expected empty array");

        // remove from ampty list
        list.revokeStrategyFor(testWrapped1, testStrategy1);
        assertEq(list.getStrategiesFor(testWrapped1).length, 0, "expected empty array");
        assertEq(list.getStrategiesFor(testWrapped2).length, 0, "expected empty array");

        // add one and check its there
        list.addStrategyFor(testWrapped1, testStrategy1);
        address[] memory strategies = list.getStrategiesFor(testWrapped1);
        assertEq(strategies.length, 1, "expected length=1");
        assertTrue(contains(strategies, testStrategy1), "should contain testStrategy1");
        assertEq(list.getStrategiesFor(testWrapped2).length, 0, "expected empty array");

        // remove one that's there
        list.revokeStrategyFor(testWrapped1, testStrategy1);
        strategies = list.getStrategiesFor(testWrapped1);
        assertEq(list.getStrategiesFor(testWrapped1).length, 0, "expected empty array");
        assertEq(list.getStrategiesFor(testWrapped2).length, 0, "expected empty array");

        // remove one that's there again
        list.revokeStrategyFor(testWrapped1, testStrategy1);
        strategies = list.getStrategiesFor(testWrapped1);
        assertEq(list.getStrategiesFor(testWrapped1).length, 0, "expected empty array");
        assertEq(list.getStrategiesFor(testWrapped2).length, 0, "expected empty array");

        // add one again and check its there
        list.addStrategyFor(testWrapped1, testStrategy1);
        strategies = list.getStrategiesFor(testWrapped1);
        assertEq(strategies.length, 1, "expected length=1");
        assertTrue(contains(strategies, testStrategy1));
        assertEq(list.getStrategiesFor(testWrapped2).length, 0, "expected empty array");

        // add the same one again and check its only there once
        list.addStrategyFor(testWrapped1, testStrategy1);
        strategies = list.getStrategiesFor(testWrapped1);
        assertEq(strategies.length, 1, "expected length=1");
        assertTrue(contains(strategies, testStrategy1), "should contain testStrategy1");
        assertEq(list.getStrategiesFor(testWrapped2).length, 0, "expected empty array");

        //
        // multiple adds and removes
        //
        list.addStrategyFor(testWrapped1, testStrategy1);
        list.addStrategyFor(testWrapped1, testStrategy2);
        list.addStrategyFor(testWrapped1, testStrategy3);
        strategies = list.getStrategiesFor(testWrapped1);
        assertEq(strategies.length, 3, "expected length=3");
        // returns them in reverse insertion order
        // (implementation detail but relying on this on a test makes the test easier)
        assertTrue(contains(strategies, testStrategy1), "should contain testStrategy1");
        assertTrue(contains(strategies, testStrategy2), "should contain testStrategy2");
        assertTrue(contains(strategies, testStrategy3), "should contain testStrategy3");

        // revoke head
        list.revokeStrategyFor(testWrapped1, testStrategy3);
        strategies = list.getStrategiesFor(testWrapped1);
        assertEq(strategies.length, 2, "expected length=2 after head revoke");
        assertTrue(contains(strategies, testStrategy1), "should contain testStrategy1");
        assertTrue(contains(strategies, testStrategy2), "should contain testStrategy2");

        // add it back and revoke tail
        list.addStrategyFor(testWrapped1, testStrategy3);
        strategies = list.getStrategiesFor(testWrapped1);
        assertEq(strategies.length, 3, "expected length=3");
        assertTrue(contains(strategies, testStrategy1), "should contain testStrategy1");
        assertTrue(contains(strategies, testStrategy2), "should contain testStrategy2");
        assertTrue(contains(strategies, testStrategy3), "should contain testStrategy3");
        list.revokeStrategyFor(testWrapped1, testStrategy1);
        strategies = list.getStrategiesFor(testWrapped1);
        assertEq(strategies.length, 2, "expected length=2 after tail revoke");
        assertTrue(contains(strategies, testStrategy2), "should contain testStrategy2");
        assertTrue(contains(strategies, testStrategy3), "should contain testStrategy3");
    }
}

contract TestMapList is TestList(new MapList()) {}

contract TestArrayList is TestList(new ArrayList()) {}
