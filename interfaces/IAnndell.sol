// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

interface IAnndell is IERC721, IAccessControl{
     function name() external view returns (string memory);
     function symbol() external view returns (string memory);
     function firstPeriodStart() external view returns (uint);
     function periodLength() external view returns (uint);
     function flushDelay() external view returns (uint);
     function claimWhiteListRequired() external view returns (bool);
     function adminForceBackDisabled() external view returns (bool);
     function transferBlocked() external view returns (bool);
     function transferWhiteListRequired() external view returns (bool);
     function whitelistAddress() external view returns (address);
     function whitelist(address _whitelisted) external view returns (bool);
     function baseURI() external view returns (string memory);
}