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
import {LendingLogicAaveV2} from "src/Strategies/LendingLogicAaveV2.sol";
import {ILendingLogic} from "src/Interfaces/ILendingLogic.sol";
import {ATokenV2} from "src/Strategies/LendingLogicAaveV2.sol";

import "src/Interfaces/IAaveLendingPoolV2.sol";

import {DateUtils} from "DateUtils/DateUtils.sol";

import {Useful} from "./Useful.sol";
import {ChainState, Roller} from "./ChainState.sol";
import {Deployed, ChainStateLending} from "./Deployed.sol";
import {TestLendingLogic} from "./TestLendingLogic.sol";
import {LendingManagerSimulator} from "./LendingManagerSimulator.sol";
import {TestData} from "./TestData.t.sol";

// TODO: split this file into 3
///////////////////////////////////////////////////////////////////////////////////////////////////
// DIRECT LENDING LOGIC INTERACTIONS
///////////////////////////////////////////////////////////////////////////////////////////////////

abstract contract LogicAave {
    address public wrapped;
    address public underlying;

    LendingLogicAaveV2 public lendingLogic;

    constructor(address _wrapped, address _underlying) {
        wrapped = _wrapped;
        underlying = _underlying;
    }

    // createLogic is a separate function, and not in the constructor, to allow it to be executed after rolling a fork to a given block
    function createLogic() public {
        lendingLogic = LendingLogicAaveV2(Deployed.LENDINGLOGICAAVE);
    }
}

abstract contract LogicAaveRAI is LogicAave(Deployed.ARAI, Deployed.RAI) {}

/*
contract TestApr is Test, LogicAaveLUSD {
    struct Result {
        uint256 blockNumber;
        uint256 apr;
    }

    function test_aprValues() public {
        // test a selection of blocks against known values
        Result[2] memory results = [
            Result(16919180, 60163416778911030 ),
            Result(17827230, 29042022965324392 )
        ];

        string memory url = vm.envString("MAINNET_RPC_URL");
        //console.log("MAINNET_RPC_URL=%s", url);
        for (uint256 r = 0; r < results.length; r++) {
            uint256 fork = vm.createFork(url);
            vm.selectFork(fork);
            vm.rollFork(results[r].blockNumber);
            createLogic();
            uint256 apr = lendingLogicYearn.getAPRFromWrapped(wrapped);
            assertEq(apr, results[r].apr, Useful.concat("apr for block ", Useful.toString(results[r].blockNumber)));
        }
    }
}
*/

