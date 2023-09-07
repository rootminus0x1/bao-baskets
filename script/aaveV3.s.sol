// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.1;
pragma experimental ABIEncoderV2;

// import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import "forge-std/Script.sol";

import {LendingRegistry} from "src/LendingRegistry.sol";
import {LendingLogicAaveV3} from "src/Strategies/LendingLogicAaveV3.sol";

contract AaveV3Constants {
    address internal constant AAVELENDINGPOOLV3 = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    address private constant LUSD = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;
    address private constant AETHLUSD = 0x3Fe6a295459FAe07DF8A0ceCC36F37160FE86AA9;

    address internal constant LENDINGREGISTRY = 0x08a2b7D713e388123dc6678168656659d297d397;
    address internal constant BAOMULTISIG = 0xFC69e0a5823E2AfCBEb8a35d33588360F1496a00;

    address internal constant underlying = LUSD;
    address internal constant wrapped = AETHLUSD;
    bytes32 internal constant protocol = 0x0000000000000000000000000000000000000000000000000000000000000005;
}

/* 
deploy the lending logic yearn
$ forge script script/bTEST.s.sol:LendingLogicAaveV3Script --fork-url $MAINNET_RPC_URL --broadcast --slow --verify
*/
contract LendingLogicAaveV3Script is Script, AaveV3Constants {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        LendingLogicAaveV3 strategy = new LendingLogicAaveV3(AAVELENDINGPOOLV3, 0);

        vm.stopBroadcast();

        console.log("LendingLogicAaveV3 deployed at %s", address(strategy));
    }
}

/* 
transactions for the multisig - results in broadcast/bTEST.s.sol/1/dry-run/run-latest.json
$ forge script script/bTEST.s.sol:BTESTYearnLUSDmultisig --sig "run(address strategy)"  "0x?" --rpc-url $MAINNET_RPC_URL
*/
contract AaveV3LUSDmultisig is Script, AaveV3Constants {
    function run(address strategy) external {
        vm.startBroadcast(BAOMULTISIG);

        // create the strategy
        LendingRegistry lendingRegistry = LendingRegistry(LENDINGREGISTRY);

        // set up the lendingRegistry with the strategy
        lendingRegistry.setWrappedToProtocol(wrapped, protocol);
        lendingRegistry.setWrappedToUnderlying(wrapped, underlying);
        lendingRegistry.setProtocolToLogic(protocol, strategy);
        lendingRegistry.setUnderlyingToProtocolWrapped(underlying, protocol, wrapped);

        vm.stopBroadcast();
    }
}
