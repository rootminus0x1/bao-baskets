// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity >=0.7.1;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {console2 as console} from "forge-std/console2.sol";
import {Test, Vm} from "forge-std/Test.sol";

import {BasketFactoryContract} from "src/BasketFactoryContract.sol";
import {PProxy} from "src/Diamond/PProxy.sol";
import {BasketRegistry} from "src/BasketRegistry.sol";
import {LendingRegistry} from "src/LendingRegistry.sol";
import {LendingLogicYearn} from "src/Strategies/LendingLogicYearn.sol";
import {LendingManager} from "src/LendingManager.sol";
import "src/Interfaces/IExperiPie.sol";
import "src/Diamond/BasketFacet.sol";

import {ChainState} from "./ChainState.sol";
import {ChainStateLending} from "./ChainStateLending.sol";
import {Deployed} from "test/Deployed.sol";

contract bTESTDeployerTest is ChainState {
    bytes32 private protocol = 0x0000000000000000000000000000000000000000000000000000000000000004;

    function test_deploy() public {
        address basket = test_deploybTEST();
        address strategy = test_deployStrategy();
        address manager = test_deployLendingManager(basket);
        test_multisig(basket, strategy, manager);
    }

    function test_deploybTEST() private returns (address) {
        // there's a minimum amount of underlying that must be in the wallet
        // it comes from the BasketFacet and exists to deal with rounding errors
        // beats me how that deals with rounding errors as rounding errors are inherent
        // in any kind of non-infinite precision number representation
        // in a real deploy this must be in the wallet :-(
        BasketFacet basketFacet = new BasketFacet();
        //uint256 MIN_AMOUNT = basketFacet.MIN_AMOUNT();

        // get some dosh
        uint256 amount = 1e20;
        deal(Deployed.LUSD, address(this), amount);

        BasketFactoryContract factory = BasketFactoryContract(Deployed.BASKETFACTORY);
        IERC20(Deployed.LUSD).approve(address(factory), amount);

        // create a new basket
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = Deployed.LUSD;
        amounts[0] = amount;
        string memory symbol = "bTEST";
        string memory name = "test Bao Basket";

        // allow the transfer to the basket
        IERC20(Deployed.LUSD).approve(address(factory), amount);

        // make a basket
        factory.bakeBasket(tokens, amounts, amount, symbol, name);

        // get the address
        address basket = address(0);
        for (uint256 b = 0;; b++) {
            try factory.baskets(b) returns (address tryBasket) {
                basket = tryBasket; // the basket is the last one
            } catch {
                break; // we've reached the end of the array
            }
        }
        return basket;
    }

    function test_deployStrategy() private returns (address strategy) {
        LendingLogicYearn strategyObj = new LendingLogicYearn(Deployed.LENDINGREGISTRY, protocol);
        strategy = address(strategyObj);
        // strategyObj.transferOwnership(Deployed.BAOMULTISIG);
    }

    function test_deployLendingManager(address basket) private returns (address) {
        // create a lending manager and connect the basket & lending Manager to it
        LendingManager manager = new LendingManager(Deployed.LENDINGREGISTRY, basket);
        manager.transferOwnership(Deployed.BAOMULTISIG);
        return address(manager);
    }

    function test_multisig(address basket, address strategy, address manager) private {
        vm.startPrank(Deployed.BAOMULTISIG);

        // add the basket to the basket registry
        BasketRegistry basketRegistry = BasketRegistry(Deployed.BASKETREGISTRY);
        basketRegistry.addBasket(basket);

        // create the strategy
        LendingRegistry lendingRegistry = LendingRegistry(Deployed.LENDINGREGISTRY);

        // set up the lendingRegistry with the strategy
        lendingRegistry.setWrappedToProtocol(Deployed.YVLUSD, protocol);
        lendingRegistry.setWrappedToUnderlying(Deployed.YVLUSD, Deployed.LUSD);
        lendingRegistry.setProtocolToLogic(protocol, address(strategy));
        lendingRegistry.setUnderlyingToProtocolWrapped(Deployed.LUSD, protocol, Deployed.YVLUSD);

        // set up this as a caller of lend/unlend, etc.
        IExperiPie(basket).addCaller(manager);

        vm.stopPrank();
    }
}

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
        assertEq(factory.defaultController(), Deployed.BAOMULTISIG, "controller needs to be multisig");

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
        // check basket ownership is set up correctly
        //PProxy basketProxy = PProxy(basket);
        assertEq(IExperiPie(basket).owner(), Deployed.BAOMULTISIG, "basket should be owned by multisig");

        // add the basket to the basket registry
        BasketRegistry basketRegistry = BasketRegistry(Deployed.BASKETREGISTRY);
        vm.prank(Deployed.BAOMULTISIG);
        basketRegistry.addBasket(basket);
        bool found = false;
        for (uint256 b = 0;; b++) {
            try basketRegistry.entries(b) returns (address tryBasket) {
                if (basket == tryBasket) {
                    found = true;
                    break;
                }
            } catch {
                break; // we've reached the end of the array
            }
        }
        assertTrue(found, "basket should be registered");

        // create the strategy
        LendingRegistry lendingRegistry = LendingRegistry(Deployed.LENDINGREGISTRY);
        LendingLogicYearn strategy = new LendingLogicYearn(address(lendingRegistry), protocol);
        // strategy.transferOwnership(Deployed.BAOMULTISIG);

        // set up the lendingRegistry with the strategy
        vm.startPrank(Deployed.BAOMULTISIG);
        lendingRegistry.setWrappedToProtocol(wrapped, protocol);
        lendingRegistry.setWrappedToUnderlying(wrapped, underlying);
        lendingRegistry.setProtocolToLogic(protocol, address(strategy));
        lendingRegistry.setUnderlyingToProtocolWrapped(underlying, protocol, wrapped);
        vm.stopPrank();

        // create a lending manager and connect the basket & lending Manager to it
        manager = new LendingManager(address(lendingRegistry), basket);
        manager.transferOwnership(Deployed.BAOMULTISIG);

        // set up this as a caller of lend/unlend, etc.
        vm.prank(Deployed.BAOMULTISIG);
        IExperiPie(basket).addCaller(address(manager));
    }
}

contract BasketLUSD is BasketLUSDSetUp {
    function test_basketLUSD() public {
        test_setUp();

        assertEq(IERC20(underlying).balanceOf(basket), totalAmount, "basket should have all the underlying");
        assertEq(IERC20(wrapped).balanceOf(basket), 0, "basket should have no wrapped");
        assertEq(IERC20(basket).balanceOf(wallet), initialSupply, "wallet should have initial suppy of bTEST");

        vm.prank(Deployed.BAOMULTISIG);
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
        vm.prank(Deployed.BAOMULTISIG);
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
