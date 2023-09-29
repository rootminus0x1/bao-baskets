// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.1;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

import {DateUtils} from "DateUtils/DateUtils.sol";
import {LoggingTest} from "./LoggingTest.sol";
import {ChainState, ChainFork, Roller} from "./ChainState.sol";
import {Useful} from "./Useful.sol";

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
        chainState.rollForkTo(startBlock + 1);
        uint256 targetTimestamp = block.timestamp;
        chainState.rollForkTo(startBlock);
        chainState.rollForkBefore(targetTimestamp - 1);
        assertEq(block.number, startBlock, "forward next block -1 sec ");
    }
}

contract TestRoller is ChainFork {
    uint256 constant startBlock = 17790000; // = 2023-07-28 07:15:35 according to https://etherscan.io/block/17790000
    uint256 immutable startTimestamp;
    uint256 constant secsPerBlock = 12;
    Roller.Bounds bounds;

    constructor() {
        // do last block first
        bounds.rightBlock = startBlock + 2 * 24 * 60 * 60 / secsPerBlock; // 2 days earlier @ 12 secs per block
        vm.rollFork(bounds.rightBlock);
        bounds.rightTimestamp = block.timestamp;

        vm.rollFork(startBlock);
        startTimestamp = block.timestamp;
    }

    function setUp() public {
        if (block.number != startBlock) vm.rollFork(startBlock);
    }

    function rollForkBeforeWithError(uint256 targetTimestamp, bytes memory expectedError) public {
        vm.expectRevert(expectedError);
        Roller.rollForkToBlockContaining(vm, targetTimestamp, bounds);
    }

    function rollForkBeforeWithError(string memory datetime, bytes memory expectedError) public {
        uint256 targetTimestamp = DateUtils.convertDateTimeStringToTimestamp(datetime);
        vm.expectRevert(expectedError);
        Roller.rollForkToBlockContaining(vm, targetTimestamp, bounds);
    }

    function rollForkBefore(string memory datetime) public returns (uint256) {
        uint256 targetTimestamp = DateUtils.convertDateTimeStringToTimestamp(datetime);
        return Roller.rollForkToBlockContaining(vm, targetTimestamp, bounds);
    }

    function rollForkBefore(uint256 targetTimestamp) public returns (uint256) {
        return Roller.rollForkToBlockContaining(vm, targetTimestamp, bounds);
    }

    function test_zero() public {
        rollForkBefore("2023-07-28 07:15:35");
        assertEq(block.number, startBlock, "same date should result in no blocks moved");
    }

    function test_some_back() public {
        rollForkBefore("2023-07-28 07:14:35");
        assertApproxEqAbs(block.timestamp, startTimestamp - 60, secsPerBlock, "back one min");

        rollForkBefore("2023-07-28 06:15:34");
        assertApproxEqAbs(block.timestamp, startTimestamp - 60 * 60, secsPerBlock, "back one hour");
        rollForkBefore("2023-07-28 06:15:35");
        assertApproxEqAbs(block.timestamp, startTimestamp - 60 * 60, secsPerBlock, "back one hour");
        rollForkBefore("2023-07-27 07:15:35");
        assertApproxEqAbs(block.timestamp, startTimestamp - 60 * 60 * 24, secsPerBlock, "back one day");
        rollForkBefore("2023-06-28 07:15:35");
        assertApproxEqAbs(block.timestamp, startTimestamp - 60 * 60 * 24 * 30, secsPerBlock, "back one month");
    }

    function test_tooLong_back() public {
        // 50 years - too long for the block number, but OK for the timestamp whose epoch starts 1-Jan-1970
        // console.log("block 0 timestamp = %d", DateUtils.convertDateTimeStringToTimestamp("2015-07-30 15:26:13"));
        rollForkBeforeWithError("2015-07-28 07:15:35", bytes("can't go back beyond the start of the blockchain"));
    }

    function testFail_wayTooLong_back() public {
        // 60 years - too long ago for the timestamp
        // vm.expectRevert(); // this will catch the string conversion failure
        rollForkBefore("1963-07-28 07:15:35");
    }

    function test_wayTooLongTS_back() public {
        // too long ago for the timestamp
        // vm.expectRevert();
        rollForkBeforeWithError(type(uint256).max, bytes("can't go back beyond 1-Jan-1970")); // assume we've wrapped the uint256 calcs and got a negative
    }

    function test_1sec_forward() public {
        rollForkBefore("2023-07-28 07:15:36");
        assertEq(block.number, startBlock, "forward one second"); // one sec is within the same block
    }

    function test_1min_forward() public {
        rollForkBefore("2023-07-28 07:16:35");
        assertApproxEqAbs(block.timestamp, startTimestamp + 60, secsPerBlock, "forward one min");
    }

    function test_1hour_forward() public {
        rollForkBefore("2023-07-28 08:15:35");
        assertApproxEqAbs(block.timestamp, startTimestamp + 60 * 60, secsPerBlock, "forward one hour");
    }

    function test_1day_forward() public {
        rollForkBefore("2023-07-29 07:15:35");
        assertApproxEqAbs(block.timestamp, startTimestamp + 60 * 60 * 24, secsPerBlock, "forward one day");
    }

    function testFail_tooLong_forward() public {
        rollForkBefore("2123-07-28 07:15:35"); // 100 years should go beyoond the last block
        assertApproxEqAbs(block.timestamp, startTimestamp + 60 * 60 * 24, secsPerBlock, "100 years forward fails");
    }

    function test_6sec_forward() public {
        // go to the next block
        vm.rollFork(startBlock + 1);
        uint256 targetTimestamp = block.timestamp;
        vm.rollFork(startBlock);
        rollForkBefore(targetTimestamp - 1);
        assertEq(block.number, startBlock, "forward next block -1 sec ");
    }

    function _wholeBlock(uint256 expectedBlock, uint256 expectedBlockTimestamp, bool forward) private {
        for (uint256 i = 0; i < 13; i++) {
            vm.rollFork(forward ? expectedBlock + 100 : expectedBlock - 100);
            rollForkBefore(expectedBlockTimestamp + i);
            assertEq(
                block.number,
                expectedBlock + ((i == 12) ? 1 : 0),
                Useful.concat(
                    "move ", forward ? "forward" : "backward", " goes to the right place: ", Useful.toString(i)
                )
            );
        }
    }

    function test_boundaries() public {
        // exact block & timestamp
        uint256 expectedBlock = 16683843;
        vm.rollFork(expectedBlock);
        uint256 expectedTimestamp = block.timestamp;

        uint256 rollCount = rollForkBefore(expectedTimestamp); // zero move
        assertEq(rollCount, 0, "zero move has zero rolls");
        assertEq(block.number, expectedBlock, "zero move stays at the same block");

        // exact timestamp
        // roll backward
        _wholeBlock(expectedBlock, expectedTimestamp, true);
        // then forward
        _wholeBlock(expectedBlock, expectedTimestamp, false);
    }
}
