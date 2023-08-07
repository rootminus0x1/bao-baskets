// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.7.1;

// solhint-disable func-name-mixedcase
// solhint-disable no-console
import {console2 as console} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

import {IYToken, YStrategyParams, IYStrategy} from "contracts/Interfaces/IYToken.sol";
import {LendingRegistry} from "contracts/LendingRegistry.sol";
import {LendingLogicYearn} from "contracts/Strategies/LendingLogicYearn.sol";
import {ILendingLogic} from "contracts/Interfaces/ILendingLogic.sol";

import {DateUtils} from "./SkeletonCodeworks/DateUtils/DateUtils.sol";

import {Useful} from "./Useful.sol";
import {ChainState, Roller} from "./ChainState.sol";
import {Deployed, ChainStateLending} from "./Deployed.sol";
import {TestLendingLogic} from "./TestLendingLogic.sol";
import {TestData} from "./TestData.t.sol";
// import {Dai} from "./Dai.t.sol";

abstract contract LogicYearn {
    address public wrapped;
    address public underlying;

    bytes32 public constant PROTOCOLYEARN = 0x0000000000000000000000000000000000000000000000000000000000000004;

    LendingLogicYearn public lendingLogicYearn;
    address public LENDINGLOGICYEARN;

    constructor(address _wrapped, address _underlying) {
        wrapped = _wrapped;
        underlying = _underlying;
    }

    // createLogic is a separate function, and not in the constructor, to allow it to be executed after rolling a fork to a given block
    function createLogic() public {
        lendingLogicYearn = new LendingLogicYearn(Deployed.LENDINGREGISTRY, PROTOCOLYEARN);
        LENDINGLOGICYEARN = address(lendingLogicYearn);

        lendingLogicYearn.transferOwnership(Deployed.OWNER);
    }
}

abstract contract LogicYearnLUSD is LogicYearn(Deployed.YVLUSD, Deployed.LUSD) {}

abstract contract TestLendingLogicYearn is LogicYearn, TestLendingLogic {
    uint256 expectedApr;
    string underlyingName;

    constructor(address _wrapped, address _underlying, string memory ulName, uint256 _apr)
        LogicYearn(_wrapped, _underlying)
    {
        underlyingName = ulName;
        LogicYearn.createLogic(); // do this before below
        TestLendingLogic.initialise(LENDINGLOGICYEARN, PROTOCOLYEARN, _wrapped, _underlying);

        expectedApr = _apr;

        vm.startPrank(Deployed.OWNER);
        // set up the lending registry
        lendingRegistry.setWrappedToProtocol(wrapped, PROTOCOLYEARN);
        lendingRegistry.setWrappedToUnderlying(wrapped, underlying);
        lendingRegistry.setProtocolToLogic(PROTOCOLYEARN, LENDINGLOGICYEARN);
        lendingRegistry.setUnderlyingToProtocolWrapped(underlying, PROTOCOLYEARN, wrapped);
        vm.stopPrank();

        //TestLendingLogic.create(LENDINGLOGICYEARN, PROTOCOLYEARN, wrapped, underlying);
    }

    function test_getApr() public {
        // this test ensure that if the getApr logic changes, then we find out
        uint256 apr = lendingLogicYearn.getAPRFromWrapped(wrapped);
        assertEq(block.number, 17698530, "wrong block"); // 2023-07-15 11:36:35
        assertApproxEqAbs(apr, expectedApr, 10000, Useful.concat(underlyingName, ": APR for block 17698530")); // ignore the last 4 digits
    }

    function test_getStrategyDetails() public {
        IYToken yv = IYToken(wrapped);
        console.log("---");
        for (uint256 s = 0; s < 25; s++) {
            address yStrategy = yv.withdrawalQueue(s);
            if (yStrategy == address(0)) break; // a null strategy marks the end of the queue;

            console.log("yStrategy address=%o", yStrategy);
            if (!IYStrategy(yStrategy).isActive()) {
                console.log("   inactive");
                continue; // next strategy, please
            }
            YStrategyParams memory yStrategyParams = yv.strategies(yStrategy);

            if (yStrategyParams.totalDebt == 0) {
                console.log("   zero debt");
                continue; // no debt so nothing to see here, move along
            }

            console.log("StrategyParams:");
            console.log("   performanceFee=   %d // Strategist's fee (basis points)", yStrategyParams.performanceFee);
            console.log(
                "   activation=       %d (%s) // Activation block.timestamp",
                yStrategyParams.activation,
                DateUtils.convertTimestampToDateTimeString(yStrategyParams.activation)
            );
            console.log(
                "   debtRatio=        %d // Maximum borrow amount (in BPS of total assets)", yStrategyParams.debtRatio
            );
            console.log(
                "   minDebtPerHarvest=%d // Lower limit on the increase of debt since last harvest",
                yStrategyParams.minDebtPerHarvest
            );
            console.log(
                "   maxDebtPerHarvest=%d // Upper limit on the increase of debt since last harvest",
                yStrategyParams.minDebtPerHarvest
            );
            console.log(
                "   lastReport=       %d (%s) // block.timestamp of the last time a report occured",
                yStrategyParams.lastReport,
                DateUtils.convertTimestampToDateTimeString(yStrategyParams.lastReport)
            );
            console.log(
                "   totalDebt=        %s // Total outstanding debt that Strategy has (in underlying?)",
                Useful.toStringThousands(yStrategyParams.totalDebt, Useful.comma)
            );
            console.log(
                "   totalGain=        %s // Total returns that Strategy has realized for Vault (in underlying?)",
                Useful.toStringThousands(yStrategyParams.totalGain, Useful.comma)
            );
            console.log(
                "   totalLoss=        %s; // Total losses that Strategy has realized for Vault",
                Useful.toStringThousands(yStrategyParams.totalLoss, Useful.comma)
            );

            // calculate the gains
            uint256 totalHarvestTime = yStrategyParams.lastReport - yStrategyParams.activation;
            uint256 timeSinceLastHarvest = block.timestamp - yStrategyParams.lastReport;
            if (timeSinceLastHarvest == 0 || totalHarvestTime == 0) {
                console.log("no harvests");
                continue;
            }
            console.log(
                "totalHarvestTime = %d (%s days) (lastReport - activation)",
                totalHarvestTime,
                totalHarvestTime / 60 / 60 / 24
            );
            console.log(
                "timeSinceLastHarvest= %d (%s days) (block.timestamp - lastReport)",
                timeSinceLastHarvest,
                timeSinceLastHarvest / 60 / 60 / 24
            );

            uint256 returnSinceLastReport = yStrategyParams.totalGain * timeSinceLastHarvest / totalHarvestTime;
            console.log(
                "returnSinceLastReport=%s (totalGain * timeSinceLastHarvest / totalHarvestTime)",
                Useful.toStringThousands(returnSinceLastReport, Useful.comma)
            );
            uint256 apr = returnSinceLastReport * 10 ** 18 / yStrategyParams.totalDebt;
            console.log("rate for period=%s", Useful.toStringThousands(apr, Useful.underscore));

            // scale it to a year, i.e. no compounding, for APR
            apr = apr * 31_556_952 / timeSinceLastHarvest;
            console.log("apr=%d, %s%% (seconds in year / timeSinceLastHarvest)", apr, Useful.toStringScaled(apr, 16));
            console.log("---");
        }
    }
}

