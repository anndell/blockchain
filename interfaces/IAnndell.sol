// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IAnndell is IERC721{
     function name() external view returns (string memory);
     function symbol() external view returns (string memory);
     function firstPeriodStart() external view returns (uint);
     function periodLength() external view returns (uint);
     function flushDelay() external view returns (uint);
}