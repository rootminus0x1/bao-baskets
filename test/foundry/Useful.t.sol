// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.1;

import {LoggingTest} from "./LoggingTest.sol";

import {Useful} from "./Useful.sol";
import {DateUtils} from "./SkeletonCodeworks/DateUtils/DateUtils.sol";

contract TestUsefulSimples is LoggingTest {
    bytes zeroA = new bytes(0);
    bytes zeroB = new bytes(0);

    bytes oneAx = "x";
    bytes oneBx = "x";
    bytes oneBy = "_";

    bytes twoAx = "xx";
    bytes twoBx = "xx";
    bytes twoBy0 = "_x";
    bytes twoByn = "x_";

    bytes thirtytwoAx = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    bytes thirtytwoBx = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    bytes thirtytwoBy0 = "_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    bytes thirtytwoBym = "xxxxxxxxxxxxxx_xxxxxxxxxxxxxxxxx";
    bytes thirtytwoByn = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx_";

    bytes bigAx = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    bytes bigBx = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    bytes bigBy0 = "_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    bytes bigBym = "xxxxxxxxxxxxxx_xxxxxxxxxxxxxxxxxx";
    bytes bigByn = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx_";

    string zeroAS = "";
    string zeroBS = "";

    string oneAxS = "x";
    string oneBxS = "x";
    string oneByS = "_";

    string twoAxS = "xx";
    string twoBxS = "xx";
    string twoBy0S = "_x";
    string twoBynS = "x_";

    string thirtytwoAxS = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    string thirtytwoBxS = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    string thirtytwoBy0S = "_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    string thirtytwoBymS = "xxxxxxxxxxxxxx_xxxxxxxxxxxxxxxxx";
    string thirtytwoBynS = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx_";

    string bigAxS = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    string bigBxS = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    string bigBy0S = "_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    string bigBymS = "xxxxxxxxxxxxxx_xxxxxxxxxxxxxxxxxx";
    string bigBynS = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx_";

    function test_memory() public {
        // zero length
        assertTrue(Useful.memeq(zeroA, zeroA), "zero length bytes are equal");
        assertTrue(Useful.memeq(zeroA, zeroB), "zero length bytes are equal");

        assertTrue(Useful.memeq(oneAx, oneAx));
        assertTrue(Useful.memeq(oneAx, oneBx));
        assertTrue(!Useful.memeq(oneAx, oneBy));

        assertTrue(Useful.memeq(twoAx, twoAx));
        assertTrue(Useful.memeq(twoAx, twoBx));
        assertTrue(!Useful.memeq(twoAx, twoBy0));
        assertTrue(!Useful.memeq(twoAx, twoByn));

        assertTrue(Useful.memeq(thirtytwoAx, thirtytwoAx));
        assertTrue(Useful.memeq(thirtytwoAx, thirtytwoBx));
        assertTrue(!Useful.memeq(thirtytwoAx, thirtytwoBy0));
        assertTrue(!Useful.memeq(thirtytwoAx, thirtytwoBym));
        assertTrue(!Useful.memeq(thirtytwoAx, thirtytwoByn));

        assertTrue(Useful.memeq(bigAx, bigAx));
        assertTrue(Useful.memeq(bigAx, bigBx));
        assertTrue(!Useful.memeq(bigAx, bigBy0));
        assertTrue(!Useful.memeq(bigAx, bigBym));
        assertTrue(!Useful.memeq(bigAx, bigByn));
    }

    function test_string() public {
        // zero length
        assertTrue(Useful.streq(zeroAS, zeroAS), "zero length bytes are equal");
        assertTrue(Useful.streq(zeroAS, zeroBS), "zero length bytes are equal");

        assertTrue(Useful.streq(oneAxS, oneAxS));
        assertTrue(Useful.streq(oneAxS, oneBxS));
        assertTrue(!Useful.streq(oneAxS, oneByS));

        assertTrue(Useful.streq(twoAxS, twoAxS));
        assertTrue(Useful.streq(twoAxS, twoBxS));
        assertTrue(!Useful.streq(twoAxS, twoBy0S));
        assertTrue(!Useful.streq(twoAxS, twoBynS));

        assertTrue(Useful.streq(thirtytwoAxS, thirtytwoAxS));
        assertTrue(Useful.streq(thirtytwoAxS, thirtytwoBxS));
        assertTrue(!Useful.streq(thirtytwoAxS, thirtytwoBy0S));
        assertTrue(!Useful.streq(thirtytwoAxS, thirtytwoBymS));
        assertTrue(!Useful.streq(thirtytwoAxS, thirtytwoBynS));

        assertTrue(Useful.streq(bigAxS, bigAxS));
        assertTrue(Useful.streq(bigAxS, bigBxS));
        assertTrue(!Useful.streq(bigAxS, bigBy0S));
        assertTrue(!Useful.streq(bigAxS, bigBymS));
        assertTrue(!Useful.streq(bigAxS, bigBynS));
    }

    function test_extractUInt256() public {
        bytes memory data = new bytes(100);
        assertEq(Useful.extractUInt256(data, 0), 0, "initialised to zero, right?");

        data[31] = 0x01;
        assertEq(Useful.extractUInt256(data, 0), 1, "little endian numbers for you");
        assertEq(Useful.extractUInt256(data, 1), 256, "offset by 1 byte is like a multiply by 2*8");

        data[30] = 0x01; // we now have
        assertEq(Useful.extractUInt256(data, 0), 257, "two byte number");

        // TODO: test beyond 32bytes
    }

    function test_toString_decimals() public {
        assertEq(Useful.toStringScaled(0, 1), "0.0");
        assertEq(Useful.toStringScaled(0, 2), "0.00");
        assertEq(Useful.toStringScaled(1, 1), "0.1");
        assertEq(Useful.toStringScaled(1, 2), "0.01");
        assertEq(Useful.toStringScaled(10, 1), "1.0");
        assertEq(Useful.toStringScaled(100, 2), "1.00");
    }

    function test_toString_thousands() public {
        assertEq(Useful.toStringThousands(0, Useful.comma), "0");
        assertEq(Useful.toStringThousands(1, Useful.comma), "1");
        assertEq(Useful.toStringThousands(100, Useful.comma), "100");
        assertEq(Useful.toStringThousands(1000, Useful.comma), "1,000");
        assertEq(Useful.toStringThousands(10000, Useful.underscore), "10_000");
        assertEq(Useful.toStringThousands(100000, Useful.comma), "100,000");
        assertEq(Useful.toStringThousands(1000000, Useful.comma), "1,000,000");
        assertEq(Useful.toStringThousands(10000000, Useful.comma), "10,000,000");
        assertEq(Useful.toStringThousands(100000000, Useful.comma), "100,000,000");

        assertEq(Useful.toStringThousands(123456789, Useful.comma), "123,456,789");

        assertEq(string("10,000"), "10,000");
        assertEq(string("100,000"), "100,000");

        assertEq(Useful.toStringThousands(0, 0), "0");
        assertEq(Useful.toStringThousands(1, 0), "1");
        assertEq(Useful.toStringThousands(100, 0), "100");
        assertEq(Useful.toStringThousands(1000, 0), "1000");
        assertEq(Useful.toStringThousands(10000, 0), "10000");
        assertEq(Useful.toStringThousands(100000, 0), "100000");
        assertEq(Useful.toStringThousands(1000000, 0), "1000000");
    }
}
