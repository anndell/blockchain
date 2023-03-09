// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../contracts/Settings.sol";

abstract contract Whitelist is Settings{
    
    bytes32 public constant WHITELIST = keccak256("WHITELIST");

    mapping(address => bool) public whitelist;

    Whitelist public whitelistAddress;

    event AddToWhitelist(address indexed wallet);
    event RemoveFromWhitelist(address indexed wallet);
    event ChangeWhitelist(address old, address _new);
    event TransferWhiteListRequired (bool on);
    event ClaimWhiteListRequired (bool on);
    event TransferBlocked (bool on);

    modifier notLocked(){
        require(!whitelistStateLocked, "Whitelist state has been locked");
        _;
    }

    function addToWhitelist(address[] calldata _addresses) public onlyRole(WHITELIST) {
        for (uint256 index = 0; index < _addresses.length; index++) {
            whitelist[_addresses[index]] = true;
            emit AddToWhitelist(_addresses[index]);
        }
    }

    function removeFromWhitelist(address[] calldata _addresses) public onlyRole(WHITELIST) {
        for (uint256 index = 0; index < _addresses.length; index++) {
            whitelist[_addresses[index]] = false;
            emit RemoveFromWhitelist(_addresses[index]);
        }
    }

    function setTransferWL(bool _on) public onlyRole(ADMIN) notLocked {
        transferWhiteListRequired = _on;
        emit TransferWhiteListRequired(_on);
    }

    function setClaimWL(bool _on) public onlyRole(ADMIN) notLocked {
        claimWhiteListRequired = _on;
        emit ClaimWhiteListRequired(_on);
    }

    function setTransferBlocked(bool _on) public onlyRole(ADMIN) notLocked {
        transferBlocked = _on;
        emit TransferBlocked(_on);
    }

    function setWhitelist(Whitelist newWhitelist) public onlyRole(ADMIN){
        require(whitelistAddressLocked, "Whitelist address is locked.");
        emit ChangeWhitelist(address(whitelistAddress), address(newWhitelist));
        whitelistAddress = newWhitelist;
    }
}