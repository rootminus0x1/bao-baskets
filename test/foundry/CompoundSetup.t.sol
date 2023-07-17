// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.1;

// solhint-disable func-name-mixedcase
// solhint-disable no-console
import {console2 as console} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

import {LendingRegistry} from "contracts/LendingRegistry.sol";

import {Deployed} from "./Deployed.sol";
import {Useful} from "./Useful.sol";

contract ForkingAndContractConnection is Test, Deployed {
    uint256 public mainnetFork;
    uint256 public constant BLOCKNUMBER = 17697898;

    address private zeroAddress = 0x0000000000000000000000000000000000000000;
    address private nonZeroAddress = 0x0000000000000000000000000000000000000001;
    bytes32 private zeroBytes32 = 0x0000000000000000000000000000000000000000000000000000000000000000;
    uint256 private zeroBigNumber = 0;

    LendingRegistry public lendingRegistry;

    function setUp() public {
        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
    }

    function test_ForkIsGood() public {
        vm.selectFork(mainnetFork);
        assertEq(vm.activeFork(), mainnetFork);

        vm.rollFork(BLOCKNUMBER);
        assertEq(block.number, BLOCKNUMBER);
    }

    function test_LendingRegistryBasics() public {
        vm.selectFork(mainnetFork);
        vm.rollFork(BLOCKNUMBER);
        lendingRegistry = LendingRegistry(Deployed.LENDINGREGISTRY);

        assertEq(lendingRegistry.owner(), Deployed.OWNER);

        uint256 bestApr;
        bytes32 bestProtocol;
        bytes32[] memory selectedProtocols;
        (bestApr, bestProtocol) = lendingRegistry.getBestApr(zeroAddress, selectedProtocols);

        assertEq(bestApr, zeroBigNumber);
        assertEq(bestProtocol, zeroBytes32);
    }
}

contract Compound is Test, Deployed, Useful {
    uint256 public mainnetFork;
    uint256 public constant BLOCKNUMBER = 17697898; // https://etherscan.io/block/17697898

    LendingRegistry public lendingRegistry;

    bool public logging = true;

    constructor() {
        LendingRegistry(Deployed.LENDINGREGISTRY);
    }

    function setUp() public {
        // logging = !streq(vm.envString("LOG"), "");
        // if (logging) console.log("LOG = '%s'", vm.envString("LOG"));
        if (logging) console.log(vm.envString("MAINNET_RPC_URL"));

        mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);
        vm.rollFork(BLOCKNUMBER);

        lendingRegistry = LendingRegistry(Deployed.LENDINGREGISTRY);
    }

    function test_LendingRegistry() public {
        assertEq(lendingRegistry.owner(), Deployed.OWNER);

        // event WrappedToUnderlyingSet(address indexed wrapped, address indexed underlying);
        // event ProtocolToLogicSet(bytes32 indexed protocol, address indexed logic);
        // event UnderlyingToProtocolWrappedSet(address indexed underlying, bytes32 indexed protocol, address indexed wrapped);

        // mapping(address => address) public wrappedToUnderlying;
        // mapping(address => mapping(bytes32 => address)) public underlyingToProtocolWrapped;
        // Maps protocol to addresses containing lend and unlend logic
        // mapping(bytes32 => address) public protocolToLogic;
    }

    /*

    event WrappedToProtocolSet(address indexed wrapped, bytes32 indexed protocol);




    function test_Emits() public {
        vm.expectEmit(true, true, false, false);
        // expected event
        emit WrappedToProtocolSet(zeroAddress, zeroBytes32);
        // actual event
        lendingRegistry.setWrappedToProtocol(zeroAddress, zeroBytes32);
    }

    function testFail_CallerIsNotOwner() public {
        vm.prank(address(0));
        lendingRegistry.setWrappedToProtocol(zeroAddress, zeroBytes32);
    }

    function test_RevertWhen_CallerIsNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0));
        lendingRegistry.setWrappedToProtocol(zeroAddress, zeroBytes32);
    }
    */
}
