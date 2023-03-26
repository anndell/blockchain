// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./AnndellSplit.sol";
import "../interfaces/IAnndellFee.sol";
import "../interfaces/IFactory.sol";

contract Factory {
    constructor(IAnndellFee _anndellFee, IFactory _factory) {
        fee = _anndellFee;
        factory = _factory;
    }

    IAnndellFee private fee;
    IFactory private factory;

    mapping (address => address) public subLevel;

    event SplitCollectionCreated(address AnndellSplitAddress, address root, address parent, uint splitLevel, address initiator);

    function createSplitCollection(address _root) external returns (address collection) {
        require(factory.isAnndell(_root), "Not anndell contract");
        address parent = _root;
        uint splitLevel = 1;
        while(subLevel[parent] != address(0)){
            parent = subLevel[parent];
            splitLevel *= 10;
        }
        splitLevel *= 10;
        bytes memory bytecode = abi.encodePacked(
            type(AnndellSplit).creationCode,
            abi.encode(_root, parent, fee, splitLevel)
        );
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, parent, block.timestamp));
        assembly {
            collection := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        require(collection != address(0), "Failed to create Anndell collection");
        fee.setQuote(collection);
        subLevel[parent] = collection;
        emit SplitCollectionCreated(collection, _root, parent, splitLevel, msg.sender);
    }
}