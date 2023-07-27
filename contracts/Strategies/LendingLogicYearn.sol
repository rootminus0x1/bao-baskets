// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.1;

import "../OpenZeppelin/Ownable.sol";
import "../OpenZeppelin/SafeMath.sol";
import "../Interfaces/IERC20.sol";
import "../Interfaces/ILendingLogic.sol";
import "../LendingRegistry.sol";
import {MapList, ArrayList} from "../Utility/List.sol";

interface IYToken {
    function expectedReturn(address strategy) external view returns (uint256);
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

    mapping(address => ArrayList) public wrappedToStrategies;
    // address internal constant GUARD = address(1);

    constructor(address _lendingRegistry, bytes32 _protocolKey) {
        require(_lendingRegistry != address(0), "INVALID_LENDING_REGISTRY");
        lendingRegistry = LendingRegistry(_lendingRegistry);
        protocolKey = _protocolKey;

        address wrapped = lendingRegistry.protocolToLogic(_protocolKey);
        wrappedToStrategies[wrapped] = new ArrayList();
    }

    function addStrategyFor(address wrapped, address strategy) public onlyOwner {
        // when new strategies are added, you can see them via
        //       log StrategyAdded(strategy (indexed), debtRatio, minDebtPerHarvest, maxDebtPerHarvest, performanceFee)
        wrappedToStrategies[wrapped].insert(strategy);
    }

    function revokeStrategyFor(address wrapped, address strategy) public onlyOwner {
        // when strategies are revoked, this event is generated:
        //   StrategyRevoked(strategy (indexed))
        wrappedToStrategies[wrapped].remove(strategy);
    }

    /*
    function _strategyCall(address wrapped, address strategy) internal returns (uint256 result) {
        bytes memory payload = abi.encodeWithSignature("expectedReturn(address)", strategy);
        (bool success, bytes memory returnData) = wrapped.call(payload);
        require(success, "error calling expectedReturn");
        require(returnData.length == 32, "expectedReturn result is not 32 bytes");
        assembly {
            result := mload(add(returnData, 32))
        }
    }
    */

    function getAPRFromWrapped(address wrapped) public view override returns (uint256) {
        // TODO: handle multiple strategies
        uint256 max;
        max = IYToken(wrapped).expectedReturn(0xFf72f7C5f64ec2fd79B57d1A69C3311C1bB3EEF1);
        return max;
    }

    function getAPRFromUnderlying(address underlying) external view override returns (uint256) {
        // TODO: this is not an APR. It's just a number of something which is the average since
        // the strategy's inception
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
