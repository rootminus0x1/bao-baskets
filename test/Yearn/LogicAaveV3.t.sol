// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.7.1;

// solhint-disable func-name-mixedcase
// solhint-disable no-console
import {console2 as console} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

import {IYToken, YStrategyParams, IYStrategy} from "src/Interfaces/IYToken.sol";
import {IEIP20} from "src/Interfaces/IEIP20.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";

import {LendingRegistry} from "src/LendingRegistry.sol";
import {LendingLogicAaveV2, ATokenV2} from "src/Strategies/LendingLogicAaveV2.sol";
import {ILendingLogic} from "src/Interfaces/ILendingLogic.sol";
import {LendingLogicAaveV3} from "src/Strategies/LendingLogicAaveV3.sol";

import "src/Interfaces/IAaveLendingPoolV2.sol";

import {DateUtils} from "DateUtils/DateUtils.sol";

import {Useful, Correlation} from "./Useful.sol";
import {ChainState, ChainFork, Roller} from "./ChainState.sol";
import {Deployed} from "test/Deployed.sol";
import {ChainStateLending} from "./ChainStateLending.sol";
import {TestLendingLogic} from "./TestLendingLogic.sol";
import {LendingManagerSimulator} from "./LendingManagerSimulator.sol";
import {TestData} from "./TestData.t.sol";

// fyi: AAVE V3 error codes: https://github.com/aave/aave-v3-core/blob/27a6d5c83560694210849d4abf09a09dec8da388/helpers/types.ts

abstract contract TestAaveLending is ChainStateLending {
    ILendingLogic lendingLogic;
    address underlying;
    address wrapped;
    string underlyingName;
    string wrappedName;
    address pool;
    address wallet;

    constructor(address _wrapped, uint64 version) {
        wrapped = _wrapped;
        underlying = ATokenV2(wrapped).UNDERLYING_ASSET_ADDRESS();
        underlyingName = IEIP20(underlying).symbol();
        wrappedName = IEIP20(wrapped).symbol();
        pool = wrapped;
        lendingLogic = (version == 3) ? new LendingLogicAaveV3() : ILendingLogic(Deployed.LENDINGLOGICAAVE);
        wallet = address(this);
    }

    function test_getApr() public view {
        uint256 apr = lendingLogic.getAPRFromWrapped(wrapped);
        console.log("apr for %s = %s%%", wrappedName, Useful.toStringScaled(apr, 18 - 2));
    }

    function test_lendDetails() public {
        uint256 amount = 100 * 1e18; // $100, no less

        // get some (more) dosh
        deal(underlying, wallet, amount * 2);
        uint256 startUnderlyingAmount = IERC20(underlying).balanceOf(wallet);
        uint256 startWrappedAmount = IERC20(wrapped).balanceOf(wallet);

        // the lend
        assertGe(IERC20(underlying).balanceOf(wallet), amount, "not enough underlying in wallet");
        uint256 startPoolBalance = IERC20(underlying).balanceOf(pool);

        LendingManagerSimulator.lend(lendingLogic, underlying, amount, wallet);
        //lend(amount);
        // TODO: check against the reported exchangeRate
        // these are the things that should have chhanged as a result of the lend
        // underlying allowance
        assertEq(
            IERC20(underlying).allowance(wallet, wrapped),
            0,
            Useful.concat("allowance should be back at 0 for underlying ", underlyingName)
        );
        // underlying transferred
        assertEq(
            IERC20(underlying).balanceOf(wallet),
            startUnderlyingAmount - amount,
            Useful.concat("incorrect amount left in wallet", underlyingName)
        );
        assertEq(
            IERC20(underlying).balanceOf(pool),
            amount + startPoolBalance,
            Useful.concat("the pool now has correct anmount of underlying ", underlyingName)
        );
        // wrapped transferred
        uint256 wrappedTransferred = IERC20(wrapped).balanceOf(wallet) - startWrappedAmount;
        assertApproxEqAbs(
            wrappedTransferred,
            startWrappedAmount + amount, // TODO: echange rate?
            1,
            "number of shares returned should be the same as the amount deposited"
        );

        // the unlend
        uint256 wrappedReturned1 = wrappedTransferred / 4;
        LendingManagerSimulator.unlend(lendingLogic, wrapped, wrappedReturned1, wallet);
        //unlend(wrappedReturned1);
        uint256 underlyingReturned1 = wrappedReturned1; // * exchange rate

        assertEq(
            IERC20(underlying).balanceOf(pool),
            startPoolBalance + amount - wrappedReturned1,
            Useful.concat("the pool should now have half the underlying remaining ", underlyingName)
        );
        assertEq(
            IERC20(underlying).balanceOf(wallet),
            startUnderlyingAmount - amount + underlyingReturned1,
            Useful.concat("wallet should now have the other half the underlying ", underlyingName)
        );
        assertApproxEqAbs(
            IERC20(wrapped).balanceOf(wallet),
            wrappedTransferred - wrappedReturned1,
            1,
            Useful.concat("shares should be transferred out of the wallet ", underlyingName)
        );

        // the second unlend
        uint256 wrappedReturned2 = wrappedTransferred - wrappedReturned1 - 1; // the rest - 1 for rounding error
        LendingManagerSimulator.unlend(lendingLogic, wrapped, wrappedReturned2, wallet);
        // unlend(wrappedReturned2);
        uint256 underlyingReturned2 = wrappedReturned2;

        assertApproxEqAbs(
            underlyingReturned1 + underlyingReturned2,
            amount,
            2, // 2 because there are 2 rounding error possibilities, one for each unlend
            Useful.concat("should have returned all the underlying ", underlyingName)
        );

        assertApproxEqAbs(
            IERC20(underlying).balanceOf(pool),
            startPoolBalance,
            2,
            Useful.concat("the pool should now have no remainining underlying ", underlyingName)
        );
        assertApproxEqAbs(
            IERC20(underlying).balanceOf(wallet),
            startUnderlyingAmount,
            2,
            Useful.concat("wallet should now have back all the underlying ", underlyingName)
        );
        assertApproxEqAbs(
            IERC20(wrapped).balanceOf(wallet),
            0,
            2, // rounding errors passed on (maybe)
            Useful.concat("all shares should be transferred out of the wallet ", underlyingName)
        );
    }
}

