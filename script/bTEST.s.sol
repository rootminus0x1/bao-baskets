// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.1;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import "forge-std/Script.sol";

import {BasketFactoryContract} from "src/BasketFactoryContract.sol";
import {BasketRegistry} from "src/BasketRegistry.sol";
import {LendingRegistry} from "src/LendingRegistry.sol";
import {LendingLogicYearn} from "src/Strategies/LendingLogicYearn.sol";
import {LendingManager} from "src/LendingManager.sol";
import {IExperiPie} from "src/Interfaces/IExperiPie.sol";

contract BTESTYearnLUSDConstants {
    address private constant LUSD = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;
    address private constant YVLUSD = 0x378cb52b00F9D0921cb46dFc099CFf73b42419dC; // 5
    address internal constant BASKETFACTORY = 0xe1e7634Cd2AED55C6aAA704299E735987f372b70;
    address internal constant BASKETREGISTRY = 0x51801401e1f21c9184610b99B978D050a374566E;
    address internal constant LENDINGREGISTRY = 0x08a2b7D713e388123dc6678168656659d297d397;
    address internal constant BAOMULTISIG = 0xFC69e0a5823E2AfCBEb8a35d33588360F1496a00;

    //uint256 private constant MIN_AMOUNT = 10 ** 6;
    uint256 internal constant amount = 100 * 1e18;

    address internal constant underlying = LUSD;
    address internal constant wrapped = YVLUSD;
    bytes32 internal constant protocol = 0x0000000000000000000000000000000000000000000000000000000000000004;
}

contract BTESTScript is Script, BTESTYearnLUSDConstants {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        BasketFactoryContract factory = BasketFactoryContract(BASKETFACTORY);

        // create a new basket
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = underlying;
        amounts[0] = amount;
        string memory symbol = "bTEST";
        string memory name = "Bao Test Basket";

        // allow the transfer to the basket
        IERC20(underlying).approve(address(factory), amount);

        // make a basket
        factory.bakeBasket(tokens, amounts, amount, symbol, name);
        vm.stopBroadcast();
    }
}

contract LendingLogicYearnScript is Script, BTESTYearnLUSDConstants {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        LendingLogicYearn strategy = new LendingLogicYearn(LENDINGREGISTRY, protocol);

        vm.stopBroadcast();

        // console.log("LendingLogivYearn deployed at %s", address(strategy));
    }
}

contract BTESTLendingManagerScript is Script, BTESTYearnLUSDConstants {
    address internal basket;

    constructor(address _basket) {
        basket = _basket;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // create a lending manager and connect the basket & lending Manager to it
        LendingManager manager = new LendingManager(LENDINGREGISTRY, basket);
        manager.transferOwnership(BAOMULTISIG);

        vm.stopBroadcast();
        console.log("LendingManager for bTEST deployed at %s", address(manager));
    }
}

contract BTESTYearnLUSDmultisig is Script, BTESTYearnLUSDConstants {
    address internal basket;
    address internal strategy;
    address internal manager;

    constructor(address _basket, address _strategy, address _manager) {
        basket = _basket;
        strategy = _strategy;
        manager = _manager;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // add the basket to the basket registry
        BasketRegistry basketRegistry = BasketRegistry(BASKETREGISTRY);
        basketRegistry.addBasket(basket);

        // create the strategy
        LendingRegistry lendingRegistry = LendingRegistry(LENDINGREGISTRY);

        // set up the lendingRegistry with the strategy
        lendingRegistry.setWrappedToProtocol(wrapped, protocol);
        lendingRegistry.setWrappedToUnderlying(wrapped, underlying);
        lendingRegistry.setProtocolToLogic(protocol, strategy);
        lendingRegistry.setUnderlyingToProtocolWrapped(underlying, protocol, wrapped);

        // set up this as a caller of lend/unlend, etc.
        IExperiPie(basket).addCaller(address(manager));

        vm.stopBroadcast();
    }
}
