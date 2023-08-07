// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.5.1;

// solhint-disable func-name-mixedcase
// solhint-disable no-console
import {console2 as console} from "forge-std/console2.sol";

import {LendingRegistry} from "contracts/LendingRegistry.sol";
import {LendingLogicCompound} from "contracts/Strategies/LendingLogicCompound.sol";

import {Deployed, ChainState, ChainStateLending} from "./Deployed.sol";
import {TestLendingLogic} from "./TestLendingLogic.sol";
import {TestData} from "./TestData.t.sol";
import {Dai} from "./Dai.t.sol";

contract TestLendingRegistry is ChainStateLending, TestData {
    function test_LendingRegistryBasics() public {
        assertEq(lendingRegistry.owner(), Deployed.OWNER);

        uint256 bestApr;
        bytes32 bestProtocol;
        bytes32[] memory selectedProtocols;
        (bestApr, bestProtocol) = lendingRegistry.getBestApr(TestData.zeroAddress, selectedProtocols);

        assertEq(bestApr, TestData.zeroBigNumber);
        assertEq(bestProtocol, TestData.zeroBytes32);
    }
}

contract TestCompoundDai is TestLendingLogic {
    constructor() {
        TestLendingLogic.initialise(
            Deployed.LENDINGLOGICCOMPOUND, Deployed.PROTOCOLCOMPOUND, Deployed.CDAI, Deployed.DAI
        );
    }

    function test_Compound() public {
        LendingLogicCompound compoundLogic = LendingLogicCompound(Deployed.LENDINGLOGICCOMPOUND);
        assertNotEq(compoundLogic.blocksPerYear(), TestData.zeroBigNumber, "expected a non-zero blocksPerYear");
    }
}

contract TestCompoundComp is TestLendingLogic {
    constructor() {
        TestLendingLogic.initialise(
            Deployed.LENDINGLOGICCOMPOUND, Deployed.PROTOCOLCOMPOUND, Deployed.CCOMP, Deployed.COMP
        );
    }
}

contract TestCompoundAave is TestLendingLogic {
    constructor() {
        TestLendingLogic.initialise(
            Deployed.LENDINGLOGICCOMPOUND, Deployed.PROTOCOLCOMPOUND, Deployed.CAAVE, Deployed.AAVE
        );
    }
}