// as of Jul-23 fails because VL_RESERVE_FROZEN (see https://github.com/aave/protocol-v2/blob/ce53c4a8c8620125063168620eba0a8a92854eb8/helpers/types.ts#L128)
// contract TestAaveLendingARAI is TestAaveLending(Deployed.ARAI) {}

// as of Jul-23 fails because VL_RESERVE_FROZEN (see https://github.com/aave/protocol-v2/blob/ce53c4a8c8620125063168620eba0a8a92854eb8/helpers/types.ts#L128)
// contract TestAaveLendingAFEI is TestAaveLending(Deployed.AFEI) {}

contract TestAaveLendingAUSDC is TestAaveLending(Deployed.AUSDC, 1) {}

contract TestAaveLendingAFRAX is TestAaveLending(Deployed.AFRAX, 1) {}

// as of Jul-23 fails because VL_RESERVE_FROZEN (see https://github.com/aave/protocol-v2/blob/ce53c4a8c8620125063168620eba0a8a92854eb8/helpers/types.ts#L128)
// contract TestAaveLendingAYFI is TestAaveLending(Deployed.AYFI) {}

contract TestAaveLendingACRV is TestAaveLending(Deployed.ACRV, 1) {}

contract TestAaveLendingADAI is TestAaveLending(Deployed.ADAI, 1) {}

// fails due to sime security issue that foundry won't execute
// contract TestAaveLendingASUSD is TestAaveLending(Deployed.ASUSD) {}

// fails because SUPPLY_CAP_EXCEEDED
// contract TestAaveLendingAETHUSDC is
//    TestAaveLending(Deployed.AETHUSDC, address(new LendingLogicAaveV3(Deployed.AAVELENDINGPOOLV3, 0)))
// {}

