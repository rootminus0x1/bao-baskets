// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.1;

import {console2 as console} from "forge-std/console2.sol";

contract Useful {
    function memeq(bytes memory a, bytes memory b) internal pure returns (bool) {
        return (a.length == b.length) && (keccak256(a) == keccak256(b));
    }

    function streq(string memory a, string memory b) internal pure returns (bool) {
        return memeq(bytes(a), bytes(b));
    }

    function extractUInt256(bytes memory data, uint256 pos) public pure returns (uint256 result) {
        require((pos + 256 / 8) <= data.length);
        uint256 endian = pos + 32;
        assembly {
            result := mload(add(data, endian))
        }
    }
}
