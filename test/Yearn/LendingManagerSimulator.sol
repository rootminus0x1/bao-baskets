// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import {ILendingLogic} from "src/Interfaces/ILendingLogic.sol";
import "forge-std/Test.sol";

// TODO: incorporate this in the LogicYearn & LogicCompound tests

library LendingManagerSimulator {
    function lend(ILendingLogic _lendingLogic, address _underlying, uint256 _amount, address _tokenHolder) public {
        (address[] memory _targets, bytes[] memory _data) = _lendingLogic.lend(_underlying, _amount, _tokenHolder);

        for (uint8 i; i < _targets.length; i++) {
            (bool _success,) = _targets[i].call{value: 0}(_data[i]);
            require(_success, "Error");
        }
    }

    function unlend(ILendingLogic _lendingLogic, address _wrapped, uint256 _amount, address _tokenHolder) public {
        (address[] memory _targets, bytes[] memory _data) = _lendingLogic.unlend(_wrapped, _amount, _tokenHolder);

        for (uint8 i; i < _targets.length; i++) {
            (bool _success,) = _targets[i].call{value: 0}(_data[i]);
            require(_success, "Error");
        }
    }
}
