// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.1;

contract Useful {
    function memeq(bytes memory a, bytes memory b) internal pure returns (bool) {
        return (a.length == b.length) && (keccak256(a) == keccak256(b));
    }

    function streq(string memory a, string memory b) internal pure returns (bool) {
        return memeq(bytes(a), bytes(b));
    }
}
