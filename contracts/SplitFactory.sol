// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "contracts/AnndellSplit.sol";
import "../interfaces/IAnndellFee.sol";
import "../interfaces/IFactory.sol";
import "../interfaces/IAnndell.sol";

contract SplitFactory {
    constructor(IAnndellFee _anndellFee, IFactory _factory, address _implementationContract) {
        fee = _anndellFee;
        factory = _factory;
        implementationContract = _implementationContract;
    }

    address public implementationContract;

    function updateImpl(address _imp) public {
        implementationContract = _imp;
    }

    IAnndellFee private fee;
    IFactory private factory;

    mapping (address => address) public subLevel;

    event SplitCollectionCreated(address AnndellSplitAddress, IAnndell root, address parent, uint splitLevel, address initiator);

    function createSplitCollection(IAnndell _root) external returns (address instance) {
        require(factory.isAnndell(address(_root)), "Not anndell contract");
        address parent = address(_root);
        uint splitLevel = 1;
        while(subLevel[parent] != address(0)){
            parent = subLevel[parent];
            splitLevel *= 10;
        }
        splitLevel *= 10;
        instance = Clones.clone(implementationContract);
        AnndellSplit anndellSplitInstance = AnndellSplit(payable(instance));
        AnndellSplit(anndellSplitInstance).initialize(_root, parent, fee, splitLevel);
        require(instance != address(0), "Failed to create AnndellSplit collection");
        fee.setQuote(instance);
        subLevel[parent] = instance;
        emit SplitCollectionCreated(instance, _root, parent, splitLevel, msg.sender);
    }
}