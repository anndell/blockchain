// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// factory.sol is a Solidity smart contract responsible for creating new instances of Anndell contracts, 
// the core building blocks of the Anndell tokenization platform. The Factory contract ensures that each 
// new Anndell contract is properly initialized with the required parameters such as asset details, token 
// settings, and fee settings. Additionally, factory.sol maintains a mapping of all created Anndell 
// contracts, allowing for easy verification and lookup of contract addresses on the platform. By providing 
// a standardized and efficient way to create and manage Anndell contracts, factory.sol serves as a critical 
// component in the overall Anndell ecosystem, enabling seamless growth and expansion of tokenized assets 
// on the platform.

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