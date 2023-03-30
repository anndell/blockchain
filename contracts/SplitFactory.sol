// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// splitfactory.sol is a Solidity smart contract that facilitates the creation of Anndell Split Collections, 
// a key feature in the Anndell ecosystem that allows for the subdivision and organization of tokenized 
// assets. This factory contract ensures that each Split Collection created adheres to the platform's 
// standards and is properly initialized with the necessary parameters, such as the root Anndell contract, 
// parent address, fee settings, and split levels. By emitting an event upon the successful creation of 
// a Split Collection, splitfactory.sol enables transparent tracking and monitoring of the platform's 
// growth and expansion, while also providing a streamlined and efficient mechanism for creating new 
// Split Collections within the Anndell ecosystem.

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