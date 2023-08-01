// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.5.1;

import {LoggingTest} from "./LoggingTest.sol";
import {DateUtils} from "./SkeletonCodeworks/DateUtils/DateUtils.sol";
import {Useful} from "./Useful.sol";

contract ChainFork is LoggingTest {
    uint256 public fork;

    constructor() {
        //startLogging("ChainFork");
        string memory url = vm.envString("MAINNET_RPC_URL");
        clog("MAINNET_RPC_URL=", url);
        fork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(fork);
        assertEq(vm.activeFork(), fork);
    }
}

contract ChainState is ChainFork {
    uint256 public originalBlock;

    constructor(uint256 _blockNumber) {
        originalBlock = _blockNumber;
        vm.rollFork(originalBlock);
        assertEq(block.number, originalBlock);
    }

    function rollToOriginal() public {
        vm.rollFork(ChainFork.fork, originalBlock);
    }

    function rollForkBefore(uint256 targetTimestamp) public {
        startLogging("rollForkBefore");
        require(int256(targetTimestamp) > 0, "can't go back beyond 1-Jan-1970");
        // TODO: test if vm.roll is a more efficient way of rolling the vm than rollFork

        uint256 startBlock = block.number;
        uint256 startTimestamp = block.timestamp;

        clog("at block %s", Useful.toStringThousands(startBlock, Useful.comma));
        clog(
            "timestamp at %s, going to %s",
            Useful.toStringThousands(startTimestamp, Useful.underscore),
            Useful.toStringThousands(targetTimestamp, Useful.underscore)
        );

        uint256 timePerBlock = 12; // doesn't have to be accurate as we increase or decrease it accordingly
        clog("init timePerBlock=%d", timePerBlock);
        uint256 rollCount = 0;

        // do a binary search to find the leftmost (i.e. the block before)
        // https://en.wikipedia.org/wiki/Binary_search_algorithm

        // L := 0
        // R := n
        uint256 leftBlock = startBlock;
        uint256 rightBlock = startBlock;
        clog("init left=%s", Useful.toStringThousands(leftBlock, Useful.comma));
        clog("init right=%s", Useful.toStringThousands(rightBlock, Useful.comma));
        if (targetTimestamp < startTimestamp) {
            // calculate where leftBlock should be
            // and move rightBlock when we can
            while (true) {
                uint256 tryBlock = startBlock - (startTimestamp - targetTimestamp) / timePerBlock - 1;
                require(int256(tryBlock) > 1, "can't go back beyond the start of the blockchain");
                leftBlock = tryBlock;
                clog("left=%s", Useful.toStringThousands(leftBlock, Useful.comma));
                vm.rollFork(leftBlock);
                clog("rolled left to %s (%d)", Useful.toStringThousands(leftBlock, Useful.comma), ++rollCount);
                if (block.timestamp <= targetTimestamp) break;
                // recalculate timePerBlock it with the larger range
                timePerBlock = (startTimestamp - block.timestamp) / (startBlock - block.number);
                clog("timePerBlock=%d", timePerBlock);
                // can shift right over to this block as it's not the one
                rightBlock = block.number;
                clog("right=%s", Useful.toStringThousands(rightBlock, Useful.comma));
            }
        }
        if (targetTimestamp > startTimestamp) {
            // calculate where rightBlock should be
            // and move leftBlock when we can
            while (true) {
                uint256 tryBlock = startBlock + (targetTimestamp - startTimestamp) / timePerBlock + 1;
                rightBlock = tryBlock;
                clog("right=%s", Useful.toStringThousands(rightBlock, Useful.comma));
                vm.rollFork(rightBlock);
                clog("rolled right to %s (%d)", Useful.toStringThousands(rightBlock, Useful.comma), ++rollCount);
                if (block.timestamp >= targetTimestamp) break;
                // recalculate timePerBlock it with the larger range
                timePerBlock = (block.timestamp - startTimestamp) / (block.number - startBlock);
                clog("timePerBlock=%d", timePerBlock);
                // can shift right over to this block as it's not the one
                leftBlock = block.number;
                clog("left=%s", Useful.toStringThousands(rightBlock, Useful.comma));
            }
        }

        /*
        uint256 sampleBlocks = 100;
        clog(
            "about to roll fork to %s, to get a time/block sample",
            Useful.toStringThousands(startBlock - sampleBlocks, Useful.comma)
        );
        // TODO: support going back before block 100? go forward instead for sample?
        require(startBlock > sampleBlocks);
        vm.rollFork(startBlock - sampleBlocks);
        // we only go back to sample so below subtraction is safe.
        typicalBlockTime = (startTimestamp - block.timestamp) / sampleBlocks; // should be about 12 secs
        // back we go to the start (in case we don't have to move at all)
        vm.rollFork(startBlock);
        */
        startLogging("about to search");
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
        clog(
            "start left=%s, right=%s",
            Useful.toStringThousands(leftBlock, Useful.comma),
            Useful.toStringThousands(rightBlock, Useful.comma)
        );

        uint256 middleBlock;
        // while L < R:
        while (leftBlock < rightBlock) {
            clog(
                "left=%s, right=%s",
                Useful.toStringThousands(leftBlock, Useful.comma),
                Useful.toStringThousands(rightBlock, Useful.comma)
            );
            // m := floor((L + R) / 2)
            middleBlock = (leftBlock + rightBlock) / 2;
            // if A[m] < T:
            vm.rollFork(middleBlock);
            clog("rolled to %s (%d)", Useful.toStringThousands(middleBlock, Useful.comma), ++rollCount);
            if (block.timestamp < targetTimestamp) {
                // L := m + 1
                leftBlock = middleBlock + 1;
            } else {
                // R := m
                rightBlock = middleBlock;
            }
        }
        popLogging();
        // return L
        popLogging();
    }

    function rollForkBefore(string memory datetime) public {
        uint256 targetTimestamp = DateUtils.convertDateTimeStringToTimestamp(datetime);
        //clog("  targetTimestamp=%d", targetTimestamp);
        rollForkBefore(targetTimestamp);
    }
}
