// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.5.1;

import {console2 as console} from "forge-std/console2.sol";
import {Test, Vm} from "forge-std/Test.sol";

import {LoggingTest} from "./LoggingTest.sol";
import {DateUtils} from "DateUtils/DateUtils.sol";
import {Useful} from "./Useful.sol";

// TODO: change the chainstate and chainfork contracts into structs

// this contract is solely designed to work with ChainFork below
// because try/catch only work for contract calls
contract _ForkHook {
    constructor(Vm vm) {
        // if there is no active fork this will revert
        vm.activeFork();
    }
}

// this contract ensures that we have a fork to work on in a test
// a fork is either created on the command line via --fork-url before this is constructed
// or a new fork is created.
contract ChainFork is Test {
    constructor() {
        // startLogging("ChainFork");
        string memory url = vm.envString("MAINNET_RPC_URL");
        // console.log("MAINNET_RPC_URL=%s", url);
        // create a fork if one is not created
        try new _ForkHook(vm) returns (_ForkHook) {
            // if we get here that means we have an active fork, so do nothing
            // console.log("--fork-url, we see you!");
        } catch {
            // if _ForkHook reverts on construction then we need to create an active fork
            // console.log("no --fork-url so create a fork");
            vm.createSelectFork(url);
        }
    }
}

