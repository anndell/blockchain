// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../contracts/Settings.sol";

abstract contract AnndellNested is ERC721Holder, Settings {

    mapping(IERC721 => mapping (uint => bool)) public idLocked;

    event TokenLockedToContract(IERC721 tokenContract, uint id);

    function releaseShares(IERC721 _address, address _to, uint[] memory _ids) public onlyRole(ADMIN){
        for (uint i = 0; i < _ids.length; i++) {
            require(!idLocked[_address][_ids[i]], "Token is locked to this contract");
            _address.safeTransferFrom(address(this), _to, _ids[i]);
        }
    }

    function lockSharesToContract(IERC721 _address, uint[] memory _ids) public onlyRole(ADMIN) {
        for (uint i = 0; i < _ids.length; i++) {
            if(address(this) == _address.ownerOf(_ids[i])){
                idLocked[_address][_ids[i]] = true;
                emit TokenLockedToContract(_address, _ids[i]);
            }
        }
    }
}