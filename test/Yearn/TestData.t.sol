// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.1;

contract TestData {
    address public zeroAddress = 0x0000000000000000000000000000000000000000;
    address public nonZeroAddress = 0x0000000000000000000000000000000000000001;
    address public nonZeroAddress2 = 0x0000000000000000000000000000000000000002;
    bytes32 public zeroBytes32 = 0x0000000000000000000000000000000000000000000000000000000000000000;
    bytes32 public nonZeroBytes32 = 0x0000000000000000000000000000000000000000000000000000000000000001;
    uint256 public zeroBigNumber = 0;
    uint256 public nonZeroBigNumber = 1;
}
