// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.1;

import {console2 as console} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

import {Useful} from "./Useful.sol";
import {DateUtils} from "./SkeletonCodeworks/DateUtils/DateUtils.sol";

contract LoggingTest is Test {
    bool private logging;
    bool[] private previousLoggingStates;

    constructor() {
        previousLoggingStates.push(false);
        logging = vm.envOr("LOG", false);
        clog("LOG = '%s'", logging);
    }

    //
    // logging switching manamgement
    //
    // startLogging and popLogging
    function startLogging(string memory name) public {
        bool prevLogging = logging;
        logging = true;
        clog(name, string("..."));
        previousLoggingStates.push(prevLogging);
    }

    function startLogging() public {
        startLogging("");
    }

    function popLogging() public {
        logging = previousLoggingStates[previousLoggingStates.length - 1];
        previousLoggingStates.pop();
        clog("done.");
    }

    function addIndent(string memory format) private view returns (string memory indented) {
        indented = format;
        for (uint256 i = 0; i < previousLoggingStates.length; i++) {
            indented = Useful.concat("  ", indented);
        }
    }

    function clog(string memory format) public view {
        if (logging) console.log(addIndent(format));
    }

    function clog(string memory format, address d) public view {
        if (logging) console.log(addIndent(format), d);
    }

    function clog(string memory format, string memory d) public view {
        if (logging) console.log(addIndent(format), d);
    }

    function clog(string memory format, bytes32 d) public view {
        if (logging) console.log(addIndent(format), uint256(d));
    }

    function clog(string memory format, bytes memory d) public view {
        if (logging) {
            console.log(addIndent(format), "->");
            console.logBytes(d); // TODO: somehow add indent
        }
    }

    function clog(string memory format, bool d) public view {
        if (logging) console.log(addIndent(format), d);
    }

    function clog(string memory format, uint256 d) public view {
        if (logging) console.log(addIndent(format), d);
    }

    function clog(string memory format, int256 d) public view {
        if (logging) console.log(addIndent(format), d);
    }

    function clog(string memory format, address d, address d2) public view {
        if (logging) console.log(addIndent(format), d, d2);
    }

    function clog(string memory format, uint256 d, uint256 d2) public view {
        if (logging) console.log(addIndent(format), d, d2);
    }

    function clog(string memory format, string memory d, string memory d2) public view {
        if (logging) console.log(addIndent(format), d, d2);
    }

    function clog(string memory format, string memory d, uint256 d2) public view {
        if (logging) console.log(addIndent(format), d, d2);
    }
}
