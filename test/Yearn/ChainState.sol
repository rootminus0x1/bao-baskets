// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.5.1;

import {console2 as console} from "forge-std/console2.sol";
import {Test, Vm} from "forge-std/Test.sol";

import {LoggingTest} from "./LoggingTest.sol";
import {DateUtils} from "DateUtils/DateUtils.sol";
import {Useful} from "./Useful.sol";

contract ChainFork is Test {
    uint256 public fork;

    constructor() {
        // startLogging("ChainFork");
        string memory url = vm.envString("MAINNET_RPC_URL");
        // console.log("MAINNET_RPC_URL=%s", url);
        fork = vm.createFork(url);
        vm.selectFork(fork);
        assertEq(vm.activeFork(), fork);
    }
}

library Roller {
    function rollForkToBlockContaining(Vm vm, uint256 targetTimestamp, uint256 lastBlock, uint256 lastTimestamp)
        public
    {
        bool logging = false;
        if (logging) {
            console.log("rollForkToBlockContaining(%s)", Useful.toStringThousands(targetTimestamp, Useful.underscore));
        }
        if (logging && int256(targetTimestamp) <= 0) console.log("can't go back beyond 1-Jan-1970");
        require(int256(targetTimestamp) > 0, "can't go back beyond 1-Jan-1970");
        if (logging && targetTimestamp < 1438269973) console.log("can't go back beyond the start of the blockchain");
        require(targetTimestamp >= 1438269973, "can't go back beyond the start of the blockchain");

        // TODO: test if vm.roll is a more efficient way of rolling the vm than rollFork

        //uint256 rollCount = 0;
        uint256 startBlock = block.number;
        uint256 startTimestamp = block.timestamp;

        // do an interpolated binary upper-bound search to find the leftmost (i.e. the block before)
        // L := 0
        // R := n
        uint256 leftBlock;
        uint256 leftTimestamp;
        uint256 rightBlock;
        uint256 rightTimestamp;

        if (targetTimestamp != startTimestamp) {
            if (targetTimestamp < startTimestamp) {
                leftBlock = 0;
                leftTimestamp = DateUtils.convertDateTimeStringToTimestamp("2015-07-30 15:26:13");
                rightBlock = startBlock;
                rightTimestamp = startTimestamp;
            } else {
                leftBlock = startBlock;
                leftTimestamp = startTimestamp;
                rightBlock = lastBlock;
                rightTimestamp = lastTimestamp;
            }
            if (logging) {
                console.log(
                    "left=%s, right=%s to start",
                    Useful.toStringThousands(leftBlock, Useful.comma),
                    Useful.toStringThousands(rightBlock, Useful.comma)
                );
                console.log(
                    "left=(%s), right=(%s) to start",
                    Useful.toStringThousands(leftTimestamp, Useful.underscore),
                    Useful.toStringThousands(rightTimestamp, Useful.underscore)
                );
                //console.log("rolls=%d", rollCount);
            }

            // while L < R:
            while (leftBlock <= rightBlock) {
                // m := floor((L + R) / 2)
                uint256 middleBlock = leftBlock
                    + ((targetTimestamp - leftTimestamp) * (rightBlock - leftBlock)) / (rightTimestamp - leftTimestamp);
                // if A[m] < T:
                require(
                    uint64(middleBlock) == middleBlock,
                    Useful.concat("middleBlock overflows u64, ", Useful.toStringThousands(middleBlock, Useful.comma))
                );
                vm.rollFork(middleBlock);
                //rollCount++;
                if (logging) {
                    console.log(
                        "rolled to %s, %s",
                        Useful.toStringThousands(middleBlock, Useful.comma),
                        Useful.toStringThousands(block.timestamp, Useful.underscore)
                    );
                }
                uint256 middleTimestamp = block.timestamp;
                if (middleTimestamp == targetTimestamp) {
                    break;
                } else if (middleTimestamp < targetTimestamp) {
                    // L := m + 1
                    leftBlock = middleBlock + 1;
                    vm.rollFork(leftBlock);
                    //rollCount++;
                    leftTimestamp = block.timestamp;
                    if (leftTimestamp > targetTimestamp) {
                        vm.rollFork(middleBlock);
                        //rollCount++;
                        break;
                    }
                } else {
                    // R := m
                    rightBlock = middleBlock - 1;
                    vm.rollFork(rightBlock);
                    //rollCount++;
                    rightTimestamp = block.timestamp;
                    if (rightTimestamp < targetTimestamp) {
                        vm.rollFork(middleBlock);
                        //rollCount++;
                        break;
                    }
                }
                if (logging) {
                    console.log(
                        "left=%s, right=%s",
                        Useful.toStringThousands(leftBlock, Useful.comma),
                        Useful.toStringThousands(rightBlock, Useful.comma)
                    );
                    console.log(
                        "left=(%s), right=(%s)",
                        Useful.toStringThousands(leftTimestamp, Useful.underscore),
                        Useful.toStringThousands(rightTimestamp, Useful.underscore)
                    );
                }
                //require(rollCount < 20);
            }
        }
        // return L
        if (logging) {
            console.log(
                "result=%s, %s",
                Useful.toStringThousands(block.number, Useful.comma),
                Useful.toStringThousands(block.timestamp, Useful.underscore)
            );
        }
    }
}

contract ChainState is ChainFork {
    uint256 public immutable lastBlock;
    uint256 public immutable lastTimestamp;

    // TODO: make this a constructor and add a snapshot with reset function

    constructor() ChainFork() {
        lastBlock = block.number;
        lastTimestamp = block.timestamp;
    }

    function rollForkTo(uint256 blockNumber) public {
        vm.rollFork(blockNumber);
        // assertEq(block.number, blockNumber);
    }

    function rollForkBefore(uint256 targetTimestamp) public /*logMe("rollForkBefore")*/ {
        Roller.rollForkToBlockContaining(vm, targetTimestamp, lastBlock, lastTimestamp);
    }

    function rollForkBefore(string memory datetime) public {
        console.log("rollForkBefore(%s)", datetime);
        uint256 targetTimestamp = DateUtils.convertDateTimeStringToTimestamp(datetime);
        rollForkBefore(targetTimestamp);
        //.log("   rolled to %s", DateUtils.convertTimestampToDateTimeString(block.timestamp));
    }
}
