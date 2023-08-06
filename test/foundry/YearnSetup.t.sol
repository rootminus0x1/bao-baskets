// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.5.1;

// solhint-disable func-name-mixedcase
// solhint-disable no-console
import {console2 as console} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

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

abstract contract YearnLusd {
    address public wrapped = Deployed.YVLUSD;
    address public underlying = Deployed.LUSD;

    bytes32 public constant PROTOCOLYEARN = 0x0000000000000000000000000000000000000000000000000000000000000004;

    LendingLogicYearn public lendingLogicYearn;
    address public LENDINGLOGICYEARN;

    function createLogic() public {
        lendingLogicYearn = new LendingLogicYearn(Deployed.LENDINGREGISTRY, PROTOCOLYEARN);
        LENDINGLOGICYEARN = address(lendingLogicYearn);

        lendingLogicYearn.transferOwnership(Deployed.OWNER);
    }
}

contract TestYearnLusd is TestLendingLogic, YearnLusd {
    function setUp() public {
        YearnLusd.createLogic();

        vm.startPrank(Deployed.OWNER);
        // set up the lending registry
        lendingRegistry.setWrappedToProtocol(wrapped, PROTOCOLYEARN);
        lendingRegistry.setWrappedToUnderlying(wrapped, underlying);
        lendingRegistry.setProtocolToLogic(PROTOCOLYEARN, LENDINGLOGICYEARN);
        lendingRegistry.setUnderlyingToProtocolWrapped(underlying, PROTOCOLYEARN, wrapped);
        vm.stopPrank();

        TestLendingLogic.create(LENDINGLOGICYEARN, PROTOCOLYEARN, wrapped, underlying);
    }
}

contract TestYearnLogicBackTest is Test, YearnLusd {
    struct TimeSeriesItem {
        string date;
        string value;
    }

    function test_historicalRates() public {
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

    function test_detailedhistoricalRates() public {
        string memory startDateTime = "2023-03-12 12:25:00"; // about as early as you can go for yvLUSD
        string memory finishDateTime = "2023-08-02 12:14:00";
        //string memory finishDateTime = "2023-03-15 12:30:00"; // test for 1 day

        uint256 startTimestamp = DateUtils.convertDateTimeStringToTimestamp(startDateTime);
        uint256 finishTimestamp = DateUtils.convertDateTimeStringToTimestamp(finishDateTime);

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

        console.log("fork, block, Date, Bao");
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
