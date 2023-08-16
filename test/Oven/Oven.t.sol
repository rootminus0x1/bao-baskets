pragma solidity ^0.7.0;

pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "src/Recipes/Recipe.sol";
import "../BasketsTestSuite.sol";

contract OvenTest is Test {

    BasketsTestSuite public testSuite;
    Oven public oven;
    Recipe public recipe;

    function setUp() public {
        testSuite = new BasketsTestSuite();
        startHoax(address(testSuite));
        oven = testSuite.bSTBLOven();
        recipe = testSuite.recipe();
    }

    function testFailOvenCap() public {
        oven.setCap(1e18);
        oven.deposit{value : (1e18 + 1)}();
    }

    function testOvenDeposit() public {
        oven.setCap(1e18);
        oven.deposit{value : 1e18}();
        assertEq(oven.ethBalanceOf(address(testSuite)), 1e18);
    }

    function testOvenWithdrawETH() public {
        uint256 initialBalance = address(this).balance;

        oven.deposit{value : 1e18}();
        oven.withdrawETH(1e18, payable(address(testSuite)));
        assertEq(oven.ethBalanceOf(address(testSuite)), 0);
        assertEq(address(this).balance, initialBalance);
    }

    function testOvenBake() public {
        // skip this test because we don't use Recipe. Use SimpleUniRecipe instead
        // SimpleUniRecipe has no getPricePie function so it wont work with it anyway
        // TODO: have a OvenTest that works with SimpleUniRecipe
        vm.skip(true);

        (uint256 mintPrice, uint16[] memory dexIndex) = recipe.getPricePie(testSuite.bSTBL(), 1e18);

        oven.deposit{value : mintPrice}();

        IERC20 basket = IERC20(testSuite.bSTBL());

        address[] memory receivers = new address[](1);
        receivers[0] = address(testSuite);
        uint initialBalance = basket.balanceOf(address(testSuite));
        console.log("got balanceOf");
        oven.bake(receivers, 1e18, mintPrice);
        console.log("baked");

        oven.withdrawOutput(address(testSuite));
        console.log("withdrawn output");

        assertEq(basket.balanceOf(address(testSuite)), initialBalance + 1e18);
    }
}