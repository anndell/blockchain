// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../interfaces/IAnndellFee.sol";
import "contracts/Anndell.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract Factory {
    constructor(IAnndellFee _anndellFee, address _implementationContract) {
        fee = _anndellFee;
        implementationContract = _implementationContract;
    }

    address public implementationContract;

    function updateImpl(address _imp) public {
        implementationContract = _imp;
    }

    mapping(address => bool) public isAnndell;
    IAnndellFee private fee;
    event CollectionCreated(address AnndellAddress, string name, string symbol, address initiator);

    function createCollection(string calldata _name, string calldata _symbol) external returns (address instance) {
        instance = Clones.clone(implementationContract);
        Anndell anndellInstance = Anndell(payable(instance));
        Anndell(anndellInstance).initialize(_name, _symbol, msg.sender, fee);
        require(instance != address(0), "Failed to create Anndell collection");
        fee.setQuote(instance);
        isAnndell[instance] = true;
        emit CollectionCreated(instance, _name, _symbol, msg.sender);
    }
}