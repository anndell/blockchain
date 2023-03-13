// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IAnndellFee {
     function setQuote(address _contract) external;
     function getQuote(address _contract, uint _amount) external view returns(address receiver, uint amount);
}