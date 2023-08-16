// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.5.1;

// solhint-disable func-name-mixedcase
// solhint-disable no-console
import {console2 as console} from "forge-std/console2.sol";

import {LendingRegistry} from "src/LendingRegistry.sol";
import {LendingLogicCompound} from "src/Strategies/LendingLogicCompound.sol";

import {Deployed, ChainState, ChainStateLending} from "./Deployed.sol";
import {TestLendingLogic} from "./TestLendingLogic.sol";
import {TestData} from "./TestData.t.sol";

// TODO: add AAVE lending logic

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
            Deployed.LENDINGLOGICCOMPOUND,
            Deployed.PROTOCOLCOMPOUND,
            Deployed.CDAI,
            Deployed.DAI,
            22280000775866001,
            22305072630290969
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
            Deployed.LENDINGLOGICCOMPOUND,
            Deployed.PROTOCOLCOMPOUND,
            Deployed.CCOMP,
            Deployed.COMP,
            19822320235702758,
            20457908950560109
        );
    }
}

contract TestCompoundAave is TestLendingLogic {
    constructor() {
        TestLendingLogic.initialise(
            Deployed.LENDINGLOGICCOMPOUND,
            Deployed.PROTOCOLCOMPOUND,
            Deployed.CAAVE,
            Deployed.AAVE,
            443497473591241,
            20625307800193479
        );
    }
}

// add this in as a test of decimals - cUSDC has 8 and USDC has 6!!!!
contract TestCompoundUSDC is TestLendingLogic {
    constructor() {
        TestLendingLogic.initialise(
            Deployed.LENDINGLOGICCOMPOUND,
            Deployed.PROTOCOLCOMPOUND,
            Deployed.CUSDC,
            Deployed.USDC,
            23165637618350606,
            23000 // 2.3 cents (in USDC 6 decimals)
        );

        vm.startPrank(Deployed.OWNER);
        // set up the lending registry
        lendingRegistry.setWrappedToProtocol(Deployed.CUSDC, Deployed.PROTOCOLCOMPOUND);
        lendingRegistry.setWrappedToUnderlying(Deployed.CUSDC, Deployed.USDC);
        // lendingRegistry.setProtocolToLogic(Deployed.PROTOCOLCOMPOUND, Deployed.LENDINGLOGICCOMPOUND;
        lendingRegistry.setUnderlyingToProtocolWrapped(Deployed.USDC, Deployed.PROTOCOLCOMPOUND, Deployed.CUSDC);
        vm.stopPrank();
    }
}
