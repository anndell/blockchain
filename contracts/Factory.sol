// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Anndell.sol";
import "../interfaces/IAnndellFee.sol";

contract Factory {
    constructor(IAnndellFee _anndellFee) {
        fee = _anndellFee;
    }

    mapping(address => bool) public isAnndell;

    IAnndellFee private fee;

    event CollectionCreated(address AnndellAddress, string name, string symbol, address initiator);

    function createCollection(string calldata _name, string calldata _symbol) external returns (address collection) {
        bytes memory bytecode = abi.encodePacked(
            type(Anndell).creationCode,
            abi.encode(_name, _symbol, msg.sender, fee)
        );
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, _symbol, block.timestamp));
        assembly {
            collection := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        require(collection != address(0), "Failed to create Anndell collection");
        fee.setQuote(collection);
        isAnndell[collection] = true;
        emit CollectionCreated(collection, _name, _symbol, msg.sender);
    }
}