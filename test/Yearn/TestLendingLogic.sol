// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.5.1;

// solhint-disable func-name-mixedcase
// solhint-disable no-console
import {console2 as console} from "forge-std/console2.sol";

import {ILendingLogic} from "src/Interfaces/ILendingLogic.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IEIP20} from "src/Interfaces/IEIP20.sol";

import {Deployed, ChainStateLending} from "./Deployed.sol";
import {TestData} from "./TestData.t.sol";
import {Useful} from "./Useful.sol";

abstract contract TestLendingLogic is ChainStateLending, TestData {
    address private logic;
    bytes32 private protocol;
    address private wrapped;
    string private wrappedName;
    uint256 private wrappedDecimals;
    address private underlying;
    string private underlyingName;
    uint256 private underlyingDecimals;
    uint256 private apr;
    uint256 private exchangeRate;

    ILendingLogic iLogic;

    function initialise(
        address _logic,
        bytes32 _protocol,
        address _wrapped,
        address _underlying,
        uint256 _apr,
        uint256 _exchangeRate
    ) public {
        logic = _logic;
        protocol = _protocol;
        wrapped = _wrapped;
        wrappedName = IEIP20(wrapped).symbol();
        wrappedDecimals = IEIP20(wrapped).decimals();
        underlying = _underlying;
        underlyingName = IEIP20(underlying).symbol();
        underlyingDecimals = IEIP20(underlying).decimals();
        apr = _apr;
        exchangeRate = _exchangeRate;

        iLogic = ILendingLogic(logic);
    }

    function test_lendingRegistrySetup() public {
        require(logic != address(0), "TestLendingLogic not initialised");
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

    function test_exchangeRate() public {
        // recipe uses the exchange rate
        uint256 one = 10 ** wrappedDecimals;
        uint256 thisExchangeRate = iLogic.exchangeRate(wrapped); // wrapped to underlying
        uint256 underlyingAmountRecipe = one * thisExchangeRate / (1e18) + 1;
        uint256 underlyingAmount = one * thisExchangeRate / (10 ** underlyingDecimals) + 1;

        console.log(
            "Recipe calculates %s %s for 1 %s",
            Useful.toStringScaled(underlyingAmountRecipe, underlyingDecimals),
            underlyingName,
            wrappedName
        );
        console.log(
            "Corrected for underlying decimals is %s %s for 1 %s",
            Useful.toStringScaled(underlyingAmount, underlyingDecimals),
            underlyingName,
            wrappedName
        );
        assertApproxEqAbs(underlyingAmountRecipe, exchangeRate, 10 ** (underlyingDecimals - 4), "exchange rate is out");
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

        uint256 thisApr = iLogic.getAPRFromWrapped(wrapped);
        assertEq(thisApr, iLogic.getAPRFromUnderlying(underlying), "underlying and wrapped have different APRs");
        assertEq(bestApr, thisApr, "thisAapr not the same as bestApr");

        console.log("apr=%s%%", Useful.toStringScaled(thisApr, 16)); // 10**(18-2)
        assertApproxEqAbs(thisApr, apr, 1e15, "apr doesn't match");
        //assertApproxEqAbs(iLogic.exchangeRate(wrapped), exchangeRate, 1e16, "exchangeRate doesn't match");
        //assertApproxEqAbs(iLogic.exchangeRateView(wrapped), exchangeRate, 1e16, "exchangeRateView doesn't match");
        assertApproxEqAbs(
            iLogic.exchangeRate(wrapped), iLogic.exchangeRateView(wrapped), 1e16, "exchangeRates don't match"
        );

        // test lending
        uint256 lendingAmount = underlyingAmount / 2;
        address[] memory targets;
        bytes[] memory data;
        (targets, data) = iLogic.lend(underlying, lendingAmount, wallet);
        assertEq(targets.length, data.length, "lend return arrays must be the same size");
        assertEq(targets[0], underlying, "approve on the underlying");
        assertEq(data[0].length, 68, "4bytes + two parameters = 68 bytes");

        (targets, data) = iLogic.unlend(wrapped, 100, wallet);
        assertEq(targets.length, data.length, "unlend return arrays must be the same size");
        assertEq(targets[0], wrapped, "unlend on the wrapped");
        assertEq(data[0].length, 36, "4bytes + one parameters = 36 bytes");
    }
}
