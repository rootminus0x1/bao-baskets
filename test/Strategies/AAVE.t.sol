pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "./LendingLogic.t.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";
import "src/Strategies/LendingLogicAaveV2.sol";

contract AAVEStrategyTest is Test, LendingLogicTest {
    ERC20 public RAI;
    ERC20 public aRAI;

    constructor() LendingLogicTest() {
        //lendingLogic = testSuite.lendingLogicAave();
        lendingLogic = new LendingLogicAaveV2(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9, 0);
    }

    function setUp() public {
        RAI = ERC20(0x03ab458634910AaD20eF5f1C8ee96F1D6ac54919);
        aRAI = ERC20(0xc9BC48c72154ef3e5425641a3c747242112a46AF);

        deal(address(RAI), address(this), 1e20);
    }

    function testLendUnlend() public {
        uint256 raiBalance = RAI.balanceOf(address(this));

        lend(address(RAI), raiBalance, address(this));

        uint256 actual = aRAI.balanceOf(address(this));
        uint256 expected = raiBalance * lendingLogic.exchangeRate(address(aRAI)) / 1 ether;
        assertEq(actual, expected);

        unlend(address(aRAI), actual, address(this));

        actual = RAI.balanceOf(address(this));
        expected = raiBalance;
        assertEq(actual, expected);
    }
}
