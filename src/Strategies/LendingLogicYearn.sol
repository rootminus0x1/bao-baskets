// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.1;

import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/math/SafeMath.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";
import "../Interfaces/IEIP20.sol";
import "../Interfaces/ILendingLogic.sol";
import "../Interfaces/IYToken.sol";
import "../LendingRegistry.sol";

contract LendingLogicYearn is Ownable, ILendingLogic {
    using SafeMath for uint256;

    LendingRegistry public lendingRegistry;
    bytes32 public immutable protocolKey;

    constructor(address _lendingRegistry, bytes32 _protocolKey) {
        require(_lendingRegistry != address(0), "INVALID_LENDING_REGISTRY");
        lendingRegistry = LendingRegistry(_lendingRegistry);
        protocolKey = _protocolKey;
    }

    function getAPRFromWrapped(address wrapped) public view override returns (uint256 apr) {
        /* multiple strategies:
            as each strategy has a different harvest period, different debts, and different fees
            they can't be summed
            so, sum the gains, scaled to a year (so they *can* be summed), with fee subtracted 
            then divided that by the sum of the strategy debts
            for 1 strategy, its the same thing :-) 
            this is hinted at here: https://docs.yearn.finance/getting-started/guides/how-to-understand-yvault-roi
            in the non-curve assets infographic where it says, 
            "the yield calculated ... is the sum of all the active strategies" 
        */
        IYToken yv = IYToken(wrapped);

        uint256 totalReturnSinceLastReportScaledToYear = 0;
        uint256 totalTotalDebt = 0;
        // there's no length available for the withdrawal queue, so use the max and stop when we get a null strategy
        for (uint256 s = 0; s < YToken.MAXIMUM_STRATEGIES; s++) {
            address yStrategy = yv.withdrawalQueue(s);
            if (yStrategy == address(0)) break; // a null strategy marks the end of the queue;
            if (!IYStrategy(yStrategy).isActive()) continue; // next strategy, please
            // got a strategy, so look at it's parameters
            YStrategyParams memory yStrategyParams = yv.strategies(yStrategy);
            if (yStrategyParams.totalDebt == 0) continue; // no debt so nothing to see here, move along

            // calculate the gains
            uint256 timeSinceLastHarvest = block.timestamp - yStrategyParams.lastReport;
            uint256 totalHarvestTime = yStrategyParams.lastReport - yStrategyParams.activation;
            if (timeSinceLastHarvest > 0 && totalHarvestTime > 0) {
                // must have some time, or there are no gains (also, more importantly, to avoid divide by zeros)
                uint256 returnSinceLastReport = yStrategyParams.totalGain * timeSinceLastHarvest / totalHarvestTime;
                // subtract the performance fee to this return as they are applied every harvest
                // i.e. the totalGain aready has fees applied but the return since harvest hasn't
                // see https://docs.yearn.finance/getting-started/products/yvaults/overview for more detail
                // performance fee is bps, e.g. 1 = 0.0001, so scale it by 10**4
                returnSinceLastReport *= (1 * 10 ** 4 - yStrategyParams.performanceFee);

                // totalReturnSinceLastReportScaledToYear += yStrategyParams.totalGain * 31_556_952 / totalHarvestTime;
                totalReturnSinceLastReportScaledToYear +=
                    returnSinceLastReport * totalHarvestTime / timeSinceLastHarvest * 31_556_952 / totalHarvestTime;
            }
            totalTotalDebt += yStrategyParams.totalDebt;
            // get the decimal in the right place:
            // we already scaled by 10**4 when deducting the fee so just to 10**14 more
            apr = totalReturnSinceLastReportScaledToYear * 10 ** 14 / totalTotalDebt;
        }
    }

    function getAPRFromUnderlying(address underlying) external view override returns (uint256) {
        address wrapped = lendingRegistry.underlyingToProtocolWrapped(underlying, protocolKey);
        return getAPRFromWrapped(wrapped);
    }

    function lend(address _underlying, uint256 _amount, address /*_tokenHolder*/ )
        external
        view
        override
        returns (address[] memory targets, bytes[] memory data)
    {
        targets = new address[](3);
        data = new bytes[](3);

        address yToken = lendingRegistry.underlyingToProtocolWrapped(_underlying, protocolKey);

        // Set approval
        targets[0] = _underlying;
        data[0] = abi.encodeWithSelector(IERC20(_underlying).approve.selector, yToken, _amount);

        // Deposit into Yearn
        targets[1] = yToken;
        data[1] = abi.encodeWithSelector(IYToken(yToken).deposit.selector, _amount);

        // zero out approval to be sure
        // there's a non-zero chance that between the caller of this function checking the
        // wallet amount of underlying and it executing the above transactions that the wallet
        // may have some of it's underlying transferred out causing the deposit to fail,
        // leaving the allowance at amount which is a bit sloppy.
        targets[2] = _underlying;
        data[2] = abi.encodeWithSelector(IERC20(_underlying).approve.selector, yToken, 0);
    }

    function unlend(address _wrapped, uint256 _amount, address /* _tokenHolder */ )
        external
        pure
        override
        returns (address[] memory targets, bytes[] memory data)
    {
        targets = new address[](1);
        data = new bytes[](1);

        targets[0] = _wrapped;
        data[0] = abi.encodeWithSelector(IYToken(_wrapped).withdraw.selector, _amount);
    }

    function exchangeRate(address _wrapped) external view override returns (uint256) {
        return this.exchangeRateView(_wrapped);
    }

    function exchangeRateView(address _wrapped) external view override returns (uint256) {
        // price per share is scaled according to the decimals of the underlying
        // but the recipe needs it scaled as if it had 18 decimals
        // therefore we scale
        address underlying = lendingRegistry.wrappedToUnderlying(_wrapped);
        return IYToken(_wrapped).pricePerShare() * 10 ** (18 - IEIP20(underlying).decimals());
    }
}
