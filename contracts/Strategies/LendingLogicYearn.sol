// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.1;

import "../OpenZeppelin/Ownable.sol";
import "../OpenZeppelin/SafeMath.sol";
import "../Interfaces/IERC20.sol";
import "../Interfaces/ILendingLogic.sol";
import "../LendingRegistry.sol";

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

/*
ABI for expectedReturn on the strategy
  {
    "stateMutability": "view",
    "type": "function",
    "name": "expectedReturn",
    "inputs": [
      {
        "name": "strategy",
        "type": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256"
      }
    ]
  },
*/

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
        // TODO: check wrapped is a IYToken?
        // TODO: handle multiple strategies
        /* multiple strategies:
            as each strategy has a different harvest period and different debts, they can't be summed.
            one simplistic approach is to average the calculated APRs, but a product of a sum is
            not the same as a sum of a product, so it will be out.
            i.e. sum the total gains, each scaled to a year (so they *can* be summed) and divided that
            by the sum of the strategy debts
            for 1 strategy, its the same thing :-) 
        */
        IYToken yv = IYToken(wrapped);
        address ystrategy = yv.withdrawalQueue(0); // 0xFf72f7C5f64ec2fd79B57d1A69C3311C1bB3EEF1
        uint256 returnSinceLastReport;
        YStrategyParams memory yStrategyParams = yv.strategies(ystrategy);
        /* from the yv contract code:
        uint256 strategy_lastReport = wrapped.strategies[strategy].lastReport
        uint256 timeSinceLastHarvest = block.timestamp - strategy_lastReport
        uint256 totalHarvestTime = strategy_lastReport - wrapped.strategies[strategy].activation 
        returnSinceLastReport = wrapped.strategies[strategy].totalGain
            * wrapped.timeSinceLastHarvest
            / wrapped.totalHarvestTime
        */
        // TODO: do the losses need to be taken into account in the above?
        // need to divide by wrapped[strategy].totalDebt to getpercentage
        // but total Debt has potentially changed over the time - is ok to get an average?
        // TODO: check if totalDebt is 0 then it's not in the withdrawal queue
        //returnSinceLastReport = yv.expectedReturn(ystrategy);
        // also need to scale by 10**18 to divide by the totalDebt, hence 10**16
        //apr = (returnSinceLastReport * 10 ** 20) / yStrategyParams.totalDebt;

        uint256 timeSinceLastHarvest = block.timestamp - yStrategyParams.lastReport;
        uint256 totalHarvestTime = yStrategyParams.lastReport - yStrategyParams.activation;
        returnSinceLastReport = yStrategyParams.totalGain * timeSinceLastHarvest / totalHarvestTime;
        apr = returnSinceLastReport * 10 ** 18 / yStrategyParams.totalDebt;

        // scale it to a year, i.e. no compounding, for APR
        apr = apr * 31_556_952 / timeSinceLastHarvest;
        // normalise it to 1, instead of basis of a percent

        // TODO: subtract the performance fee (yStrategyParams.performanceFee)?
        // performance fee is bps, i.e. scaled to 6 digits, need to multiply it by 10*12 first?
    }

    function getAPRFromUnderlying(address underlying) external view override returns (uint256) {
        // TODO: should the below be done once in the constructor as it's unlikely to change?
        address wrapped = lendingRegistry.underlyingToProtocolWrapped(underlying, protocolKey);
        return getAPRFromWrapped(wrapped);
    }

    function lend(address _underlying, uint256 _amount, address /*_tokenHolder*/ )
        external
        view
        override
        returns (address[] memory targets, bytes[] memory data)
    {
        IERC20 underlying = IERC20(_underlying);

        targets = new address[](3);
        data = new bytes[](3);

        address yToken = lendingRegistry.underlyingToProtocolWrapped(_underlying, protocolKey);

        // zero out approval to be sure
        targets[0] = _underlying;
        data[0] = abi.encodeWithSelector(underlying.approve.selector, yToken, 0);

        // Set approval
        targets[1] = _underlying;
        data[1] = abi.encodeWithSelector(underlying.approve.selector, yToken, _amount);

        // Deposit into Yearn
        targets[2] = yToken;
        // data[2] = abi.encodeWithSelector(IYToken.mint.selector, _amount);

        return (targets, data);
    }

    function unlend(address _wrapped, uint256 _amount, address _tokenHolder)
        external
        view
        override
        returns (address[] memory targets, bytes[] memory data)
    {
        targets = new address[](1);
        data = new bytes[](1);

        targets[0] = _wrapped;
        // TODO: data[0] = abi.encodeWithSelector(ICToken.redeem.selector, _amount);

        return (targets, data);
    }

    function exchangeRate(address _wrapped) external override returns (uint256) {
        return 0; // TODO: ICToken(_wrapped).exchangeRateCurrent();
    }

    function exchangeRateView(address _wrapped) external view override returns (uint256) {
        return 0; // TODO: ICToken(_wrapped).exchangeRateStored();
    }
}
