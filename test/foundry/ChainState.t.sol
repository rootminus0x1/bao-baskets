// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.1;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

import {DateUtils} from "./SkeletonCodeworks/DateUtils/DateUtils.sol";
import {LoggingTest} from "./LoggingTest.sol";
import {ChainState} from "./ChainState.sol";

contract TestChainState is Test {
    ChainState chainState = new ChainState();
    uint256 startBlock;
    uint256 startTimestamp;
    uint256 constant secsPerBlock = 12;

    function setUp() public {
        // go to a known point in time:
        // https://etherscan.io/block/17790000 has this at Jul-28-2023 07:15:35 AM +UTC
        chainState.rollForkTo(17790000);
        startBlock = block.number;
        startTimestamp = block.timestamp;
    }

    function test_dates() public {
        uint256 result = DateUtils.convertDateTimeStringToTimestamp("2023-07-28 07:15:35");
        assertEq(result, block.timestamp, "compare with etherscan");
    }

    function test_zero() public {
        chainState.rollForkBefore("2023-07-28 07:15:35");
        assertEq(block.number, startBlock, "same date should result in no blocks moved");
    }

    function test_blockboundary_back() public {
        // roll over at least one block boundary
        for (uint256 i = 1; i < 20; i++) {
            chainState.rollForkBefore(startTimestamp - 1);
        }
        assertEq(block.number, startBlock - 1, "back one second, should be the previous block");
    }

    function test_longer_back() public {
        chainState.rollForkBefore("2023-07-28 07:14:35");
        assertApproxEqAbs(block.timestamp, startTimestamp - 60, secsPerBlock, "back one min");
        chainState.rollForkBefore("2023-07-28 06:15:35");
        assertApproxEqAbs(block.timestamp, startTimestamp - 60 * 60, secsPerBlock, "back one hour");
        chainState.rollForkBefore("2023-07-27 07:15:35");
        assertApproxEqAbs(block.timestamp, startTimestamp - 60 * 60 * 24, secsPerBlock, "back one day");
        chainState.rollForkBefore("2023-06-28 07:15:35");
        assertApproxEqAbs(block.timestamp, startTimestamp - 60 * 60 * 24 * 30, secsPerBlock, "back one month");
    }

    function test_tooLong_back() public {
        // 50 years - too long for the block number, but OK for the timestamp whose epoch starts 1-Jan-1970
        vm.expectRevert("can't go back beyond the start of the blockchain");
        chainState.rollForkBefore("1973-07-28 07:15:35");
    }

    function test_wayTooLong_back() public {
        // 60 years - too long ago for the timestamp
        vm.expectRevert(); // this will catch the string conversion failure
        chainState.rollForkBefore("1963-07-28 07:15:35");
    }

    function test_wayTooLongTS_back() public {
        // too long ago for the timestamp
        vm.expectRevert("can't go back beyond 1-Jan-1970");
        chainState.rollForkBefore(type(uint256).max); // assume we've wrapped the uint256 calcs and got a negative
    }

    function test_1sec_forward() public {
        chainState.rollForkBefore("2023-07-28 07:15:36");
        assertEq(block.number, startBlock, "forward one second"); // one sec is within the same block
    }

    function test_1min_forward() public {
        chainState.rollForkBefore("2023-07-28 07:16:35");
        assertApproxEqAbs(block.timestamp, startTimestamp + 60, secsPerBlock, "forward one min");
    }

    function test_1hour_forward() public {
        chainState.rollForkBefore("2023-07-28 08:15:35");
        assertApproxEqAbs(block.timestamp, startTimestamp + 60 * 60, secsPerBlock, "forward one hour");
    }

    function test_1day_forward() public {
        chainState.rollForkBefore("2023-07-29 07:15:35");
        assertApproxEqAbs(block.timestamp, startTimestamp + 60 * 60 * 24, secsPerBlock, "forward one day");
    }

    function testFail_tooLong_forward() public {
        chainState.rollForkBefore("2123-07-28 07:15:35"); // 100 years should go beyoond the last block
        assertApproxEqAbs(block.timestamp, startTimestamp + 60 * 60 * 24, secsPerBlock, "100 years forward fails");
    }

    function test_6sec_forward() public {
        // go to the next block
        vm.rollFork(chainState.fork(), startBlock + 1);
        uint256 targetTimestamp = block.timestamp;
        vm.rollFork(chainState.fork(), startBlock);
        chainState.rollForkBefore(targetTimestamp - 1);
        assertEq(block.number, startBlock, "forward next block -1 sec ");
    }
}
