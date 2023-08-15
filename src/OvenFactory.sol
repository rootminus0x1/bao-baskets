// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/access/Ownable.sol";
import "./Oven.sol";

contract OvenFactoryContract is Ownable {
    event OvenCreated(
        address Oven,
        address Controller,
        address Pie,
        address Recipe
    );
    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address[] public ovens;
    mapping(address => bool) public isOven;
    address public defaultController;

    function setDefaultController(address _controller) external onlyOwner {
        defaultController = _controller;
    }

    function CreateEmptyOven() external {
        CreateOven(address(0), address(0));
    }

    function CreateOven(address _pie, address _recipe) public returns(Oven){
        require(defaultController != address(0), "CONTROLLER_NOT_SET");

        Oven oven = new Oven(address(this), _pie, _recipe, weth);
        ovens.push(address(oven));
        isOven[address(oven)] = true;

        oven.setCap(type(uint256).max);
        oven.setController(defaultController);
        emit OvenCreated(address(oven), defaultController, _pie, _recipe);
        return(oven);
    }
}