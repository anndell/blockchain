// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// settings.sol is a Solidity smart contract that serves as the configuration center for the Anndell ecosystem,
// providing a centralized point of management for various parameters and settings. This contract enables the 
// platform's administrator to define and update key settings, such as fees, factory addresses, and whitelist 
// addresses, ensuring the smooth operation and adaptability of the platform. By offering a unified place for 
// managing settings, settings.sol enhances the maintainability and flexibility of the Anndell ecosystem, 
// allowing it to evolve and adapt to changing requirements and conditions.

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

abstract contract Settings is AccessControlUpgradeable, ERC721Upgradeable {

    bytes32 public constant ADMIN = keccak256("ADMIN");

    bool public whitelistStateLocked;
    bool public whitelistAddressLocked;
    bool public transferWhiteListRequired;
    bool public claimWhiteListRequired;
    bool public transferBlocked;

    bool public supplyCapLocked;
    bool public adminForceBackDisabled;
    bool public burnEnabled;
    bool public burnLocked;

    bool public nameSymbolLocked;
    bool public baseURILocked;
    
    string name_;
    string symbol_;
    string baseURI_;

    event Lock(uint _type);
    event ChangeNameAndTicker(string oldName, string oldSymbol, string newName, string newSymbol);
    event ChangeBaseURI(string oldBase, string newBase);

    function setBurnEnabled(bool _enabled) external onlyRole(ADMIN) {
        require(!burnLocked, "Burn state is locked");
        burnEnabled = _enabled;
        // add event
    }

    function lockWhitelistState() external onlyRole(ADMIN) {
        whitelistStateLocked = true;
        emit Lock(1);
    }

    function lockNameAndSymbol() external onlyRole(ADMIN) {
       nameSymbolLocked = true;
       emit Lock(2);
    }

    function lockBurnEnabled() external onlyRole(ADMIN) {
        burnLocked = true;
        emit Lock(3);
    }

    function lockCap() external onlyRole(ADMIN) {
        // require(supplyCap != 0, "Can not lock contract without issuing any shares");
        supplyCapLocked = true;
        emit Lock(4);
    }

        function disableAdminForceBack() external onlyRole(ADMIN) {
       adminForceBackDisabled = true;
       emit Lock(5);
    }

    function lockBaseURI() external onlyRole(ADMIN) {
        baseURILocked = true;
        emit Lock(6);
    }

    function lockWhitelist() external onlyRole(ADMIN) {
        whitelistAddressLocked = true;
        emit Lock(7);
    }

    function setNameAndSymbol(string memory _name, string memory _symbol) external onlyRole(ADMIN){
        require(!nameSymbolLocked, "Name and Symbol is locked.");
        emit ChangeNameAndTicker(name_, symbol_, _name, _symbol);
        name_ = _name;
        symbol_ = _symbol;
    }
    
    function setBaseURI(string memory _base) external onlyRole(ADMIN){
        require(!baseURILocked, "Base URI is locked.");
        emit ChangeBaseURI(baseURI_, _base);
        baseURI_ = _base;
    }

    function name() public view override returns (string memory) {
        return name_;
    }

    function symbol() public view override returns (string memory) {
        return symbol_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI_;
    }

    function baseURI() public view virtual returns (string memory) {
        return _baseURI();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Upgradeable, AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}