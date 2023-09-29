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
        uint256 blockNumber;
        string date;
        string value;
    }

    function test_historicalRates() public {
        //console.log("running historical rates test");
        vm.skip(!vm.envOr("BACKTESTS", false));
        TimeSeriesItem[212] memory timeSeries = [
            TimeSeriesItem({blockNumber: 16683843, date: "2023-02-22 12:00:00", value: "0.00%"}),
            TimeSeriesItem({blockNumber: 16690956, date: "2023-02-23 12:00:00", value: "0.16%"}),
            TimeSeriesItem({blockNumber: 16698053, date: "2023-02-24 12:00:00", value: "2.72%"}),
            TimeSeriesItem({blockNumber: 16705156, date: "2023-02-25 12:00:00", value: "0.34%"}),
            TimeSeriesItem({blockNumber: 16712271, date: "2023-02-26 12:00:00", value: "1.53%"}),
            TimeSeriesItem({blockNumber: 16719386, date: "2023-02-27 12:00:00", value: "0.16%"}),
            TimeSeriesItem({blockNumber: 16726518, date: "2023-02-28 12:00:00", value: "1.70%"}),
            TimeSeriesItem({blockNumber: 16733631, date: "2023-03-01 12:00:00", value: "0.51%"}),
            TimeSeriesItem({blockNumber: 16740742, date: "2023-03-02 12:00:00", value: "2.68%"}),
            TimeSeriesItem({blockNumber: 16747844, date: "2023-03-03 12:00:00", value: "0.90%"}),
            TimeSeriesItem({blockNumber: 16754936, date: "2023-03-04 12:00:00", value: "4.14%"}),
            TimeSeriesItem({blockNumber: 16762057, date: "2023-03-05 12:00:00", value: "0.88%"}),
            TimeSeriesItem({blockNumber: 16769172, date: "2023-03-06 12:00:00", value: "1.97%"}),
            TimeSeriesItem({blockNumber: 16776283, date: "2023-03-07 12:00:00", value: "1.32%"}),
            TimeSeriesItem({blockNumber: 16783395, date: "2023-03-08 12:00:00", value: "0.00%"}),
            TimeSeriesItem({blockNumber: 16790510, date: "2023-03-09 12:00:00", value: "4.05%"}),
            TimeSeriesItem({blockNumber: 16797588, date: "2023-03-10 12:00:00", value: "1.36%"}),
            TimeSeriesItem({blockNumber: 16804701, date: "2023-03-11 12:00:00", value: "24.48%"}),
            TimeSeriesItem({blockNumber: 16811806, date: "2023-03-12 12:00:00", value: "10.71%"}),
            TimeSeriesItem({blockNumber: 16818931, date: "2023-03-13 12:00:00", value: "10.72%"}),
            TimeSeriesItem({blockNumber: 16826047, date: "2023-03-14 12:00:00", value: "1.95%"}),
            TimeSeriesItem({blockNumber: 16833155, date: "2023-03-15 12:00:00", value: "0.67%"}),
            TimeSeriesItem({blockNumber: 16840269, date: "2023-03-16 12:00:00", value: "0.59%"}),
            TimeSeriesItem({blockNumber: 16847394, date: "2023-03-17 12:00:00", value: "0.52%"}),
            TimeSeriesItem({blockNumber: 16854499, date: "2023-03-18 12:00:00", value: "0.73%"}),
            TimeSeriesItem({blockNumber: 16861629, date: "2023-03-19 12:00:00", value: "0.83%"}),
            TimeSeriesItem({blockNumber: 16868744, date: "2023-03-20 12:00:00", value: "0.84%"}),
            TimeSeriesItem({blockNumber: 16875874, date: "2023-03-21 12:00:00", value: "1.13%"}),
            TimeSeriesItem({blockNumber: 16882993, date: "2023-03-22 12:00:00", value: "4.22%"}),
            TimeSeriesItem({blockNumber: 16890100, date: "2023-03-23 12:00:00", value: "0.81%"}),
            TimeSeriesItem({blockNumber: 16897222, date: "2023-03-24 12:00:00", value: "0.99%"}),
            TimeSeriesItem({blockNumber: 16904339, date: "2023-03-25 12:00:00", value: "1.91%"}),
            TimeSeriesItem({blockNumber: 16911462, date: "2023-03-26 12:00:00", value: "1.20%"}),
            TimeSeriesItem({blockNumber: 16918577, date: "2023-03-27 12:00:00", value: "0.87%"}),
            TimeSeriesItem({blockNumber: 16925693, date: "2023-03-28 12:00:00", value: "0.57%"}),
            TimeSeriesItem({blockNumber: 16932810, date: "2023-03-29 12:00:00", value: "1.52%"}),
            TimeSeriesItem({blockNumber: 16939925, date: "2023-03-30 12:00:00", value: "0.88%"}),
            TimeSeriesItem({blockNumber: 16947044, date: "2023-03-31 12:00:00", value: "0.41%"}),
            TimeSeriesItem({blockNumber: 16954160, date: "2023-04-01 12:00:00", value: "1.82%"}),
            TimeSeriesItem({blockNumber: 16961268, date: "2023-04-02 12:00:00", value: "0.55%"}),
            TimeSeriesItem({blockNumber: 16968355, date: "2023-04-03 12:00:00", value: "0.70%"}),
            TimeSeriesItem({blockNumber: 16975387, date: "2023-04-04 12:00:00", value: "0.50%"}),
            TimeSeriesItem({blockNumber: 16982440, date: "2023-04-05 12:00:00", value: "0.85%"}),
            TimeSeriesItem({blockNumber: 16989432, date: "2023-04-06 12:00:00", value: "4.14%"}),
            TimeSeriesItem({blockNumber: 16996473, date: "2023-04-07 12:00:00", value: "0.90%"}),
            TimeSeriesItem({blockNumber: 17003543, date: "2023-04-08 12:00:00", value: "0.69%"}),
            TimeSeriesItem({blockNumber: 17010603, date: "2023-04-09 12:00:00", value: "1.48%"}),
            TimeSeriesItem({blockNumber: 17017660, date: "2023-04-10 12:00:00", value: "2.92%"}),
            TimeSeriesItem({blockNumber: 17024717, date: "2023-04-11 12:00:00", value: "0.94%"}),
            TimeSeriesItem({blockNumber: 17031792, date: "2023-04-12 12:00:00", value: "0.88%"}),
            TimeSeriesItem({blockNumber: 17038416, date: "2023-04-13 12:00:00", value: "0.95%"}),
            TimeSeriesItem({blockNumber: 17045278, date: "2023-04-14 12:00:00", value: "3.87%"}),
            TimeSeriesItem({blockNumber: 17052272, date: "2023-04-15 12:00:00", value: "1.41%"}),
            TimeSeriesItem({blockNumber: 17059310, date: "2023-04-16 12:00:00", value: "1.22%"}),
            TimeSeriesItem({blockNumber: 17066357, date: "2023-04-17 12:00:00", value: "1.42%"}),
            TimeSeriesItem({blockNumber: 17073427, date: "2023-04-18 12:00:00", value: "0.73%"}),
            TimeSeriesItem({blockNumber: 17080510, date: "2023-04-19 12:00:00", value: "0.67%"}),
            TimeSeriesItem({blockNumber: 17087568, date: "2023-04-20 12:00:00", value: "1.54%"}),
            TimeSeriesItem({blockNumber: 17094626, date: "2023-04-21 12:00:00", value: "1.59%"}),
            TimeSeriesItem({blockNumber: 17101744, date: "2023-04-22 12:00:00", value: "0.35%"}),
            TimeSeriesItem({blockNumber: 17108872, date: "2023-04-23 12:00:00", value: "1.32%"}),
            TimeSeriesItem({blockNumber: 17116006, date: "2023-04-24 12:00:00", value: "0.22%"}),
            TimeSeriesItem({blockNumber: 17123134, date: "2023-04-25 12:00:00", value: "0.90%"}),
            TimeSeriesItem({blockNumber: 17130259, date: "2023-04-26 12:00:00", value: "4.16%"}),
            TimeSeriesItem({blockNumber: 17137372, date: "2023-04-27 12:00:00", value: "1.15%"}),
            TimeSeriesItem({blockNumber: 17144484, date: "2023-04-28 12:00:00", value: "0.64%"}),
            TimeSeriesItem({blockNumber: 17151617, date: "2023-04-29 12:00:00", value: "0.27%"}),
            TimeSeriesItem({blockNumber: 17158722, date: "2023-04-30 12:00:00", value: "2.43%"}),
            TimeSeriesItem({blockNumber: 17165839, date: "2023-05-01 12:00:00", value: "1.00%"}),
            TimeSeriesItem({blockNumber: 17172951, date: "2023-05-02 12:00:00", value: "1.37%"}),
            TimeSeriesItem({blockNumber: 17180054, date: "2023-05-03 12:00:00", value: "0.98%"}),
            TimeSeriesItem({blockNumber: 17187167, date: "2023-05-04 12:00:00", value: "8.75%"}),
            TimeSeriesItem({blockNumber: 17194292, date: "2023-05-05 12:00:00", value: "0.47%"}),
            TimeSeriesItem({blockNumber: 17201411, date: "2023-05-06 12:00:00", value: "3.03%"}),
            TimeSeriesItem({blockNumber: 17208524, date: "2023-05-07 12:00:00", value: "3.88%"}),
            TimeSeriesItem({blockNumber: 17215636, date: "2023-05-08 12:00:00", value: "3.15%"}),
            TimeSeriesItem({blockNumber: 17222752, date: "2023-05-09 12:00:00", value: "3.02%"}),
            TimeSeriesItem({blockNumber: 17229867, date: "2023-05-10 12:00:00", value: "0.36%"}),
            TimeSeriesItem({blockNumber: 17236972, date: "2023-05-11 12:00:00", value: "3.11%"}),
            TimeSeriesItem({blockNumber: 17243990, date: "2023-05-12 12:00:00", value: "1.94%"}),
            TimeSeriesItem({blockNumber: 17250915, date: "2023-05-13 12:00:00", value: "0.98%"}),
            TimeSeriesItem({blockNumber: 17257963, date: "2023-05-14 12:00:00", value: "1.47%"}),
            TimeSeriesItem({blockNumber: 17265042, date: "2023-05-15 12:00:00", value: "1.78%"}),
            TimeSeriesItem({blockNumber: 17272128, date: "2023-05-16 12:00:00", value: "0.84%"}),
            TimeSeriesItem({blockNumber: 17279217, date: "2023-05-17 12:00:00", value: "0.86%"}),
            TimeSeriesItem({blockNumber: 17286293, date: "2023-05-18 12:00:00", value: "1.65%"}),
            TimeSeriesItem({blockNumber: 17293399, date: "2023-05-19 12:00:00", value: "1.30%"}),
            TimeSeriesItem({blockNumber: 17300504, date: "2023-05-20 12:00:00", value: "0.39%"}),
            TimeSeriesItem({blockNumber: 17307604, date: "2023-05-21 12:00:00", value: "1.56%"}),
            TimeSeriesItem({blockNumber: 17314696, date: "2023-05-22 12:00:00", value: "0.95%"}),
            TimeSeriesItem({blockNumber: 17321795, date: "2023-05-23 12:00:00", value: "0.01%"}),
            TimeSeriesItem({blockNumber: 17328904, date: "2023-05-24 12:00:00", value: "2.62%"}),
            TimeSeriesItem({blockNumber: 17336020, date: "2023-05-25 12:00:00", value: "1.02%"}),
            TimeSeriesItem({blockNumber: 17343132, date: "2023-05-26 12:00:00", value: "0.76%"}),
            TimeSeriesItem({blockNumber: 17350246, date: "2023-05-27 12:00:00", value: "0.31%"}),
            TimeSeriesItem({blockNumber: 17357379, date: "2023-05-28 12:00:00", value: "0.31%"}),
            TimeSeriesItem({blockNumber: 17364504, date: "2023-05-29 12:00:00", value: "3.00%"}),
            TimeSeriesItem({blockNumber: 17371603, date: "2023-05-30 12:00:00", value: "0.79%"}),
            TimeSeriesItem({blockNumber: 17378717, date: "2023-05-31 12:00:00", value: "2.29%"}),
            TimeSeriesItem({blockNumber: 17385819, date: "2023-06-01 12:00:00", value: "1.07%"}),
            TimeSeriesItem({blockNumber: 17392911, date: "2023-06-02 12:00:00", value: "2.61%"}),
            TimeSeriesItem({blockNumber: 17400017, date: "2023-06-03 12:00:00", value: "1.04%"}),
            TimeSeriesItem({blockNumber: 17407103, date: "2023-06-04 12:00:00", value: "1.39%"}),
            TimeSeriesItem({blockNumber: 17414181, date: "2023-06-05 12:00:00", value: "1.17%"}),
            TimeSeriesItem({blockNumber: 17421269, date: "2023-06-06 12:00:00", value: "1.55%"}),
            TimeSeriesItem({blockNumber: 17428357, date: "2023-06-07 12:00:00", value: "1.61%"}),
            TimeSeriesItem({blockNumber: 17435453, date: "2023-06-08 12:00:00", value: "1.18%"}),
            TimeSeriesItem({blockNumber: 17442534, date: "2023-06-09 12:00:00", value: "0.71%"}),
            TimeSeriesItem({blockNumber: 17449632, date: "2023-06-10 12:00:00", value: "2.25%"}),
            TimeSeriesItem({blockNumber: 17456734, date: "2023-06-11 12:00:00", value: "0.97%"}),
            TimeSeriesItem({blockNumber: 17463839, date: "2023-06-12 12:00:00", value: "0.92%"}),
            TimeSeriesItem({blockNumber: 17470934, date: "2023-06-13 12:00:00", value: "1.09%"}),
            TimeSeriesItem({blockNumber: 17478039, date: "2023-06-14 12:00:00", value: "2.01%"}),
            TimeSeriesItem({blockNumber: 17485140, date: "2023-06-15 12:00:00", value: "3.79%"}),
            TimeSeriesItem({blockNumber: 17492257, date: "2023-06-16 12:00:00", value: "1.77%"}),
            TimeSeriesItem({blockNumber: 17499387, date: "2023-06-17 12:00:00", value: "1.48%"}),
            TimeSeriesItem({blockNumber: 17506523, date: "2023-06-18 12:00:00", value: "3.73%"}),
            TimeSeriesItem({blockNumber: 17513655, date: "2023-06-19 12:00:00", value: "1.05%"}),
            TimeSeriesItem({blockNumber: 17520768, date: "2023-06-20 12:00:00", value: "3.06%"}),
            TimeSeriesItem({blockNumber: 17527896, date: "2023-06-21 12:00:00", value: "1.75%"}),
            TimeSeriesItem({blockNumber: 17535017, date: "2023-06-22 12:00:00", value: "0.53%"}),
            TimeSeriesItem({blockNumber: 17542125, date: "2023-06-23 12:00:00", value: "2.23%"}),
            TimeSeriesItem({blockNumber: 17549241, date: "2023-06-24 12:00:00", value: "0.00%"}),
            TimeSeriesItem({blockNumber: 17556354, date: "2023-06-25 12:00:00", value: "3.96%"}),
            TimeSeriesItem({blockNumber: 17563459, date: "2023-06-26 12:00:00", value: "1.63%"}),
            TimeSeriesItem({blockNumber: 17570555, date: "2023-06-27 12:00:00", value: "2.03%"}),
            TimeSeriesItem({blockNumber: 17577676, date: "2023-06-28 12:00:00", value: "0.72%"}),
            TimeSeriesItem({blockNumber: 17584815, date: "2023-06-29 12:00:00", value: "1.66%"}),
            TimeSeriesItem({blockNumber: 17591953, date: "2023-06-30 12:00:00", value: "0.45%"}),
            TimeSeriesItem({blockNumber: 17599065, date: "2023-07-01 12:00:00", value: "1.88%"}),
            TimeSeriesItem({blockNumber: 17606183, date: "2023-07-02 12:00:00", value: "3.95%"}),
            TimeSeriesItem({blockNumber: 17613303, date: "2023-07-03 12:00:00", value: "1.75%"}),
            TimeSeriesItem({blockNumber: 17620421, date: "2023-07-04 12:00:00", value: "1.75%"}),
            TimeSeriesItem({blockNumber: 17627540, date: "2023-07-05 12:00:00", value: "0.00%"}),
            TimeSeriesItem({blockNumber: 17634666, date: "2023-07-06 12:00:00", value: "1.28%"}),
            TimeSeriesItem({blockNumber: 17641784, date: "2023-07-07 12:00:00", value: "3.83%"}),
            TimeSeriesItem({blockNumber: 17648902, date: "2023-07-08 12:00:00", value: "2.61%"}),
            TimeSeriesItem({blockNumber: 17656008, date: "2023-07-09 12:00:00", value: "1.80%"}),
            TimeSeriesItem({blockNumber: 17663120, date: "2023-07-10 12:00:00", value: "3.20%"}),
            TimeSeriesItem({blockNumber: 17670229, date: "2023-07-11 12:00:00", value: "2.16%"}),
            TimeSeriesItem({blockNumber: 17677341, date: "2023-07-12 12:00:00", value: "0.08%"}),
            TimeSeriesItem({blockNumber: 17684439, date: "2023-07-13 12:00:00", value: "3.12%"}),
            TimeSeriesItem({blockNumber: 17691560, date: "2023-07-14 12:00:00", value: "2.54%"}),
            TimeSeriesItem({blockNumber: 17698645, date: "2023-07-15 12:00:00", value: "2.34%"}),
            TimeSeriesItem({blockNumber: 17705709, date: "2023-07-16 12:00:00", value: "2.05%"}),
            TimeSeriesItem({blockNumber: 17712839, date: "2023-07-17 12:00:00", value: "3.08%"}),
            TimeSeriesItem({blockNumber: 17719978, date: "2023-07-18 12:00:00", value: "1.51%"}),
            TimeSeriesItem({blockNumber: 17727093, date: "2023-07-19 12:00:00", value: "0.87%"}),
            TimeSeriesItem({blockNumber: 17734235, date: "2023-07-20 12:00:00", value: "1.02%"}),
            TimeSeriesItem({blockNumber: 17741375, date: "2023-07-21 12:00:00", value: "2.70%"}),
            TimeSeriesItem({blockNumber: 17748529, date: "2023-07-22 12:00:00", value: "11.82%"}),
            TimeSeriesItem({blockNumber: 17755676, date: "2023-07-23 12:00:00", value: "12.34%"}),
            TimeSeriesItem({blockNumber: 17762822, date: "2023-07-24 12:00:00", value: "1.86%"}),
            TimeSeriesItem({blockNumber: 17769968, date: "2023-07-25 12:00:00", value: "0.90%"}),
            TimeSeriesItem({blockNumber: 17777112, date: "2023-07-26 12:00:00", value: "4.25%"}),
            TimeSeriesItem({blockNumber: 17784258, date: "2023-07-27 12:00:00", value: "1.98%"}),
            TimeSeriesItem({blockNumber: 17791417, date: "2023-07-28 12:00:00", value: "1.85%"}),
            TimeSeriesItem({blockNumber: 17798553, date: "2023-07-29 12:00:00", value: "2.53%"}),
            TimeSeriesItem({blockNumber: 17805708, date: "2023-07-30 12:00:00", value: "4.93%"}),
            TimeSeriesItem({blockNumber: 17812849, date: "2023-07-31 12:00:00", value: "8.64%"}),
            TimeSeriesItem({blockNumber: 17820011, date: "2023-08-01 12:00:00", value: "3.98%"}),
            TimeSeriesItem({blockNumber: 17827171, date: "2023-08-02 12:00:00", value: "2.18%"}),
            TimeSeriesItem({blockNumber: 17834330, date: "2023-08-03 12:00:00", value: "5.78%"}),
            TimeSeriesItem({blockNumber: 17841479, date: "2023-08-04 12:00:00", value: "0.87%"}),
            TimeSeriesItem({blockNumber: 17848625, date: "2023-08-05 12:00:00", value: "2.81%"}),
            TimeSeriesItem({blockNumber: 17855776, date: "2023-08-06 12:00:00", value: "3.41%"}),
            TimeSeriesItem({blockNumber: 17862918, date: "2023-08-07 12:00:00", value: "1.80%"}),
            TimeSeriesItem({blockNumber: 17870062, date: "2023-08-08 12:00:00", value: "3.27%"}),
            TimeSeriesItem({blockNumber: 17877206, date: "2023-08-09 12:00:00", value: "2.61%"}),
            TimeSeriesItem({blockNumber: 17884343, date: "2023-08-10 12:00:00", value: "1.38%"}),
            TimeSeriesItem({blockNumber: 17891503, date: "2023-08-11 12:00:00", value: "4.02%"}),
            TimeSeriesItem({blockNumber: 17898638, date: "2023-08-12 12:00:00", value: "1.78%"}),
            TimeSeriesItem({blockNumber: 17905797, date: "2023-08-13 12:00:00", value: "2.48%"}),
            TimeSeriesItem({blockNumber: 17912944, date: "2023-08-14 12:00:00", value: "1.83%"}),
            TimeSeriesItem({blockNumber: 17920101, date: "2023-08-15 12:00:00", value: "2.30%"}),
            TimeSeriesItem({blockNumber: 17927250, date: "2023-08-16 12:00:00", value: "1.35%"}),
            TimeSeriesItem({blockNumber: 17934398, date: "2023-08-17 12:00:00", value: "1.53%"}),
            TimeSeriesItem({blockNumber: 17941531, date: "2023-08-18 12:00:00", value: "0.73%"}),
            TimeSeriesItem({blockNumber: 17948681, date: "2023-08-19 12:00:00", value: "1.67%"}),
            TimeSeriesItem({blockNumber: 17955815, date: "2023-08-20 12:00:00", value: "0.36%"}),
            TimeSeriesItem({blockNumber: 17962967, date: "2023-08-21 12:00:00", value: "4.91%"}),
            TimeSeriesItem({blockNumber: 17970114, date: "2023-08-22 12:00:00", value: "3.17%"}),
            TimeSeriesItem({blockNumber: 17977266, date: "2023-08-23 12:00:00", value: "2.36%"}),
            TimeSeriesItem({blockNumber: 17984420, date: "2023-08-24 12:00:00", value: "0.48%"}),
            TimeSeriesItem({blockNumber: 17991568, date: "2023-08-25 12:00:00", value: "2.41%"}),
            TimeSeriesItem({blockNumber: 17998700, date: "2023-08-26 12:00:00", value: "1.92%"}),
            TimeSeriesItem({blockNumber: 18005862, date: "2023-08-27 12:00:00", value: "4.12%"}),
            TimeSeriesItem({blockNumber: 18013004, date: "2023-08-28 12:00:00", value: "2.72%"}),
            TimeSeriesItem({blockNumber: 18020134, date: "2023-08-29 12:00:00", value: "0.90%"}),
            TimeSeriesItem({blockNumber: 18027274, date: "2023-08-30 12:00:00", value: "2.13%"}),
            TimeSeriesItem({blockNumber: 18034417, date: "2023-08-31 12:00:00", value: "4.34%"}),
            TimeSeriesItem({blockNumber: 18041563, date: "2023-09-01 12:00:00", value: "4.41%"}),
            TimeSeriesItem({blockNumber: 18048689, date: "2023-09-02 12:00:00", value: "3.14%"}),
            TimeSeriesItem({blockNumber: 18055829, date: "2023-09-03 12:00:00", value: "8.17%"}),
            TimeSeriesItem({blockNumber: 18062975, date: "2023-09-04 12:00:00", value: "2.34%"}),
            TimeSeriesItem({blockNumber: 18070137, date: "2023-09-05 12:00:00", value: "2.19%"}),
            TimeSeriesItem({blockNumber: 18077263, date: "2023-09-06 12:00:00", value: "3.85%"}),
            TimeSeriesItem({blockNumber: 18084408, date: "2023-09-07 12:00:00", value: "2.84%"}),
            TimeSeriesItem({blockNumber: 18091556, date: "2023-09-08 12:00:00", value: "2.32%"}),
            TimeSeriesItem({blockNumber: 18098692, date: "2023-09-09 12:00:00", value: "2.19%"}),
            TimeSeriesItem({blockNumber: 18105833, date: "2023-09-10 12:00:00", value: "0.73%"}),
            TimeSeriesItem({blockNumber: 18112972, date: "2023-09-11 12:00:00", value: "0.00%"}),
            TimeSeriesItem({blockNumber: 18120110, date: "2023-09-12 12:00:00", value: "4.80%"}),
            TimeSeriesItem({blockNumber: 18127241, date: "2023-09-13 12:00:00", value: "4.05%"}),
            TimeSeriesItem({blockNumber: 18134380, date: "2023-09-14 12:00:00", value: "0.55%"}),
            TimeSeriesItem({blockNumber: 18141480, date: "2023-09-15 12:00:00", value: "4.80%"}),
            TimeSeriesItem({blockNumber: 18148567, date: "2023-09-16 12:00:00", value: "2.20%"}),
            TimeSeriesItem({blockNumber: 18155616, date: "2023-09-17 12:00:00", value: "1.31%"}),
            TimeSeriesItem({blockNumber: 18162687, date: "2023-09-18 12:00:00", value: "2.01%"}),
            TimeSeriesItem({blockNumber: 18169817, date: "2023-09-19 12:00:00", value: "0.67%"}),
            TimeSeriesItem({blockNumber: 18176961, date: "2023-09-20 12:00:00", value: "2.52%"}),
            TimeSeriesItem({blockNumber: 18184109, date: "2023-09-21 12:00:00", value: "1.94%"})
        ];
        // find the right bound, just beyond the end of the last timeseries date, for all subsequent searches
        Roller.Bounds memory bounds = Roller.Bounds(0, 0, block.number, block.timestamp);
        Roller.rollForkToBlockContaining(
            vm, DateUtils.convertDateTimeStringToTimestamp(timeSeries[timeSeries.length - 1].date) + 100, bounds
        );
        bounds.rightBlock = block.number;
        bounds.rightTimestamp = block.timestamp;

        uint256 base = vm.snapshot();

        console.log("Block, Roll count, Date, AAVe web, Bao logic");
        Correlation.Accumulator memory acc;

        for (uint256 i = 0; i < timeSeries.length; i++) {
            if (i > 0) vm.revertTo(base);

            uint256 rollCount = Roller.rollForkToBlockContaining(
                vm, DateUtils.convertDateTimeStringToTimestamp(timeSeries[i].date), bounds
            );

            // the dates are increasing so we can set the left bound to the current block
            bounds.leftBlock = block.number;
            bounds.leftTimestamp = block.timestamp;

            // if the block number is available
            // vm.rollFork(timeSeries[i].blockNumber);
            // uint256 rollCount = 1;

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
