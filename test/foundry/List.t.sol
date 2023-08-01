// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.5.1;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

import {MapList, ArrayList, IList} from "contracts/Utility/List.sol";

abstract contract TestList is Test {
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

    function test_addAndRemove() public {
        //
        // single adds and removes
        //
        // check empty handling
        assertTrue(!list.contains(testStrategy1), "no strategies");
        assertEq(list.getElements().length, 0, "expected empty array");
        assertEq(list.getElements().length, 0, "expected empty array"); // call twice

        // remove from ampty list
        list.remove(testStrategy1);
        assertEq(list.getElements().length, 0, "expected empty array");

        // add one and check its there
        list.insert(testStrategy1);
        address[] memory strategies = list.getElements();
        assertEq(strategies.length, 1, "expected length=1");
        assertTrue(contains(strategies, testStrategy1), "should contain testStrategy1");

        // remove one that's there
        list.remove(testStrategy1);
        strategies = list.getElements();
        assertEq(list.getElements().length, 0, "expected empty array");

        // remove one that's there again
        list.remove(testStrategy1);
        strategies = list.getElements();
        assertEq(list.getElements().length, 0, "expected empty array");

        // add one again and check its there
        list.insert(testStrategy1);
        strategies = list.getElements();
        assertEq(strategies.length, 1, "expected length=1");
        assertTrue(contains(strategies, testStrategy1));

        // add the same one again and check its only there once
        list.insert(testStrategy1);
        strategies = list.getElements();
        assertEq(strategies.length, 1, "expected length=1");
        assertTrue(contains(strategies, testStrategy1), "should contain testStrategy1");

        //
        // multiple adds and removes
        //
        list.insert(testStrategy1);
        list.insert(testStrategy2);
        list.insert(testStrategy3);
        strategies = list.getElements();
        assertEq(strategies.length, 3, "expected length=3");
        // returns them in reverse insertion order
        // (implementation detail but relying on this on a test makes the test easier)
        assertTrue(contains(strategies, testStrategy1), "should contain testStrategy1");
        assertTrue(contains(strategies, testStrategy2), "should contain testStrategy2");
        assertTrue(contains(strategies, testStrategy3), "should contain testStrategy3");

        // revoke head
        list.remove(testStrategy3);
        strategies = list.getElements();
        assertEq(strategies.length, 2, "expected length=2 after head revoke");
        assertTrue(contains(strategies, testStrategy1), "should contain testStrategy1");
        assertTrue(contains(strategies, testStrategy2), "should contain testStrategy2");

        // add it back and revoke tail
        list.insert(testStrategy3);
        strategies = list.getElements();
        assertEq(strategies.length, 3, "expected length=3");
        assertTrue(contains(strategies, testStrategy1), "should contain testStrategy1");
        assertTrue(contains(strategies, testStrategy2), "should contain testStrategy2");
        assertTrue(contains(strategies, testStrategy3), "should contain testStrategy3");
        list.remove(testStrategy1);
        strategies = list.getElements();
        assertEq(strategies.length, 2, "expected length=2 after tail revoke");
        assertTrue(contains(strategies, testStrategy2), "should contain testStrategy2");
        assertTrue(contains(strategies, testStrategy3), "should contain testStrategy3");
    }
}

contract TestMapList is TestList(new MapList()) {}

contract TestArrayList is TestList(new ArrayList()) {}
