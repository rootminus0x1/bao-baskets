// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.7.1;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {console2 as console} from "forge-std/console2.sol";
import {Test, Vm} from "forge-std/Test.sol";

import {BasketFactoryContract} from "src/BasketFactoryContract.sol";
import {LendingRegistry} from "src/LendingRegistry.sol";
import {LendingLogicYearn} from "src/Strategies/LendingLogicYearn.sol";
import {LendingManager} from "src/LendingManager.sol";
import "src/Interfaces/IExperiPie.sol";

import {Deployed, ChainStateLending} from "./Deployed.sol";

// this test is added to make sure the test harness below is doing the right thing versus an existing basket
// TODO: obs
contract TestBSTBL is ChainStateLending {
    LendingManager manager;

    constructor() {
        manager = LendingManager(Deployed.LENDINGMANAGERBSTBL);
    }

    function test_lend() public {
        // TODO: manager.lend(...) etc.
    }
}

contract BasketLUSDSetUp is ChainStateLending {
    uint256 constant percent100 = 1e18;
    uint256 constant totalAmount = 6000 * 1e18; // 6 grand LUSD
    uint256 constant lendAmount = 4000 * 1e18; // 4 grand LUSD
    uint256 constant initialSupply = 7000 * 1e18; // 7 grand bTEST

    address basket;
    address defaultController;
    address wallet;

    address wrapped = Deployed.YVLUSD;
    address underlying = Deployed.LUSD;
    bytes32 protocol = 0x0000000000000000000000000000000000000000000000000000000000000006;

    LendingManager manager;

    constructor() {
        wrapped = Deployed.YVLUSD;
        underlying = Deployed.LUSD;
        wallet = address(this);
    }

    function test_setUp() public {
        BasketFactoryContract factory = BasketFactoryContract(Deployed.BASKETFACTORY);
        defaultController = factory.defaultController();
        console.log("default controller=%s", defaultController);
        // create a new basket
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = Deployed.LUSD;
        amounts[0] = totalAmount;
        string memory symbol = "bTEST";
        string memory name = "test Bao Basket";

        // give us the dosh to set up the basket
        deal(underlying, wallet, totalAmount);
        assertEq(IERC20(underlying).balanceOf(wallet), totalAmount, "didn't deal correctly");
        IERC20(underlying).approve(address(factory), totalAmount);
        assertEq(IERC20(underlying).allowance(wallet, address(factory)), totalAmount, "didn't approve correctly");

        // make a basket
        factory.bakeBasket(tokens, amounts, initialSupply, symbol, name);
        assertEq(IERC20(underlying).balanceOf(wallet), 0, "baking didn't take the underlying (tokens array)");
        // find its address, it's the last one created
        // (assuming nothing else is creating them at the same time)
        for (uint256 b = 0;; b++) {
            try factory.baskets(b) returns (address tryBasket) {
                basket = tryBasket; // the basket is the last one
            } catch {
                break; // we've reached the end of the array
            }
        }
        // check creator has the initial supply of basket tokens
        assertEq(IERC20(basket).balanceOf(wallet), initialSupply, "baking didn't transfer the basket");
        assertEq(
            IERC20(underlying).balanceOf(basket),
            totalAmount,
            "basket should have amount (array) of the underlying (token array)"
        );

        // create a lending registry and set up the strategy
        LendingRegistry registry = new LendingRegistry();
        LendingLogicYearn strategy = new LendingLogicYearn(address(registry), protocol);

        // set up the registry
        registry.setWrappedToProtocol(wrapped, protocol);
        registry.setWrappedToUnderlying(wrapped, underlying);
        registry.setProtocolToLogic(protocol, address(strategy));
        registry.setUnderlyingToProtocolWrapped(underlying, protocol, wrapped);

        // create a lending manager and connect the basket & lending Manager to it
        manager = new LendingManager(address(registry), basket);

        // set up this as a caller of lend/unlend, etc.
        vm.prank(defaultController);
        IExperiPie(basket).addCaller(address(manager));
    }
}

contract BasketLUSD is BasketLUSDSetUp {
    function test_basketLUSD() public {
        test_setUp();

        assertEq(IERC20(underlying).balanceOf(basket), totalAmount, "basket should have all the underlying");
        assertEq(IERC20(wrapped).balanceOf(basket), 0, "basket should have no wrapped");
        assertEq(IERC20(basket).balanceOf(wallet), initialSupply, "wallet should have initial suppy of bTEST");

        manager.lend(underlying, lendAmount, protocol);
        // basket goes down by amount of underlying and up by a similar amount of wrapped
        assertEq(
            IERC20(underlying).balanceOf(basket),
            totalAmount - lendAmount,
            "lending doesn't reduce basket by correct amount of underlying"
        );
        uint256 lendAmountWrapped = IERC20(wrapped).balanceOf(basket);
        assertApproxEqRel(
            lendAmountWrapped,
            lendAmount,
            percent100 / 10,
            "lending doesn't increase basket by correct amount of wrapped"
        );

        // opposite of lend :-)
        uint256 unlendAmountWrapped = lendAmountWrapped / 2;
        uint256 unlendAmount = lendAmount / 2;
        manager.unlend(wrapped, unlendAmountWrapped);
        assertApproxEqAbs(
            IERC20(underlying).balanceOf(basket),
            totalAmount - lendAmount + unlendAmount,
            1, // allow for rounding/truncation errors
            "unlending doesn't increase basket by correct amount of underlying"
        );
        assertApproxEqAbs(
            IERC20(wrapped).balanceOf(basket),
            lendAmountWrapped - unlendAmountWrapped,
            1, // allow for rounding/truncation errors
            "unlending doesn't reduce basket by correct amount of wrapped"
        );

        // manager.bounce(wrapped, amount, _toProtocol);
        // same as unlend(wrapped, amount), lend(underlying, type(uint256).max, protocol);
    }
}