contract TestAaveLendingV3 is TestAaveLending {
    constructor(address _wrapped) TestAaveLending(_wrapped, 3) {}
}

contract TestAaveLendingAETHFRAX is TestAaveLendingV3(Deployed.AETHFRAX) {}

contract TestAaveLendingAETHCRV is TestAaveLendingV3(Deployed.AETHCRV) {}

contract TestAaveLendingAETHDAI is TestAaveLendingV3(Deployed.AETHDAI) {}

contract TestAaveLendingAETHLUSD is TestAaveLendingV3(Deployed.AETHLUSD) {}

contract TestLogicAaveV3Backtest is ChainFork {
    struct TimeSeriesItem {
        string date;
        string value;
    }

    function test_historicalRates() public {
        //console.log("running historical rates test");
        vm.skip(!vm.envOr("BACKTESTS", false));

        TimeSeriesItem[212] memory timeSeries = [
            TimeSeriesItem({date: "2023-02-22 12:00:00", value: "0.00%"}),
            TimeSeriesItem({date: "2023-02-23 12:00:00", value: "0.16%"}),
            TimeSeriesItem({date: "2023-02-24 12:00:00", value: "2.72%"}),
            TimeSeriesItem({date: "2023-02-25 12:00:00", value: "0.34%"}),
            TimeSeriesItem({date: "2023-02-26 12:00:00", value: "1.53%"}),
            TimeSeriesItem({date: "2023-02-27 12:00:00", value: "0.16%"}),
            TimeSeriesItem({date: "2023-02-28 12:00:00", value: "1.70%"}),
            TimeSeriesItem({date: "2023-03-01 12:00:00", value: "0.51%"}),
            TimeSeriesItem({date: "2023-03-02 12:00:00", value: "2.68%"}),
            TimeSeriesItem({date: "2023-03-03 12:00:00", value: "0.90%"}),
            TimeSeriesItem({date: "2023-03-04 12:00:00", value: "4.14%"}),
            TimeSeriesItem({date: "2023-03-05 12:00:00", value: "0.88%"}),
            TimeSeriesItem({date: "2023-03-06 12:00:00", value: "1.97%"}),
            TimeSeriesItem({date: "2023-03-07 12:00:00", value: "1.32%"}),
            TimeSeriesItem({date: "2023-03-08 12:00:00", value: "0.00%"}),
            TimeSeriesItem({date: "2023-03-09 12:00:00", value: "4.05%"}),
            TimeSeriesItem({date: "2023-03-10 12:00:00", value: "1.36%"}),
            TimeSeriesItem({date: "2023-03-11 12:00:00", value: "24.48%"}),
            TimeSeriesItem({date: "2023-03-12 12:00:00", value: "10.71%"}),
            TimeSeriesItem({date: "2023-03-13 12:00:00", value: "10.72%"}),
            TimeSeriesItem({date: "2023-03-14 12:00:00", value: "1.95%"}),
            TimeSeriesItem({date: "2023-03-15 12:00:00", value: "0.67%"}),
            TimeSeriesItem({date: "2023-03-16 12:00:00", value: "0.59%"}),
            TimeSeriesItem({date: "2023-03-17 12:00:00", value: "0.52%"}),
            TimeSeriesItem({date: "2023-03-18 12:00:00", value: "0.73%"}),
            TimeSeriesItem({date: "2023-03-19 12:00:00", value: "0.83%"}),
            TimeSeriesItem({date: "2023-03-20 12:00:00", value: "0.84%"}),
            TimeSeriesItem({date: "2023-03-21 12:00:00", value: "1.13%"}),
            TimeSeriesItem({date: "2023-03-22 12:00:00", value: "4.22%"}),
            TimeSeriesItem({date: "2023-03-23 12:00:00", value: "0.81%"}),
            TimeSeriesItem({date: "2023-03-24 12:00:00", value: "0.99%"}),
            TimeSeriesItem({date: "2023-03-25 12:00:00", value: "1.91%"}),
            TimeSeriesItem({date: "2023-03-26 12:00:00", value: "1.20%"}),
            TimeSeriesItem({date: "2023-03-27 12:00:00", value: "0.87%"}),
            TimeSeriesItem({date: "2023-03-28 12:00:00", value: "0.57%"}),
            TimeSeriesItem({date: "2023-03-29 12:00:00", value: "1.52%"}),
            TimeSeriesItem({date: "2023-03-30 12:00:00", value: "0.88%"}),
            TimeSeriesItem({date: "2023-03-31 12:00:00", value: "0.41%"}),
            TimeSeriesItem({date: "2023-04-01 12:00:00", value: "1.82%"}),
            TimeSeriesItem({date: "2023-04-02 12:00:00", value: "0.55%"}),
            TimeSeriesItem({date: "2023-04-03 12:00:00", value: "0.70%"}),
            TimeSeriesItem({date: "2023-04-04 12:00:00", value: "0.50%"}),
            TimeSeriesItem({date: "2023-04-05 12:00:00", value: "0.85%"}),
            TimeSeriesItem({date: "2023-04-06 12:00:00", value: "4.14%"}),
            TimeSeriesItem({date: "2023-04-07 12:00:00", value: "0.90%"}),
            TimeSeriesItem({date: "2023-04-08 12:00:00", value: "0.69%"}),
            TimeSeriesItem({date: "2023-04-09 12:00:00", value: "1.48%"}),
            TimeSeriesItem({date: "2023-04-10 12:00:00", value: "2.92%"}),
            TimeSeriesItem({date: "2023-04-11 12:00:00", value: "0.94%"}),
            TimeSeriesItem({date: "2023-04-12 12:00:00", value: "0.88%"}),
            TimeSeriesItem({date: "2023-04-13 12:00:00", value: "0.95%"}),
            TimeSeriesItem({date: "2023-04-14 12:00:00", value: "3.87%"}),
            TimeSeriesItem({date: "2023-04-15 12:00:00", value: "1.41%"}),
            TimeSeriesItem({date: "2023-04-16 12:00:00", value: "1.22%"}),
            TimeSeriesItem({date: "2023-04-17 12:00:00", value: "1.42%"}),
            TimeSeriesItem({date: "2023-04-18 12:00:00", value: "0.73%"}),
            TimeSeriesItem({date: "2023-04-19 12:00:00", value: "0.67%"}),
            TimeSeriesItem({date: "2023-04-20 12:00:00", value: "1.54%"}),
            TimeSeriesItem({date: "2023-04-21 12:00:00", value: "1.59%"}),
            TimeSeriesItem({date: "2023-04-22 12:00:00", value: "0.35%"}),
            TimeSeriesItem({date: "2023-04-23 12:00:00", value: "1.32%"}),
            TimeSeriesItem({date: "2023-04-24 12:00:00", value: "0.22%"}),
            TimeSeriesItem({date: "2023-04-25 12:00:00", value: "0.90%"}),
            TimeSeriesItem({date: "2023-04-26 12:00:00", value: "4.16%"}),
            TimeSeriesItem({date: "2023-04-27 12:00:00", value: "1.15%"}),
            TimeSeriesItem({date: "2023-04-28 12:00:00", value: "0.64%"}),
            TimeSeriesItem({date: "2023-04-29 12:00:00", value: "0.27%"}),
            TimeSeriesItem({date: "2023-04-30 12:00:00", value: "2.43%"}),
            TimeSeriesItem({date: "2023-05-01 12:00:00", value: "1.00%"}),
            TimeSeriesItem({date: "2023-05-02 12:00:00", value: "1.37%"}),
            TimeSeriesItem({date: "2023-05-03 12:00:00", value: "0.98%"}),
            TimeSeriesItem({date: "2023-05-04 12:00:00", value: "8.75%"}),
            TimeSeriesItem({date: "2023-05-05 12:00:00", value: "0.47%"}),
            TimeSeriesItem({date: "2023-05-06 12:00:00", value: "3.03%"}),
            TimeSeriesItem({date: "2023-05-07 12:00:00", value: "3.88%"}),
            TimeSeriesItem({date: "2023-05-08 12:00:00", value: "3.15%"}),
            TimeSeriesItem({date: "2023-05-09 12:00:00", value: "3.02%"}),
            TimeSeriesItem({date: "2023-05-10 12:00:00", value: "0.36%"}),
            TimeSeriesItem({date: "2023-05-11 12:00:00", value: "3.11%"}),
            TimeSeriesItem({date: "2023-05-12 12:00:00", value: "1.94%"}),
            TimeSeriesItem({date: "2023-05-13 12:00:00", value: "0.98%"}),
            TimeSeriesItem({date: "2023-05-14 12:00:00", value: "1.47%"}),
            TimeSeriesItem({date: "2023-05-15 12:00:00", value: "1.78%"}),
            TimeSeriesItem({date: "2023-05-16 12:00:00", value: "0.84%"}),
            TimeSeriesItem({date: "2023-05-17 12:00:00", value: "0.86%"}),
            TimeSeriesItem({date: "2023-05-18 12:00:00", value: "1.65%"}),
            TimeSeriesItem({date: "2023-05-19 12:00:00", value: "1.30%"}),
            TimeSeriesItem({date: "2023-05-20 12:00:00", value: "0.39%"}),
            TimeSeriesItem({date: "2023-05-21 12:00:00", value: "1.56%"}),
            TimeSeriesItem({date: "2023-05-22 12:00:00", value: "0.95%"}),
            TimeSeriesItem({date: "2023-05-23 12:00:00", value: "0.01%"}),
            TimeSeriesItem({date: "2023-05-24 12:00:00", value: "2.62%"}),
            TimeSeriesItem({date: "2023-05-25 12:00:00", value: "1.02%"}),
            TimeSeriesItem({date: "2023-05-26 12:00:00", value: "0.76%"}),
            TimeSeriesItem({date: "2023-05-27 12:00:00", value: "0.31%"}),
            TimeSeriesItem({date: "2023-05-28 12:00:00", value: "0.31%"}),
            TimeSeriesItem({date: "2023-05-29 12:00:00", value: "3.00%"}),
            TimeSeriesItem({date: "2023-05-30 12:00:00", value: "0.79%"}),
            TimeSeriesItem({date: "2023-05-31 12:00:00", value: "2.29%"}),
            TimeSeriesItem({date: "2023-06-01 12:00:00", value: "1.07%"}),
            TimeSeriesItem({date: "2023-06-02 12:00:00", value: "2.61%"}),
            TimeSeriesItem({date: "2023-06-03 12:00:00", value: "1.04%"}),
            TimeSeriesItem({date: "2023-06-04 12:00:00", value: "1.39%"}),
            TimeSeriesItem({date: "2023-06-05 12:00:00", value: "1.17%"}),
            TimeSeriesItem({date: "2023-06-06 12:00:00", value: "1.55%"}),
            TimeSeriesItem({date: "2023-06-07 12:00:00", value: "1.61%"}),
            TimeSeriesItem({date: "2023-06-08 12:00:00", value: "1.18%"}),
            TimeSeriesItem({date: "2023-06-09 12:00:00", value: "0.71%"}),
            TimeSeriesItem({date: "2023-06-10 12:00:00", value: "2.25%"}),
            TimeSeriesItem({date: "2023-06-11 12:00:00", value: "0.97%"}),
            TimeSeriesItem({date: "2023-06-12 12:00:00", value: "0.92%"}),
            TimeSeriesItem({date: "2023-06-13 12:00:00", value: "1.09%"}),
            TimeSeriesItem({date: "2023-06-14 12:00:00", value: "2.01%"}),
            TimeSeriesItem({date: "2023-06-15 12:00:00", value: "3.79%"}),
            TimeSeriesItem({date: "2023-06-16 12:00:00", value: "1.77%"}),
            TimeSeriesItem({date: "2023-06-17 12:00:00", value: "1.48%"}),
            TimeSeriesItem({date: "2023-06-18 12:00:00", value: "3.73%"}),
            TimeSeriesItem({date: "2023-06-19 12:00:00", value: "1.05%"}),
            TimeSeriesItem({date: "2023-06-20 12:00:00", value: "3.06%"}),
            TimeSeriesItem({date: "2023-06-21 12:00:00", value: "1.75%"}),
            TimeSeriesItem({date: "2023-06-22 12:00:00", value: "0.53%"}),
            TimeSeriesItem({date: "2023-06-23 12:00:00", value: "2.23%"}),
            TimeSeriesItem({date: "2023-06-24 12:00:00", value: "0.00%"}),
            TimeSeriesItem({date: "2023-06-25 12:00:00", value: "3.96%"}),
            TimeSeriesItem({date: "2023-06-26 12:00:00", value: "1.63%"}),
            TimeSeriesItem({date: "2023-06-27 12:00:00", value: "2.03%"}),
            TimeSeriesItem({date: "2023-06-28 12:00:00", value: "0.72%"}),
            TimeSeriesItem({date: "2023-06-29 12:00:00", value: "1.66%"}),
            TimeSeriesItem({date: "2023-06-30 12:00:00", value: "0.45%"}),
            TimeSeriesItem({date: "2023-07-01 12:00:00", value: "1.88%"}),
            TimeSeriesItem({date: "2023-07-02 12:00:00", value: "3.95%"}),
            TimeSeriesItem({date: "2023-07-03 12:00:00", value: "1.75%"}),
            TimeSeriesItem({date: "2023-07-04 12:00:00", value: "1.75%"}),
            TimeSeriesItem({date: "2023-07-05 12:00:00", value: "0.00%"}),
            TimeSeriesItem({date: "2023-07-06 12:00:00", value: "1.28%"}),
            TimeSeriesItem({date: "2023-07-07 12:00:00", value: "3.83%"}),
            TimeSeriesItem({date: "2023-07-08 12:00:00", value: "2.61%"}),
            TimeSeriesItem({date: "2023-07-09 12:00:00", value: "1.80%"}),
            TimeSeriesItem({date: "2023-07-10 12:00:00", value: "3.20%"}),
            TimeSeriesItem({date: "2023-07-11 12:00:00", value: "2.16%"}),
            TimeSeriesItem({date: "2023-07-12 12:00:00", value: "0.08%"}),
            TimeSeriesItem({date: "2023-07-13 12:00:00", value: "3.12%"}),
            TimeSeriesItem({date: "2023-07-14 12:00:00", value: "2.54%"}),
            TimeSeriesItem({date: "2023-07-15 12:00:00", value: "2.34%"}),
            TimeSeriesItem({date: "2023-07-16 12:00:00", value: "2.05%"}),
            TimeSeriesItem({date: "2023-07-17 12:00:00", value: "3.08%"}),
            TimeSeriesItem({date: "2023-07-18 12:00:00", value: "1.51%"}),
            TimeSeriesItem({date: "2023-07-19 12:00:00", value: "0.87%"}),
            TimeSeriesItem({date: "2023-07-20 12:00:00", value: "1.02%"}),
            TimeSeriesItem({date: "2023-07-21 12:00:00", value: "2.70%"}),
            TimeSeriesItem({date: "2023-07-22 12:00:00", value: "11.82%"}),
            TimeSeriesItem({date: "2023-07-23 12:00:00", value: "12.34%"}),
            TimeSeriesItem({date: "2023-07-24 12:00:00", value: "1.86%"}),
            TimeSeriesItem({date: "2023-07-25 12:00:00", value: "0.90%"}),
            TimeSeriesItem({date: "2023-07-26 12:00:00", value: "4.25%"}),
            TimeSeriesItem({date: "2023-07-27 12:00:00", value: "1.98%"}),
            TimeSeriesItem({date: "2023-07-28 12:00:00", value: "1.85%"}),
            TimeSeriesItem({date: "2023-07-29 12:00:00", value: "2.53%"}),
            TimeSeriesItem({date: "2023-07-30 12:00:00", value: "4.93%"}),
            TimeSeriesItem({date: "2023-07-31 12:00:00", value: "8.64%"}),
            TimeSeriesItem({date: "2023-08-01 12:00:00", value: "3.98%"}),
            TimeSeriesItem({date: "2023-08-02 12:00:00", value: "2.18%"}),
            TimeSeriesItem({date: "2023-08-03 12:00:00", value: "5.78%"}),
            TimeSeriesItem({date: "2023-08-04 12:00:00", value: "0.87%"}),
            TimeSeriesItem({date: "2023-08-05 12:00:00", value: "2.81%"}),
            TimeSeriesItem({date: "2023-08-06 12:00:00", value: "3.41%"}),
            TimeSeriesItem({date: "2023-08-07 12:00:00", value: "1.80%"}),
            TimeSeriesItem({date: "2023-08-08 12:00:00", value: "3.27%"}),
            TimeSeriesItem({date: "2023-08-09 12:00:00", value: "2.61%"}),
            TimeSeriesItem({date: "2023-08-10 12:00:00", value: "1.38%"}),
            TimeSeriesItem({date: "2023-08-11 12:00:00", value: "4.02%"}),
            TimeSeriesItem({date: "2023-08-12 12:00:00", value: "1.78%"}),
            TimeSeriesItem({date: "2023-08-13 12:00:00", value: "2.48%"}),
            TimeSeriesItem({date: "2023-08-14 12:00:00", value: "1.83%"}),
            TimeSeriesItem({date: "2023-08-15 12:00:00", value: "2.30%"}),
            TimeSeriesItem({date: "2023-08-16 12:00:00", value: "1.35%"}),
            TimeSeriesItem({date: "2023-08-17 12:00:00", value: "1.53%"}),
            TimeSeriesItem({date: "2023-08-18 12:00:00", value: "0.73%"}),
            TimeSeriesItem({date: "2023-08-19 12:00:00", value: "1.67%"}),
            TimeSeriesItem({date: "2023-08-20 12:00:00", value: "0.36%"}),
            TimeSeriesItem({date: "2023-08-21 12:00:00", value: "4.91%"}),
            TimeSeriesItem({date: "2023-08-22 12:00:00", value: "3.17%"}),
            TimeSeriesItem({date: "2023-08-23 12:00:00", value: "2.36%"}),
            TimeSeriesItem({date: "2023-08-24 12:00:00", value: "0.48%"}),
            TimeSeriesItem({date: "2023-08-25 12:00:00", value: "2.41%"}),
            TimeSeriesItem({date: "2023-08-26 12:00:00", value: "1.92%"}),
            TimeSeriesItem({date: "2023-08-27 12:00:00", value: "4.12%"}),
            TimeSeriesItem({date: "2023-08-28 12:00:00", value: "2.72%"}),
            TimeSeriesItem({date: "2023-08-29 12:00:00", value: "0.90%"}),
            TimeSeriesItem({date: "2023-08-30 12:00:00", value: "2.13%"}),
            TimeSeriesItem({date: "2023-08-31 12:00:00", value: "4.34%"}),
            TimeSeriesItem({date: "2023-09-01 12:00:00", value: "4.41%"}),
            TimeSeriesItem({date: "2023-09-02 12:00:00", value: "3.14%"}),
            TimeSeriesItem({date: "2023-09-03 12:00:00", value: "8.17%"}),
            TimeSeriesItem({date: "2023-09-04 12:00:00", value: "2.34%"}),
            TimeSeriesItem({date: "2023-09-05 12:00:00", value: "2.19%"}),
            TimeSeriesItem({date: "2023-09-06 12:00:00", value: "3.85%"}),
            TimeSeriesItem({date: "2023-09-07 12:00:00", value: "2.84%"}),
            TimeSeriesItem({date: "2023-09-08 12:00:00", value: "2.32%"}),
            TimeSeriesItem({date: "2023-09-09 12:00:00", value: "2.19%"}),
            TimeSeriesItem({date: "2023-09-10 12:00:00", value: "0.73%"}),
            TimeSeriesItem({date: "2023-09-11 12:00:00", value: "0.00%"}),
            TimeSeriesItem({date: "2023-09-12 12:00:00", value: "4.80%"}),
            TimeSeriesItem({date: "2023-09-13 12:00:00", value: "4.05%"}),
            TimeSeriesItem({date: "2023-09-14 12:00:00", value: "0.55%"}),
            TimeSeriesItem({date: "2023-09-15 12:00:00", value: "4.80%"}),
            TimeSeriesItem({date: "2023-09-16 12:00:00", value: "2.20%"}),
            TimeSeriesItem({date: "2023-09-17 12:00:00", value: "1.31%"}),
            TimeSeriesItem({date: "2023-09-18 12:00:00", value: "2.01%"}),
            TimeSeriesItem({date: "2023-09-19 12:00:00", value: "0.67%"}),
            TimeSeriesItem({date: "2023-09-20 12:00:00", value: "2.52%"}),
            TimeSeriesItem({date: "2023-09-21 12:00:00", value: "1.94%"})
        ];
        // block 18200000 is a couple of days beyond that
        // string memory url = vm.envString("MAINNET_RPC_URL");
        // console.log("MAINNET_RPC_URL=%s", url);

        /*
        uint256 maxTimestamp = 0;
        uint256 minTimestamp = type(uint256).max;
        //console.log("minTS =%d", minTimestamp);
        uint256[] memory timestamps = new uint256[](timeSeries.length);
        for (uint256 i = 0; i < timeSeries.length; i++) {
            uint256 ts = DateUtils.convertDateTimeStringToTimestamp(timeSeries[i].date);
            if (ts > maxTimestamp) maxTimestamp = ts;
            if (ts < minTimestamp) minTimestamp = ts;
            //console.log("minTS =%d, %d", minTimestamp, ts);
            timestamps[i] = ts;
        }
        */

        Roller.UpperBound memory ubound = Roller.UpperBound(block.number, block.timestamp);
        //console.log("lastBlock=%d", lastBlock);
        //console.log("maxTS =%d", maxTimestamp);
        //console.log("minTS =%d", minTimestamp);
        //console.log("lastTS=%d", lastTimestamp);

        console.log("Block, Roll count, Date, AAVe web, Bao logic");

        Correlation.Accumulator memory acc;

        uint256 base = vm.snapshot();

        // Roller.rollForkToBlockContaining(vm, minTimestamp, lastBlock, lastTimestamp);
        // LendingLogicAaveV3 baseLendingLogic = new LendingLogicAaveV3();
        // vm.makePersistent(address(baseLendingLogic));

        for (uint256 i = 0; i < timeSeries.length; i++) {
            //uint256 fork = vm.createFork(url);
            //vm.selectFork(fork);
            if (i > 0) vm.revertTo(base);

            uint256 ts = DateUtils.convertDateTimeStringToTimestamp(timeSeries[i].date);
            uint256 rollCount = Roller.rollForkToBlockContaining(vm, ts, ubound);

            LendingLogicAaveV3 newLendingLogic = new LendingLogicAaveV3();
            uint256 calculatedApr = newLendingLogic.getAPRFromWrapped(Deployed.AETHLUSD);

            acc = Correlation.addXY(acc, calculatedApr, Useful.toUint256(timeSeries[i].value, 18));

            console.log(
                "%d, %d, %s",
                block.number,
                rollCount,
                Useful.concat(
                    timeSeries[i].date,
                    ", ",
                    timeSeries[i].value,
                    ", ",
                    Useful.toStringScaled(calculatedApr, 18 - 2),
                    "%"
                )
            );
        }
        uint256 correlation = Correlation.pearsonCorrelation(acc);
        console.log("correlation=%s", Useful.toStringScaled(correlation, 18));
        assertGt(correlation, 8 * 1e17, "nearly good correlation");
    }
}
