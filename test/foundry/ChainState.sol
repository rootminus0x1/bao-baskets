// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.5.1;

import {console2 as console} from "forge-std/console2.sol";
import {Test, Vm} from "forge-std/Test.sol";

import {LoggingTest} from "./LoggingTest.sol";
import {DateUtils} from "./SkeletonCodeworks/DateUtils/DateUtils.sol";
import {Useful} from "./Useful.sol";

contract ChainFork is Test {
    uint256 public fork;

    constructor() {
        //startLogging("ChainFork");
        string memory url = vm.envString("MAINNET_RPC_URL");
        console.log("MAINNET_RPC_URL=%s", url);
        fork = vm.createFork(url);
        vm.selectFork(fork);
        assertEq(vm.activeFork(), fork);
    }
}

library Roller {
    /*
    function _rolltoGuess(uint256 aBlock, uint256 bBlock, uint256 aTimestamp, uint256 bTimestamp, uint256 guessTimePerBlock) private returns (uint256 newABlock, uint256 newBBlock, newGuessTimePerBlock) {
            while (true) {
                uint256 tryBlock = startBlock - (startTimestamp - targetTimestamp) / timePerBlock;
                require(int256(tryBlock) > 1, "can't go back beyond the start of the blockchain");
                leftBlock = tryBlock;
                console.log("left=%d", leftBlock);
                //l("left", leftBlock);
                rollForkTo(leftBlock);
                //l("rolled left to", leftBlock).l(++rollCount);
                if (block.timestamp <= targetTimestamp) break;
                // recalculate timePerBlock it with the larger range
                timePerBlock = (startTimestamp - block.timestamp) / (startBlock - block.number);
                //clog("timePerBlock=%d", timePerBlock);
                // can shift right over to this block as it's not the one
                rightBlock = block.number;
                console.log("right=%d", rightBlock);
                //l("right", rightBlock);
            }




    }
    */

    function rollForkBefore(Vm vm, uint256 targetTimestamp) public /*logMe("rollForkBefore")*/ {
        //console.log("rollForkBefore(%d)", targetTimestamp);
        require(int256(targetTimestamp) > 0, "can't go back beyond 1-Jan-1970");
        // TODO: test if vm.roll is a more efficient way of rolling the vm than rollFork

        //uint256 startRollCount = rollCount;
        uint256 startBlock = block.number;
        uint256 startTimestamp = block.timestamp;

        //l(n("at block").v(startBlock));
        //l(n("timestamp at").v_(startTimestamp).comma().n("going to").v_(targetTimestamp));
        //console.log("at block %d ", startBlock);
        //console.log("timestamp at %d going to %d", startTimestamp, targetTimestamp);

        uint256 timePerBlock = 12; // doesn't have to be accurate as we increase or decrease it accordingly
        // l(n("init timePerBlock").v(timePerBlock));
        //l("timePerBlock");
        //l(n("timePerBlock"));

        // do a binary search to find the leftmost (i.e. the block before)
        // https://en.wikipedia.org/wiki/Binary_search_algorithm
        // L := 0
        // R := n
        uint256 leftBlock = startBlock;
        uint256 rightBlock = startBlock;
        //console.log("left=%d, right=%d, start", leftBlock, rightBlock);

        //l("init left", leftBlock);
        //l("init right", rightBlock);

        // TODO: section this always finds a block very close to one end because it
        // rarely does more than one loop (even if the timePerBlock is set to 1! - why is that?)
        // so the same algorithm should be done both ways round (break it out to a function for that)
        if (targetTimestamp < startTimestamp) {
            // calculate where leftBlock should be
            // and move rightBlock when we can
            while (true) {
                uint256 tryBlock = startBlock - (startTimestamp - targetTimestamp) / timePerBlock;
                require(int256(tryBlock) > 1, "can't go back beyond the start of the blockchain");
                leftBlock = tryBlock;
                // console.log(" left=%d", leftBlock);
                //l("left", leftBlock);
                vm.rollFork(leftBlock);
                //l("rolled left to", leftBlock).l(++rollCount);
                if (block.timestamp <= targetTimestamp) break;
                // recalculate timePerBlock it with the larger range
                timePerBlock = (startTimestamp - block.timestamp) / (startBlock - block.number);
                //clog("timePerBlock=%d", timePerBlock);
                // can shift right over to this block as it's not the one
                rightBlock = block.number;
                // console.log("right=%d", rightBlock);
                //l("right", rightBlock);
            }
        }
        if (targetTimestamp > startTimestamp) {
            // calculate where rightBlock should be
            // and move leftBlock when we can
            while (true) {
                uint256 tryBlock = startBlock + (targetTimestamp - startTimestamp) / timePerBlock + 1;
                rightBlock = tryBlock;
                //console.log("right=%d", rightBlock);
                //clog("right=%s", Useful.toStringThousands(rightBlock, Useful.comma));
                vm.rollFork(rightBlock);
                //clog("rolled right to %s (%d)", Useful.toStringThousands(rightBlock, Useful.comma), ++rollCount);
                if (block.timestamp >= targetTimestamp) break;
                // recalculate timePerBlock it with the larger range
                timePerBlock = (block.timestamp - startTimestamp) / (block.number - startBlock);
                //clog("timePerBlock=%d", timePerBlock);
                // can shift right over to this block as it's not the one
                leftBlock = block.number;
                //console.log(" left=%d", leftBlock);
            }
        }
        // console.log("left=%d, right=%d, after guess", leftBlock, rightBlock);
        // console.log("rolls=%d", rollCount - startRollCount);

        /*
        uint256 sampleBlocks = 100;
        clog(
            "about to roll fork to %s, to get a time/block sample",
            Useful.toStringThousands(startBlock - sampleBlocks, Useful.comma)
        );
        // TODO: support going back before block 100? go forward instead for sample?
        require(startBlock > sampleBlocks);
        rollForkTo(startBlock - sampleBlocks);
        // we only go back to sample so below subtraction is safe.
        typicalBlockTime = (startTimestamp - block.timestamp) / sampleBlocks; // should be about 12 secs
        // back we go to the start (in case we don't have to move at all)
        rollForkTo(startBlock);
        */
        /*
        if (targetTimestamp <= startTimestamp) {
            // going backwards
            leftBlock = (startTimestamp - targetTimestamp) * typicalBlockTime * 2; // *2 to ensure
            rightBlock = startBlock;
        } else {
            // going forwards
            leftBlock = startBlock;
            rightBlock = (targetTimestamp - startTimestamp) * typicalBlockTime * 2; // *2 to ensure
        }
        */
        //clog(
        //    "start left=%s, right=%s",
        //    Useful.toStringThousands(leftBlock, Useful.comma),
        //    Useful.toStringThousands(rightBlock, Useful.comma)
        //);

        uint256 middleBlock;
        // while L < R:
        while (leftBlock < rightBlock) {
            //clog(
            //    "left=%s, right=%s",
            //    Useful.toStringThousands(leftBlock, Useful.comma),
            //    Useful.toStringThousands(rightBlock, Useful.comma)
            //);
            // m := floor((L + R) / 2)
            middleBlock = (leftBlock + rightBlock) / 2;
            // if A[m] < T:
            vm.rollFork(middleBlock);
            //clog("rolled to %s (%d)", Useful.toStringThousands(middleBlock, Useful.comma), ++rollCount);
            if (block.timestamp < targetTimestamp) {
                // L := m + 1
                leftBlock = middleBlock + 1;
            } else {
                // R := m
                rightBlock = middleBlock;
            }
        }
        // return L
        // console.log("block=%d", block.number);
        // console.log("rolls=%d", rollCount - startRollCount);
    }
}

contract ChainState is ChainFork {
    //uint256 public originalBlock;
    uint256 public rollCount;

    function rollForkTo(uint256 blockNumber) public {
        vm.rollFork(blockNumber);
        rollCount++;
        // assertEq(block.number, blockNumber);
    }

    function rollForkBefore(uint256 targetTimestamp) public /*logMe("rollForkBefore")*/ {
        Roller.rollForkBefore(vm, targetTimestamp);
    }

    function rollForkBefore(string memory datetime) public {
        console.log("rollForkBefore(%s)", datetime);
        uint256 targetTimestamp = DateUtils.convertDateTimeStringToTimestamp(datetime);
        rollForkBefore(targetTimestamp);
        console.log("   rolled to %s", DateUtils.convertTimestampToDateTimeString(block.timestamp));
    }
}