/*
contract TestYearnLogicBackTest is Test, LogicYearnLUSD {
    struct TimeSeriesItem {
        string date;
        string value;
    }

    function test_historicalRates() public {
        //console.log("running historical rates test");
        vm.skip(!vm.envOr("BACKTESTS", false));

        TimeSeriesItem[10] memory timeSeries = [
            TimeSeriesItem({date: "2023-03-11 22:25:00", value: "8.48%"}),
            TimeSeriesItem({date: "2023-03-26 23:29:00", value: "7.21%"}),
            TimeSeriesItem({date: "2023-04-10 23:34:00", value: "7.14%"}),
            TimeSeriesItem({date: "2023-05-04 04:27:00", value: "4.97%"}),
            TimeSeriesItem({date: "2023-05-19 11:39:00", value: "3.87%"}),
            TimeSeriesItem({date: "2023-06-03 11:40:00", value: "3.16%"}),
            TimeSeriesItem({date: "2023-06-18 11:40:00", value: "2.70%"}),
            TimeSeriesItem({date: "2023-07-03 11:41:00", value: "2.72%"}),
            TimeSeriesItem({date: "2023-07-18 11:43:00", value: "3.07%"}),
            TimeSeriesItem({date: "2023-08-02 12:14:00", value: "2.63%"})
        ];
        string memory url = vm.envString("MAINNET_RPC_URL");
        // console.log("MAINNET_RPC_URL=%s", url);

        // TODO: break this pearson correlation out into Useful
        uint256 n = timeSeries.length;
        uint256 sumx = 0;
        uint256 sumy = 0;
        uint256 sumxy = 0;
        uint256 sumxx = 0;
        uint256 sumyy = 0;
        console.log("Date, Yearn, Bao");
        for (uint256 i = 0; i < n; i++) {
            uint256 fork = vm.createFork(url);
            vm.selectFork(fork);

            uint256 dt = DateUtils.convertDateTimeStringToTimestamp(timeSeries[i].date);
            Roller.rollForkBefore(vm, dt + 60 * 60); // add an hour

            createLogic();

            uint256 apr = lendingLogicYearn.getAPRFromWrapped(wrapped);
            console.log(
                "%s, %s, %s%%",
                DateUtils.convertTimestampToDateTimeString(block.timestamp),
                timeSeries[i].value,
                Useful.toStringScaled(apr, 18 - 2)
            );
            uint256 x = apr;
            uint256 y = Useful.toUint256(timeSeries[i].value, 18);
            sumx += x;
            sumy += y;
            sumxy += x * y;
            sumxx += x * x;
            sumyy += y * y;
        }
        // r = n * (sum(x*y)) - (sum(x) * sum(y))
        //     ------------------------------------
        //     sqrt((n * sum(x*x) - sum(x)**2)) * sqrt((n * sum(x*x) - sum(y)**2))
        uint256 numer = n * sumxy - sumx * sumy;
        uint256 denom = Useful.sqrt(n * sumxx - sumx * sumx) * Useful.sqrt(n * sumyy - sumy * sumy);
        uint256 correlation = numer * 1e18 / denom;
        console.log("correlation=%s", Useful.toStringScaled(correlation, 18));
        assertGt(correlation, 9 * 1e17, "good correlation");
    }

    function test_detailedhistoricalRates() public {
        vm.skip(!vm.envOr("BACKTESTS", false));

        string memory startDateTime = "2023-03-12 12:25:00"; // about as early as you can go for yvLUSD
        string memory finishDateTime = "2023-08-02 12:14:00";
        //string memory finishDateTime = "2023-03-15 12:30:00"; // test for 1 day

        uint256 startTimestamp = DateUtils.convertDateTimeStringToTimestamp(startDateTime);
        uint256 finishTimestamp = DateUtils.convertDateTimeStringToTimestamp(finishDateTime);

        // TODO: rationalise the following code into a chainfork that supports multiple forks
        string memory url = vm.envString("MAINNET_RPC_URL");
        // console.log("MAINNET_RPC_URL=%s", url);

        // do a daily sample
        uint256 samplePeriod = 60 * 60 * 24; // one a day; <-- parameter
        uint256 numberOfSamples = (finishTimestamp - startTimestamp) / samplePeriod;

        console.log("numberOfSamples=%d", numberOfSamples);
        // work out how many blocks to go per sample Period
        uint256 fork = vm.createFork(url);
        vm.selectFork(fork);
        Roller.rollForkBefore(vm, finishTimestamp);
        uint256 finishBlock = block.number;
        Roller.rollForkBefore(vm, startTimestamp);
        uint256 startBlock = block.number;

        uint256 blocksPerSamplePeriod = (finishBlock - startBlock) / numberOfSamples;
        console.log("sampling between blocks %d and %d", startBlock, finishBlock);

        console.log("block, Date, Bao");
        uint256 currentBlock = block.number;
        while (currentBlock <= finishBlock) {
            createLogic();
            uint256 apr = lendingLogicYearn.getAPRFromWrapped(wrapped);
            console.log(
                "%d, %s, %s%%",
                currentBlock,
                DateUtils.convertTimestampToDateTimeString(block.timestamp),
                Useful.toStringScaled(apr, 18 - 2)
            );
            currentBlock += blocksPerSamplePeriod;
            fork = vm.createFork(url);
            vm.selectFork(fork);
            vm.rollFork(currentBlock);
        }
    }
}
*/

///////////////////////////////////////////////////////////////////////////////////////////////////
// LENDING LOGIC VIA LENDING REGISTRY INTERACTIONS
///////////////////////////////////////////////////////////////////////////////////////////////////

/*
abstract contract TestLendingLogicYearn is LogicYearn, TestLendingLogic {
    uint256 expectedApr;
    string underlyingName;

    constructor(address _wrapped, address _underlying, string memory ulName, uint256 _apr, uint256 _exchangeRate)
        LogicYearn(_wrapped, _underlying)
    {
        underlyingName = ulName;
        LogicYearn.createLogic(); // do this before below
        TestLendingLogic.initialise(LENDINGLOGICYEARN, PROTOCOLYEARN, _wrapped, _underlying, _apr, _exchangeRate);

        expectedApr = _apr;

        vm.startPrank(Deployed.BAOMULTISIG);
        // set up the lending registry
        lendingRegistry.setWrappedToProtocol(wrapped, PROTOCOLYEARN);
        lendingRegistry.setWrappedToUnderlying(wrapped, underlying);
        lendingRegistry.setProtocolToLogic(PROTOCOLYEARN, LENDINGLOGICYEARN);
        lendingRegistry.setUnderlyingToProtocolWrapped(underlying, PROTOCOLYEARN, wrapped);
        vm.stopPrank();
    }

    function test_getApr() public {
        // this test ensure that if the getApr logic changes, then we find out
        uint256 apr = lendingLogicYearn.getAPRFromWrapped(wrapped);
        assertEq(block.number, 17698530, "wrong block"); // 2023-07-15 11:36:35
        assertApproxEqAbs(apr, expectedApr, 10000, Useful.concat(underlyingName, ": APR for block 17698530")); // ignore the last 4 digits
    }
}


*/

///////////////////////////////////////////////////////////////////////////////////////////////////
// LENDING MANAGER interactions
///////////////////////////////////////////////////////////////////////////////////////////////////

