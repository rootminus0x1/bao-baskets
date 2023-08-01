// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.5.1;

// solhint-disable func-name-mixedcase
// solhint-disable no-console
// import {console2 as console} from "forge-std/console2.sol";

import {ILendingLogic} from "contracts/Interfaces/ILendingLogic.sol";
import {IERC20} from "contracts/Interfaces/IERC20.sol";

import {Deployed, ChainStateLending} from "./Deployed.sol";
import {TestData} from "./TestData.t.sol";
import {Useful} from "./Useful.sol";

abstract contract TestLendingLogic is ChainStateLending, TestData {
    address logic;
    bytes32 protocol;
    address wrapped;
    address underlying;

    ILendingLogic iLogic;

    /*
    constructor(address _logic, bytes32 _protocol, address _wrapped, address _underlying) {
        logic = _logic;
        protocol = _protocol;
        wrapped = _wrapped;
        underlying = _underlying;

        iLogic = ILendingLogic(_logic);
    }
    */

    function create(address _logic, bytes32 _protocol, address _wrapped, address _underlying) public {
        logic = _logic;
        protocol = _protocol;
        wrapped = _wrapped;
        underlying = _underlying;

        iLogic = ILendingLogic(logic);
    }

    function dumpState(string calldata func) internal view {
        clog("in", func);
        clog("  logic=", logic);
        clog("  protocol=", protocol);
        clog("  wrapped=", wrapped);
        clog("  underlying=", underlying);
    }

    function test_lendingManagerSetup() public {
        // dumpState("test_lendingManagerSetup");
        // mapping(address => mapping(bytes32 => address)) public underlyingToProtocolWrapped;
        assertEq(
            lendingRegistry.underlyingToProtocolWrapped(underlying, protocol),
            wrapped,
            "incorrect wrapped stored in underlyingToProtocolWrapped"
        );
        // mapping(bytes32 => address) public protocolToLogic;
        assertEq(lendingRegistry.protocolToLogic(protocol), logic, "incorrect logic stored in protocolToLogic");
        // mapping(address => bytes32) public wrappedToProtocol;
        assertEq(lendingRegistry.wrappedToProtocol(wrapped), protocol, "incorrect protocol stored in wrappedToProtocol");
        // mapping(address => address) public wrappedToUnderlying;
        assertEq(
            lendingRegistry.wrappedToUnderlying(wrapped),
            underlying,
            "incorrect underlying stored in wrappedToUnderlying"
        );
    }

    function test_getBestApr() public {
        // get best Apr for underlying

        uint256 bestApr;
        bytes32 bestProtocol;
        bytes32[] memory selectedProtocols = new bytes32[](1);
        selectedProtocols[0] = protocol;
        (bestApr, bestProtocol) = lendingRegistry.getBestApr(underlying, selectedProtocols);
        assertEq(bestProtocol, protocol, "should return the given protocol");
        assertEq(bestProtocol, protocol, "should return the given protocol");
        assertLe(iLogic.getAPRFromWrapped(wrapped), bestApr, "APRs should match from different routes");
        assertLe(iLogic.getAPRFromUnderlying(underlying), bestApr, "APRs should match from different routes #2");

        assertNotEq(bestApr, TestData.zeroBigNumber, "expected a non-zero number for apr");
        assertEq(bestProtocol, protocol, "expected the compound protocol");
    }

    function test_Logic() public {
        // check out the underlying contract
        uint256 underlyingAmount = 12345;
        address wallet = msg.sender;
        deal(underlying, wallet, underlyingAmount);
        assertEq(IERC20(underlying).balanceOf(wallet), underlyingAmount, "unable to deal underlying");

        // test basic functionality
        uint256 bestApr;
        bytes32 bestProtocol;
        bytes32[] memory selectedProtocols = new bytes32[](1);
        selectedProtocols[0] = protocol;
        (bestApr, bestProtocol) = lendingRegistry.getBestApr(underlying, selectedProtocols);

        uint256 apr = iLogic.getAPRFromWrapped(wrapped);
        assertEq(apr, iLogic.getAPRFromUnderlying(underlying), "underlying and wrapped have different APRs");
        assertEq(bestApr, apr, "apr not the same as bestApr");

        // not sure how to test these
        clog("exchange rate", iLogic.exchangeRate(wrapped));
        clog("exchange rate view", iLogic.exchangeRateView(wrapped));
        clog("APR: %s", apr);
        clog("APR: %s%%", Useful.toStringScaled(apr, 18 - 2));

        // test lending
        uint256 lendingAmount = underlyingAmount / 2;
        address[] memory targets;
        bytes[] memory data;
        (targets, data) = iLogic.lend(underlying, lendingAmount, wallet);
        assertEq(targets.length, data.length, "lend return arrays must be the same size");
        assertEq(targets.length, 3, "3 returned TX's");
        assertEq(targets[0], underlying, "approve 0 on the underlying");
        assertEq(data[0].length, 68, "4bytes + two parameters = 68 bytes");
        assertEq(Useful.extractUInt256(data[0], 36), 0, "must be 0");
        assertEq(targets[1], underlying, "approve amount on the underlying");
        assertEq(data[1].length, 68, "4bytes + two parameters = 68 bytes");
        assertEq(Useful.extractUInt256(data[1], 36), lendingAmount, "must be amount");

        /*
        clog("lend(", lendingAmount, ") -> (");
        for (uint256 t = 0; t < targets.length; t++) {
            clog(targets[t], " ->");
            console.logBytes(data[t]);
        }
        clog(")");
        }
        */
    }
}