contract TestLendingLogicYearnLUSD is
    TestLendingLogicYearn(Deployed.YVLUSD, Deployed.LUSD, "LUSD", 28554710897801830)
{}

contract TestLendingLogicYearnUSDC is
    TestLendingLogicYearn(Deployed.YVUSDC, Deployed.USDC, "USDC", 26008016921457931)
{}

contract TestLendingLogicYearnDAI is TestLendingLogicYearn(Deployed.YVDAI, Deployed.DAI, "DAI", 33170550474952463) {}

contract TestLendingLogicYearnUSDT is
    TestLendingLogicYearn(Deployed.YVUSDT, Deployed.USDT, "USDT", 21175457302527667)
{}

// TUSD gives over 200% APR, which is wrong :-)
contract TestLendingLogicYearnTUSD is
    TestLendingLogicYearn(Deployed.YVTUSD, Deployed.TUSD, "TUSD", 2216414571994840630)
{}

contract TestApr is Test, LogicYearnLUSD {
    struct Result {
        uint256 blockNumber;
        uint256 apr;
    }

    function test_aprValues() public {
        // test a selection of blocks against known values
        Result[2] memory results = [
            Result(16919180, 60163416778911030 /* was 60163416778910791 */ ),
            Result(17827230, 29042022965324392 /* was 29042022965321539 */ )
        ];

        string memory url = vm.envString("MAINNET_RPC_URL");
        console.log("MAINNET_RPC_URL=%s", url);
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

contract TestYearnLogicBackTest_long is Test, LogicYearnLUSD {
    struct TimeSeriesItem {
        string date;
        string value;
    }

    function test_historicalRates_long() public {
        // TODO: check that the correlation > 0.9
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
        console.log("MAINNET_RPC_URL=%s", url);
        console.log("Date, Yearn, Bao");
        for (uint256 i = 0; i < timeSeries.length; i++) {
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
        }
    }

    function test_detailedhistoricalRates_long() public {
        string memory startDateTime = "2023-03-12 12:25:00"; // about as early as you can go for yvLUSD
        string memory finishDateTime = "2023-08-02 12:14:00";
        //string memory finishDateTime = "2023-03-15 12:30:00"; // test for 1 day

        uint256 startTimestamp = DateUtils.convertDateTimeStringToTimestamp(startDateTime);
        uint256 finishTimestamp = DateUtils.convertDateTimeStringToTimestamp(finishDateTime);

        // TODO: rationalise the following code into a chainfork that supports multiple forks
        string memory url = vm.envString("MAINNET_RPC_URL");
        console.log("MAINNET_RPC_URL=%s", url);

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
