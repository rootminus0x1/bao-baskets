// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.1;

contract TestData {
    address public zeroAddress = 0x0000000000000000000000000000000000000000;
    address public nonZeroAddress = 0x0000000000000000000000000000000000000001;
    bytes32 public zeroBytes32 = 0x0000000000000000000000000000000000000000000000000000000000000000;
    uint256 public zeroBigNumber = 0;
}
