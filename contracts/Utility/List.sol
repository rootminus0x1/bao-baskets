// SPDX-License-Identifier: UNLICENSED
pragma experimental ABIEncoderV2;
pragma solidity ^0.7.1;

interface IList {
    function contains(address element) external view returns (bool);
    function remove(address element) external;
    function insert(address element) external;
    function getElements() external view returns (address[] memory result);
}

contract MapList is IList {
    // this is a mapping of wrapped to a circular linked list of strategies
    //   thanks to https://medium.com/bandprotocol/solidity-102-2-o-1-iterable-map-8d905298c1bc
    mapping(address => address) public elements;
    address private constant GUARD = address(1);

    function contains(address element) public view override returns (bool) {
        // assumes the list is initialised
        return elements[element] != address(0);
    }

    function remove(address element) public override {
        // when strategies are revoked in Yearn, this event is generated:
        //   StrategyRevoked(element (indexed))

        // if not an empty list and the list contains 'element'
        if (elements[GUARD] != address(0) && elements[element] != address(0)) {
            address prev = GUARD; // start at the head
            while (elements[prev] != GUARD) {
                // not at the tail
                if (elements[prev] == element) {
                    // found the prev element to unlink
                    elements[prev] = elements[element];
                    elements[element] = address(0);
                    break;
                }
                prev = elements[prev];
            }
        }
    }

    function insert(address element) public override {
        if (elements[GUARD] == address(0)) {
            // empty list, initialise with one entry
            elements[element] = GUARD;
            elements[GUARD] = element;
        } else if (elements[element] == address(0)) {
            // it's not in the list, so add it at the head
            elements[element] = elements[GUARD];
            elements[GUARD] = element;
        }
    }

    function getElements() public view override returns (address[] memory result) {
        address currentStrategy = elements[GUARD];
        if (currentStrategy == address(0)) {
            // uninitialised list, so no entries
            return new address[](0);
        }
        // get length, could be 0 is current element is GUARD
        uint256 length = 0;
        while (currentStrategy != GUARD) {
            length++;
            currentStrategy = elements[currentStrategy];
        }

        result = new address[](length);
        currentStrategy = elements[GUARD];
        length = 0;
        while (currentStrategy != GUARD) {
            result[length] = currentStrategy;
            currentStrategy = elements[currentStrategy];
            length++;
        }

        return result;
    }
}

contract ArrayList is IList {
    address[] public elements;

    function _indexOf(address element) internal view returns (bool found, uint256 index) {
        found = false;
        for (index = 0; index < elements.length; index++) {
            if (elements[index] == element) {
                found = true;
                break;
            }
        }
    }

    function contains(address element) public view override returns (bool found) {
        (found,) = _indexOf(element);
    }

    function remove(address element) public override {
        // when strategies are revoked in Yearn, this event is generated:
        //   StrategyRevoked(element (indexed))
        (bool found, uint256 index) = _indexOf(element);
        if (found) {
            if (index < elements.length - 1) {
                // copy the last one over it
                elements[index] = elements[elements.length - 1];
            }
            // shorten the array
            elements.pop();
        }
    }

    function insert(address element) public override {
        (bool found,) = _indexOf(element);
        if (!found) {
            elements.push(element);
        }
    }

    function getElements() public view override returns (address[] memory result) {
        result = new address[](elements.length);
        for (uint256 index = 0; index < elements.length; index++) {
            result[index] = elements[index];
        }
    }
}
