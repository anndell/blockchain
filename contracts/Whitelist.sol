// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract Whitelist is AccessControl {
    
    bytes32 public constant WHITELIST = keccak256("WHITELIST");

    mapping(address => bool) public whitelist;

    event AddToWhitelist(address indexed wallet);
    event RemoveFromWhitelist(address indexed wallet);

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

    function isWhitelisted (address _address) public view {
        require(whitelist[_address] == true, "Address is not whitelisted");
    }

    function _checkRole(bytes32 role, address account) internal view virtual override{
        if (!(hasRole(role, account) || hasRole(DEFAULT_ADMIN_ROLE, account))) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(account),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32),
                        " or ",
                        Strings.toHexString(uint256(DEFAULT_ADMIN_ROLE), 32)
                    )
                )
            );
        }
    }
}