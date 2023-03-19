// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract AnndellFee is AccessControl {

    constructor(address _default_admin, address _defaultReceiver){
        require(_defaultReceiver != address(0));
        defaultReceiver = _defaultReceiver;
        _setupRole(DEFAULT_ADMIN_ROLE, _default_admin);
    }

    uint constant private BASIS_POINTS = 10_000;
    
    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant FACTORY = keccak256("FACTORY");

    bool private defaultSettings;
    address private defaultReceiver;
    uint private defaultFee;

    mapping(address => PercentageAndReceiver) public percentagesAndReceivers;

    struct PercentageAndReceiver{
        address receiver;
        uint percentageBasisPoints;
    }

    event PercentageAndReceiverSet(address _contract, address _receiver, uint _percentageBasisPoints);

    function getQuote(address _contract, uint _amount) public view returns(address receiver, uint amount) {
        if(percentagesAndReceivers[_contract].percentageBasisPoints != 0){
            amount = (_amount * percentagesAndReceivers[_contract].percentageBasisPoints) / BASIS_POINTS;
            receiver = percentagesAndReceivers[_contract].receiver;
        }
    }

    function setQuotesAdmin(address[] memory _contracts, uint[] memory _percentagesInBasisPoints, address[] memory _receivers) public onlyRole(ADMIN){
        uint length = _contracts.length;
        require(length == _percentagesInBasisPoints.length && length == _receivers.length);
        for (uint256 index = 0; index < length; index++) {
            require(_receivers[index] != address(0));
            require(_percentagesInBasisPoints[index] < BASIS_POINTS);
            percentagesAndReceivers[_contracts[index]].receiver = _receivers[index];
            percentagesAndReceivers[_contracts[index]].percentageBasisPoints = _percentagesInBasisPoints[index];
            emit PercentageAndReceiverSet(_contracts[index], _receivers[index], _percentagesInBasisPoints[index]);
        }
    }

    function setQuote(address _contract) public onlyRole(FACTORY){
        if(defaultSettings){
            percentagesAndReceivers[_contract].receiver = defaultReceiver;
            percentagesAndReceivers[_contract].percentageBasisPoints = defaultFee;
            emit PercentageAndReceiverSet(_contract, defaultReceiver, defaultFee);
        }
    }

    function setDefaultSettings(bool _enable) public onlyRole(ADMIN){
        defaultSettings = _enable;
    }

    function setDefaultFee(uint _feeInBasisPoints) public onlyRole(ADMIN){
        require(_feeInBasisPoints < BASIS_POINTS);
        defaultFee = _feeInBasisPoints;
    }

    function setDefaultReceiver(address _receiver) public onlyRole(ADMIN){
        require(_receiver != address(0));
        defaultReceiver = _receiver;
    }
}