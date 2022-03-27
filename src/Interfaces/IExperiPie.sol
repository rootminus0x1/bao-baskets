// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "./IERC173.sol";
import "./IBasketFacet.sol";
import "./IERC20Facet.sol";
import "./ICallFacet.sol";

/**
    @title ExperiPie Interface
    @dev Combines all ExperiPie facet interfaces into one
*/
interface IExperiPie is IERC20, IBasketFacet, IERC20Facet, IERC173, ICallFacet {
}
