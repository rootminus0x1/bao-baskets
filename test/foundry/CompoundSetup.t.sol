// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.5.1;

// solhint-disable func-name-mixedcase
// solhint-disable no-console
import {console2 as console} from "forge-std/console2.sol";

import {LendingRegistry} from "contracts/LendingRegistry.sol";
import {LendingLogicCompound} from "contracts/Strategies/LendingLogicCompound.sol";

import {Deployed, ChainState} from "./Deployed.sol";
import {Useful} from "./Useful.sol";
import {TestData} from "./TestData.t.sol";
import {Dai} from "./Dai.t.sol";

contract TestLendingRegistry is ChainState, Deployed, TestData {
    function test_LendingRegistryBasics() public {
        LendingRegistry lendingRegistry = LendingRegistry(Deployed.LENDINGREGISTRY);
        assertEq(lendingRegistry.owner(), Deployed.OWNER);

        uint256 bestApr;
        bytes32 bestProtocol;
        bytes32[] memory selectedProtocols;
        (bestApr, bestProtocol) = lendingRegistry.getBestApr(TestData.zeroAddress, selectedProtocols);

        assertEq(bestApr, TestData.zeroBigNumber);
        assertEq(bestProtocol, TestData.zeroBytes32);
    }
}

contract TestCompound is ChainState, Deployed, Useful, TestData {
    bool public logging = false;

    function setUp() public virtual {
        // logging = !streq(vm.envString("LOG"), "");
        // if (logging) console.log("LOG = '%s'", vm.envString("LOG"));
        if (logging) console.log(vm.envString("MAINNET_RPC_URL"));

        //mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        //vm.selectFork(mainnetFork);
        //vm.rollFork(BLOCKNUMBER);
    }

    function test_Logic() public {
        // get some underlying DAI
        address underlying = Deployed.DAI.addr;

        // check out the underlying contract
        Dai dai = Dai(underlying);
        uint256 daiAmount = 12345;
        address wallet = msg.sender;
        deal(Deployed.DAI.addr, wallet, daiAmount);
        assertEq(dai.balanceOf(wallet), daiAmount);

        // get best Apr for underlying (obs compound :-)
        LendingRegistry lendingRegistry = LendingRegistry(Deployed.LENDINGREGISTRY);
        uint256 bestApr;
        bytes32 bestProtocol;
        bytes32[] memory selectedProtocols = new bytes32[](1);
        selectedProtocols[0] = Deployed.COMPOUNDPROTOCOL;
        (bestApr, bestProtocol) = lendingRegistry.getBestApr(underlying, selectedProtocols);

        assertNotEq(bestApr, TestData.zeroBigNumber, "expected a non-zero number for apr");
        assertEq(bestProtocol, Deployed.COMPOUNDPROTOCOL, "expected the compound protocol");

        if (logging) console.log("APR", bestApr, "protocol", uint256(bestProtocol));

        // get wrapped via protocol
        // mapping(address => mapping(bytes32 => address)) public underlyingToProtocolWrapped;
        address wrapped = lendingRegistry.underlyingToProtocolWrapped(underlying, bestProtocol);
        assertEq(wrapped, CDAI.addr, "expected the wrapped to be CDAI");

        // get the lending logic
        // mapping(bytes32 => address) public protocolToLogic;
        address logic = lendingRegistry.protocolToLogic(bestProtocol);
        assertEq(logic, COMPOUNDLENDINGSTRATEGY, "incorrect lending strategy (logic)");

        // check other mappings are correct
        // mapping(address => bytes32) public wrappedToProtocol;
        // mapping(address => address) public wrappedToUnderlying;
        assertEq(lendingRegistry.wrappedToProtocol(wrapped), bestProtocol);
        assertEq(lendingRegistry.wrappedToUnderlying(wrapped), underlying);

        // back to the logic
        LendingLogicCompound compoundLogic = LendingLogicCompound(logic);

        // test basic functionality
        assertNotEq(compoundLogic.blocksPerYear(), TestData.zeroBigNumber, "expected a non-zero blocksPerYear");
        assertEq(compoundLogic.getAPRFromWrapped(wrapped), bestApr, "APRs should match from different routes");
        assertEq(compoundLogic.getAPRFromUnderlying(underlying), bestApr, "APRs should match from different routes #2");
        if (logging) {
            // not sure how to test this
            console.log("exchange rate", compoundLogic.exchangeRate(wrapped));
            console.log("exchange rate view", compoundLogic.exchangeRateView(wrapped));
        }

        // test lending
        uint256 amount = daiAmount / 2;
        address[] memory targets;
        bytes[] memory data;
        (targets, data) = compoundLogic.lend(underlying, amount, wallet);
        assertEq(targets.length, data.length, "lend return arrays must be the same size");
        assertEq(targets.length, 3, "3 returned TX's");
        assertEq(targets[0], underlying, "approve 0 on the underlying");
        assertEq(data[0].length, 68, "4bytes + two parameters = 68 bytes");
        assertEq(Useful.extractUInt256(data[0], 36), 0, "must be 0");
        assertEq(targets[1], underlying, "approve amount on the underlying");
        assertEq(data[1].length, 68, "4bytes + two parameters = 68 bytes");
        assertEq(Useful.extractUInt256(data[1], 36), amount, "must be amount");

        if (logging) {
            console.log("lend(", amount, ") -> (");
            for (uint256 t = 0; t < targets.length; t++) {
                console.log(targets[t], " ->");
                console.logBytes(data[t]);
            }
            console.log(")");
        }
    }
}
