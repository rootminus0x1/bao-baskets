// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.5.1;

import {LendingRegistry} from "src/LendingRegistry.sol";
import {Deployed} from "test/Deployed.sol";

library LendingRegistrySetup {
    function addLendingLogic(address strategy, bytes32 protocol, address wrapped, address underlying) external {
        LendingRegistry lendingRegistry = LendingRegistry(Deployed.LENDINGREGISTRY);

        // set up the lendingRegistry with the strategy
        lendingRegistry.setWrappedToProtocol(wrapped, protocol);
        lendingRegistry.setWrappedToUnderlying(wrapped, underlying);
        lendingRegistry.setProtocolToLogic(protocol, strategy);
        lendingRegistry.setUnderlyingToProtocolWrapped(underlying, protocol, wrapped);
    }
}