abstract contract TestAaveLending is Test, LendingManagerSimulator {
    address underlying;
    address wrapped;
    string underlyingName;
    string wrappedName;

    constructor(address _wrapped, address _lendingLogic) LendingManagerSimulator(_lendingLogic) {
        wrapped = _wrapped;
        underlying = ATokenV2(wrapped).UNDERLYING_ASSET_ADDRESS();
        underlyingName = IEIP20(underlying).symbol();
        wrappedName = IEIP20(wrapped).symbol();
    }

    function test_getApr() public {
        uint256 apr = lendingLogic.getAPRFromWrapped(wrapped);
        console.log("apr for %s = %s%%", wrappedName, Useful.toStringScaled(apr, 18 - 2));
    }

    function test_lendDetails() public {
        uint256 amount = 100 * 1e18; // $100, no less
        address wallet = address(this);

        // get some (more) dosh
        deal(underlying, wallet, amount * 2);
        uint256 startUnderlyingAmount = IERC20(underlying).balanceOf(wallet);
        uint256 startWrappedAmount = IERC20(wrapped).balanceOf(wallet);

        // the lend
        assertGe(IERC20(underlying).balanceOf(wallet), amount, "not enough underlying in wallet");
        uint256 startPoolBalance = IERC20(underlying).balanceOf(wrapped);

        lend(underlying, amount, wallet);
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
            IERC20(underlying).balanceOf(wrapped),
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
        unlend(wrapped, wrappedReturned1, wallet);
        //unlend(wrappedReturned1);
        uint256 underlyingReturned1 = wrappedReturned1; // * exchange rate

        assertEq(
            IERC20(underlying).balanceOf(wrapped),
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
        unlend(wrapped, wrappedReturned2, wallet);
        // unlend(wrappedReturned2);
        uint256 underlyingReturned2 = wrappedReturned2;

        assertApproxEqAbs(
            underlyingReturned1 + underlyingReturned2,
            amount,
            2, // 2 because there are 2 rounding error possibilities, one for each unlend
            Useful.concat("should have returned all the underlying ", underlyingName)
        );

        assertApproxEqAbs(
            IERC20(underlying).balanceOf(wrapped),
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
            1, // rounding errors passed on (maybe)
            Useful.concat("all shares should be transferred out of the wallet ", underlyingName)
        );
    }
}

// as of Jul-23 fails because VL_RESERVE_FROZEN (see https://github.com/aave/protocol-v2/blob/ce53c4a8c8620125063168620eba0a8a92854eb8/helpers/types.ts#L128)
// contract TestAaveLendingARAI is TestAaveLending(Deployed.ARAI) {}

// as of Jul-23 fails because VL_RESERVE_FROZEN (see https://github.com/aave/protocol-v2/blob/ce53c4a8c8620125063168620eba0a8a92854eb8/helpers/types.ts#L128)
// contract TestAaveLendingAFEI is TestAaveLending(Deployed.AFEI) {}

contract TestAaveLendingAUSDC is TestAaveLending(Deployed.AUSDC, Deployed.LENDINGLOGICAAVE) {}

contract TestAaveLendingAFRAX is TestAaveLending(Deployed.AFRAX, Deployed.LENDINGLOGICAAVE) {}

// as of Jul-23 fails because VL_RESERVE_FROZEN (see https://github.com/aave/protocol-v2/blob/ce53c4a8c8620125063168620eba0a8a92854eb8/helpers/types.ts#L128)
// contract TestAaveLendingAYFI is TestAaveLending(Deployed.AYFI) {}

contract TestAaveLendingACRV is TestAaveLending(Deployed.ACRV, Deployed.LENDINGLOGICAAVE) {}

contract TestAaveLendingADAI is TestAaveLending(Deployed.ADAI, Deployed.LENDINGLOGICAAVE) {}

// fails due to sime security issue that foundry won't execute
// contract TestAaveLendingASUSD is TestAaveLending(Deployed.ASUSD) {}

//contract TestAaveLendingV3ADAI is
//    TestAaveLending(Deployed.ADAI, address(new LendingLogicAaveV2(Deployed.AAVELENDINGPOOLV3, 0)))
//{}

/*
contract TestAaveLendingAll is Test {
    function test_Aave() public{
        address[] wrappedList;
        wrappedList.push
    }
}
*/

// TODO:
/*
abstract contract LogicAaveV3 {
    address public wrapped;
    address public underlying;

    LendingLogicAaveV2 public lendingLogic;

    constructor(address _wrapped, address _underlying) {
        wrapped = _wrapped;
        underlying = _underlying;
    }

    // createLogic is a separate function, and not in the constructor, to allow it to be executed after rolling a fork to a given block
    function createLogic() public {
        // TODO: create the lending registry for V3
        lendingLogic = new LendingLogicAaveV2(Deployed.LENDINGREGISTRY, PROTOCOLAAVEV3);
        // TODO: LENDINGLOGICAAVEV3 = address(lendingLogic);
    }
}
*/
