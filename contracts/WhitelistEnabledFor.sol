// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../contracts/Whitelist.sol";

abstract contract WhitelistEnabledFor is Whitelist {

    bytes32 public constant WHITELIST_ENABLER = keccak256("WHITELIST_ENABLER");

    bool public whitelistStateLocked;

    bool public transferWhiteListRequired;
    bool public claimWhiteListRequired;
    bool public transferBlocked;

    event TransferWhiteListRequired (bool on);
    event ClaimWhiteListRequired (bool on);
    event TransferBlocked (bool on);
    event Lock(uint _type);

    modifier notLocked(){
        require(!whitelistStateLocked, "Whitelist state has been locked");
        _;
    }

    function setTransferWL(bool _on) public onlyRole(WHITELIST_ENABLER) notLocked {
        transferWhiteListRequired = _on;
        emit TransferWhiteListRequired(_on);
    }

    function setClaimWL(bool _on) public onlyRole(WHITELIST_ENABLER) notLocked {
        claimWhiteListRequired = _on;
        emit ClaimWhiteListRequired(_on);
    }

    function setTransferBlocked(bool _on) public onlyRole(WHITELIST_ENABLER) notLocked {
        transferBlocked = _on;
        emit TransferBlocked(_on);
    }

    function lockWhitelistState() public onlyRole(DEFAULT_ADMIN_ROLE) {
        whitelistStateLocked = true;
        emit Lock(1);
    }
}