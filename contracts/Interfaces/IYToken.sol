// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.1;

// This file reverse engineered from yvLUSD contract:
// https://etherscan.io/token/0x378cb52b00F9D0921cb46dFc099CFf73b42419dC#code
// and its attached strategy contract:
// https://etherscan.io/address/0xFf72f7C5f64ec2fd79B57d1A69C3311C1bB3EEF1#code
// the interface IYToken is not complete but contains all the functions needed so far

library YToken {
    uint256 constant MAXIMUM_STRATEGIES = 20;
}

struct YStrategyParams {
    uint256 performanceFee; // Strategist's fee (basis points)
    uint256 activation; // Activation block.timestamp
    uint256 debtRatio; // Maximum borrow amount (in BPS of total assets)
    uint256 minDebtPerHarvest; // Lower limit on the increase of debt since last harvest
    uint256 maxDebtPerHarvest; // Upper limit on the increase of debt since last harvest
    uint256 lastReport; // block.timestamp of the last time a report occured
    uint256 totalDebt; // Total outstanding debt that Strategy has (in underlying?)
    uint256 totalGain; // Total returns that Strategy has realized for Vault (in underlying?)
    uint256 totalLoss; // Total losses that Strategy has realized for Vault
}

interface IYToken {
    function expectedReturn(address ystrategy) external view returns (uint256 valueRealisedSinceLastReport);
    function withdrawalQueue(uint256 ystrategyIndex) external view returns (address ystrategy);
    function strategies(address ystrategy) external view returns (YStrategyParams calldata);
}

interface IYStrategy {
    function isActive() external view returns (bool);
}