library Roller {
    struct Bounds {
        uint256 leftBlock;
        uint256 leftTimestamp;
        uint256 rightBlock;
        uint256 rightTimestamp;
    }

    function rollForkToBlockContaining(Vm vm, uint256 targetTimestamp, Bounds memory bounds)
        public
        returns (uint256 rollCount)
    {
        bool logging = false;
        /*
        console.log("lastBlock=%d, %d", bound.lastBlock, bound.lastTimestamp);
        if (logging) {
            console.log("rollForkToBlockContaining(%s)", Useful.toStringThousands(targetTimestamp, Useful.underscore));
        }
        */
        //if (logging && int256(targetTimestamp) <= 0) console.log("can't go back beyond 1-Jan-1970");
        require(int256(targetTimestamp) > 0, "can't go back beyond 1-Jan-1970");
        //if (logging && targetTimestamp < 1438269973) console.log("can't go back beyond the start of the blockchain");
        require(targetTimestamp >= 1438269973, "can't go back beyond the start of the blockchain");

        // TODO: test if vm.roll is a more efficient way of rolling the vm than rollFork

        console.log("targetTimestamp=%s", Useful.toStringThousands(targetTimestamp, Useful.underscore));
        if (targetTimestamp != block.timestamp) {
            // not already there, ok do the search
            // an interpolated binary upper-bound search to find the leftmost (i.e. the block before)
            // L := 0
            // R := n
            // make sure we handle an uninitialised leftTimestamp correctly
            if (bounds.leftBlock == 0) bounds.leftTimestamp = 1438269973; // DateUtils.convertDateTimeStringToTimestamp("2015-07-30 15:26:13");

            require(
                targetTimestamp >= bounds.leftTimestamp && targetTimestamp <= bounds.rightTimestamp,
                "target must be within bounds"
            );

            // utilise the current block info to reduce the bounds
            if (block.timestamp > targetTimestamp && block.timestamp < bounds.rightTimestamp) {
                bounds.rightBlock = block.number;
                bounds.rightTimestamp = block.timestamp;
            }
            if (block.timestamp < targetTimestamp && block.timestamp > bounds.leftTimestamp) {
                bounds.leftBlock = block.number;
                bounds.leftTimestamp = block.timestamp;
            }

            if (logging) {
                console.log(
                    "left=%s, right=%s to start",
                    Useful.toStringThousands(bounds.leftBlock, Useful.comma),
                    Useful.toStringThousands(bounds.rightBlock, Useful.comma)
                );
                console.log(
                    "left=(%s), right=(%s) to start",
                    Useful.toStringThousands(bounds.leftTimestamp, Useful.underscore),
                    Useful.toStringThousands(bounds.rightTimestamp, Useful.underscore)
                );
            }

            // while L < R:
            while (bounds.leftBlock <= bounds.rightBlock) {
                // m := floor((L + R) / 2)
                uint256 middleBlock = bounds.leftBlock
                    + ((targetTimestamp - bounds.leftTimestamp) * (bounds.rightBlock - bounds.leftBlock))
                        / (bounds.rightTimestamp - bounds.leftTimestamp);
                // if A[m] < T:
                require(uint64(middleBlock) == middleBlock, "middleBlock overflows u64");
                vm.rollFork(middleBlock);
                rollCount++;
                if (logging) {
                    console.log(
                        "(middle) rolled to %s, %s",
                        Useful.toStringThousands(block.number, Useful.comma),
                        Useful.toStringThousands(block.timestamp, Useful.underscore)
                    );
                }
                uint256 middleTimestamp = block.timestamp;
                if (middleTimestamp == targetTimestamp) {
                    break;
                } else if (middleTimestamp < targetTimestamp) {
                    // L := m + 1
                    bounds.leftBlock = middleBlock + 1;
                    vm.rollFork(bounds.leftBlock);
                    rollCount++;
                    if (logging) {
                        console.log(
                            "(left move) rolled to %s, %s",
                            Useful.toStringThousands(block.number, Useful.comma),
                            Useful.toStringThousands(block.timestamp, Useful.underscore)
                        );
                    }
                    bounds.leftTimestamp = block.timestamp;
                    if (bounds.leftTimestamp > targetTimestamp) {
                        vm.rollFork(middleBlock);
                        rollCount++;
                        if (logging) {
                            console.log(
                                "(exit after left move) rolled to %s, %s",
                                Useful.toStringThousands(block.number, Useful.comma),
                                Useful.toStringThousands(block.timestamp, Useful.underscore)
                            );
                        }
                        break;
                    }
                } else {
                    // R := m
                    bounds.rightBlock = middleBlock - 1;
                    vm.rollFork(bounds.rightBlock);
                    rollCount++;
                    if (logging) {
                        console.log(
                            "(right move) rolled to %s, %s",
                            Useful.toStringThousands(block.number, Useful.comma),
                            Useful.toStringThousands(block.timestamp, Useful.underscore)
                        );
                    }
                    bounds.rightTimestamp = block.timestamp;
                    if (bounds.rightTimestamp < targetTimestamp) {
                        /*
                        vm.rollFork(middleBlock);
                        rollCount++;
                        if (logging) {
                            console.log(
                                "(exit after right move) rolled to %s, %s",
                                Useful.toStringThousands(block.number, Useful.comma),
                                Useful.toStringThousands(block.timestamp, Useful.underscore)
                            );
                        }
                        */
                        break;
                    }
                }
                /*
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
                */
            }
        }
        // return L
        if (logging) {
            console.log(
                "(result) is %s, %s",
                Useful.toStringThousands(block.number, Useful.comma),
                Useful.toStringThousands(block.timestamp, Useful.underscore)
            );
        }
        /*
        if (logging) {
            console.log(
                "result=%s, %s",
                Useful.toStringThousands(block.number, Useful.comma),
                Useful.toStringThousands(block.timestamp, Useful.underscore)
            );
        }
        */
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
        Roller.rollForkToBlockContaining(vm, targetTimestamp, Roller.Bounds(0, 0, lastBlock, lastTimestamp));
    }

    function rollForkBefore(string memory datetime) public {
        console.log("rollForkBefore(%s)", datetime);
        uint256 targetTimestamp = DateUtils.convertDateTimeStringToTimestamp(datetime);
        rollForkBefore(targetTimestamp);
        //.log("   rolled to %s", DateUtils.convertTimestampToDateTimeString(block.timestamp));
    }
}
