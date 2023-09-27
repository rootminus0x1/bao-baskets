// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.5.1;

import {LendingRegistry} from "src/LendingRegistry.sol";
import {ChainFork} from "./ChainState.sol";
import {Deployed} from "test/Deployed.sol";

contract ChainStateLending is ChainFork {
    LendingRegistry public lendingRegistry;

    constructor() {
        vm.rollFork(Deployed.blockWithCompoundAaveKashi);
        lendingRegistry = LendingRegistry(Deployed.LENDINGREGISTRY);
    }
}
