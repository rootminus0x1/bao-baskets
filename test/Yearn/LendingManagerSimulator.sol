pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import {ILendingLogic} from "src/Interfaces/ILendingLogic.sol";
import "forge-std/Test.sol";

// TODO: incorporate this in the LogicYearn & LogicCompound tests

abstract contract LendingManagerSimulator {
    ILendingLogic public lendingLogic;

    constructor(address _lendingLogic) {
        lendingLogic = ILendingLogic(_lendingLogic);
    }

    function lend(address _underlying, uint256 _amount, address _tokenHolder) public {
        (address[] memory _targets, bytes[] memory _data) = lendingLogic.lend(_underlying, _amount, _tokenHolder);

        for (uint8 i; i < _targets.length; i++) {
            (bool _success,) = _targets[i].call{value: 0}(_data[i]);
            require(_success, "Error");
        }
    }

    function unlend(address _wrapped, uint256 _amount, address _tokenHolder) public {
        (address[] memory _targets, bytes[] memory _data) = lendingLogic.unlend(_wrapped, _amount, _tokenHolder);

        for (uint8 i; i < _targets.length; i++) {
            (bool _success,) = _targets[i].call{value: 0}(_data[i]);
            require(_success, "Error");
        }
    }
}
