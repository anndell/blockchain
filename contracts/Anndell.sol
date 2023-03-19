// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../contracts/Whitelist.sol";
import "../interfaces/IAnndellFee.sol";

contract Anndell is Whitelist {

    constructor (string memory _name, string memory _symbol, address _default_admin, IAnndellFee _anndellFee) ERC721 (_name, _symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _default_admin);
        whitelistAddress = this;
        name_ = _name;
        symbol_ = _symbol;
        fee = _anndellFee;
    }

    IAnndellFee private fee;

    bytes32 public constant MINT = keccak256("MINT");

    uint public supplyCap;
    uint public circulatingSupply;
    uint public burnCount;

    uint public lockIssuanceUntil;
    
    uint public firstPeriodStart;
    uint public periodLength = 365 days;
    uint public flushDelay = 90 days;

    mapping(IERC721 => mapping (uint => bool)) public idLocked;

    mapping(address => uint) public retroactiveTotals;
    mapping(address => ClaimPeriod[]) public token;
    mapping(uint => address) public lockedIdToAddress;
    mapping(uint => uint) public nonBaeringIdToId;

    struct ClaimPeriod {
        uint start;
        uint startCap;
        uint startMaxTokenId;
        uint shareEarnings;
        uint earningsAccountedFor;
        mapping(uint => uint) claimedPerShare;
    }

    event IssuanceOfShares (uint sharesInCirculation, uint oldCap, uint newCap);
    event IssuerMintOfShares (uint IDfrom, uint IDto);
    event EarningsClaimed(address user, address token, uint totalAmount, uint[] shareIds, uint periodIndex);
    event Flush(address token, uint periodIndex);
    event ForceBackShares(uint[] shareIds);
    event CalculateTokenDistribution(address token, uint newShareEarnings);
    event IssuanceLockedUntil(uint timestamp);
    event TokenLockedToContract(IERC721 tokenContract, uint id);
    event PeriodAndDelay(uint period, uint delay);
    
    function issuanceOfShares(uint _nrToIssue) public onlyRole(ADMIN) {
        require(!supplyCapLocked, "No more shares can be issued");
        require(supplyCap == circulatingSupply, "You can not issue more shares before minting existing ones"); // is this nessecary?
        require(_nrToIssue > 0, "Can not issue 0");
        if(lockIssuanceUntil != 0){
            require(lockIssuanceUntil < block.timestamp, "New issuance locked for a set time frame");
        }
        if(supplyCap == 0){firstPeriodStart = block.timestamp;}
        supplyCap += _nrToIssue;
        emit IssuanceOfShares(circulatingSupply, supplyCap - _nrToIssue, supplyCap);
    }

    function mint(address _to, uint _quantity) public onlyRole(MINT) {
        uint target = circulatingSupply + _quantity;
        require(target <= supplyCap && (target + burnCount) / 10e21 == 0, "Cap overflow");
        uint idTarget = target + burnCount;
        for (uint256 index = circulatingSupply + burnCount + 1; index <= idTarget; index++) {
            _safeMint(_to, index);
        }
        emit IssuerMintOfShares(circulatingSupply, target);
        circulatingSupply = target; 
    }

    function calculateTokensDistribution(address[] calldata _tokens) public {
        for (uint256 index = 0; index < _tokens.length; index++) {
            calculateTokenDistribution(_tokens[index]);
        }
    }

    function calculateTokenDistribution(address _token) public {
        require(supplyCap != 0, "Must issue shares");
        ClaimPeriod[] storage claimPeriods = token[_token];
        if(claimPeriods.length == 0){
            claimPeriods.push();
            claimPeriods[0].start = firstPeriodStart;
            claimPeriods[0].startCap = supplyCap;
            claimPeriods[0].startMaxTokenId = supplyCap + burnCount;
        }

        uint activePeriodIndex = claimPeriods.length - 1;
        ClaimPeriod storage activePeriod = claimPeriods[activePeriodIndex];

        if(block.timestamp < activePeriod.start + periodLength){
            _distribution(activePeriod, _token);
        }else{
            claimPeriods.push();
            ClaimPeriod storage nextPeriod = claimPeriods[activePeriodIndex + 1];
            nextPeriod.startCap = supplyCap;
            nextPeriod.startMaxTokenId = supplyCap + burnCount;
            nextPeriod.start = activePeriod.start + (block.timestamp - activePeriod.start) / periodLength;
            retroactiveTotals[_token] += activePeriod.earningsAccountedFor;
            _distribution(nextPeriod, _token);
        }
    }

    function _distribution(ClaimPeriod storage _period, address _token) internal {
        if (_token == address(0)){
            uint balance = address(this).balance - retroactiveTotals[address(0)];
            (address receiver, uint amount) = fee.getQuote(address(this), balance);
            (bool sent, ) = receiver.call{value: amount}("");
            require(sent, "Failed to transfer native token");
            balance -= amount;
            _period.shareEarnings += (balance - _period.earningsAccountedFor) / _period.startCap;
            _period.earningsAccountedFor = balance;
        }else {
            uint balance = IERC20(_token).balanceOf(address(this)) - retroactiveTotals[_token];
            (address receiver, uint amount) = fee.getQuote(address(this), balance);
            IERC20(_token).transfer(receiver, amount);
            balance -= amount;
            _period.shareEarnings += (balance - _period.earningsAccountedFor) / _period.startCap;
            _period.earningsAccountedFor = balance;
        }
        emit CalculateTokenDistribution(_token, _period.shareEarnings);
    }

    function burnBatch(uint[] calldata _tokens) external {
        require(burnEnabled, "Burning shares is disabled");
        uint tokenAmount = _tokens.length;
        circulatingSupply -= tokenAmount;
        supplyCap -= tokenAmount;
        burnCount += tokenAmount;
        for (uint i = 0; i < tokenAmount; i++) {
            require(_isApprovedOrOwner(msg.sender, _tokens[i]), "Invalid token owner");
            _burn(_tokens[i]);
        }
    }

    function claimEarnings(address _token, uint _claimPeriod, address _owner, uint[] calldata _shareIds) public { // add loop over periods?
        uint totalToGet = _totalToGet(_token, _claimPeriod, _owner, _shareIds);
        if(_token == address(0)){
            (bool sent, ) = _owner.call{value: totalToGet}(""); // test if zero
            require(sent, "Failed to transfer native token");
        } else {
            IERC20(_token).transfer(_owner, totalToGet); // test if zero
        }
        emit EarningsClaimed(_owner, _token, totalToGet, _shareIds, _claimPeriod);
    }

    function _totalToGet(address _token, uint _periodIndex, address _owner, uint[] calldata _shareIds) internal returns (uint totalToGet){
        require(_owner != address(this));
        ClaimPeriod storage period = token[_token][_periodIndex];
        if(claimWhiteListRequired){
            require(whitelistAddress.whitelist(_owner), "Address not whitelisted");
        }
        require(period.earningsAccountedFor != 0, "Nothing to claim or flushed"); // CHECK FLUSHED?
        uint target = period.shareEarnings;

        uint startMaxTokenId = period.startMaxTokenId + 1;
        for (uint256 index = 0; index < _shareIds.length; index++) {
            uint share = _shareIds[index];
            if(share < startMaxTokenId){ 
                if (ownerOf(share) == _owner || lockedIdToAddress[share] == _owner) {
                    totalToGet += target - period.claimedPerShare[share];
                    period.claimedPerShare[share] = target;
                }
            }
        }
        if(_periodIndex < token[_token].length - 1){
            retroactiveTotals[_token] -= totalToGet;
        }
        period.earningsAccountedFor -= totalToGet; // TEST IF FAIL ON FLUSHED
    } 

    function flush(uint _periodIndex, address[] calldata _tokens) public onlyRole(ADMIN){
        for (uint256 index = 0; index < _tokens.length; index++) {
            _flush(_periodIndex, _tokens[index]);
        }
    }

    function _flush(uint _periodIndex, address _token) internal {
        ClaimPeriod storage period = token[_token][_periodIndex];
        require(period.start > block.timestamp + periodLength + flushDelay, "Not Possible to flush this deposit period yet.");
        retroactiveTotals[_token] -= period.earningsAccountedFor;
        if(_token == address(0)){
            uint toSend = period.earningsAccountedFor; // prevent reentrancy
            (bool sent, ) = msg.sender.call{value: toSend}("");
            require(sent, "Failed to transfer native token");
        }else{
            IERC20(_token).transfer(msg.sender, period.earningsAccountedFor);
        }
        period.earningsAccountedFor = 0;
        emit Flush(_token, _periodIndex);
    }

    function adminForceBackShares(uint[] calldata _ids, address _to) external onlyRole(ADMIN){
        require(!adminForceBackDisabled, "Force back has been disabled");
        for (uint256 index = 0; index < _ids.length; index++) {
            _transfer(ownerOf(_ids[index]), _to, _ids[index]);
        }
        emit ForceBackShares(_ids);
    }

    function setPeriodAndDelay(uint _periodLength, uint _flushDelay) public onlyRole(ADMIN){
        require(firstPeriodStart == 0, "Contract already started");
        periodLength = _periodLength;
        flushDelay = _flushDelay;
        emit PeriodAndDelay(_periodLength, _flushDelay);
    }

    function setLockIssuanceUntil(uint _timestamp) public onlyRole(ADMIN){
        require(supplyCap != 0);
        if(block.timestamp < lockIssuanceUntil){
            require(lockIssuanceUntil < _timestamp);
            lockIssuanceUntil = _timestamp;
        }else{
            require(block.timestamp < _timestamp);
            lockIssuanceUntil = _timestamp;
        }
        emit IssuanceLockedUntil(_timestamp);
    }

    receive() external payable {}
    
    function getBalance() public view returns(uint){
        return address(this).balance;
    }

    function issueNonBaering(uint[] memory _tokenIds, address _receiverAddress) public {
        uint idToIssue;
        uint id;
        for (uint i = 0; i < _tokenIds.length; i++) {
            id = _tokenIds[i];
            require(ownerOf(id) == msg.sender, "Not owner of share.");
            require(nonBaeringIdToId[id] == 0 && id / 10e21 == 0);
            IERC721(address(this)).safeTransferFrom(msg.sender, address(this), id); // how does this work with whitelist and shit?
            lockedIdToAddress[id] = _receiverAddress;
            idToIssue = id + 10e21;
            nonBaeringIdToId[idToIssue] = id;
            _safeMint(msg.sender, idToIssue);
        }
    }

    function redeemNonBaeringToken(uint[] memory _tokenIds) public {
        uint id;
        for (uint i = 0; i < _tokenIds.length; i++) {
            id = _tokenIds[i];
            require(ownerOf(id) == msg.sender, "Not owner of share.");
            require(id / 10e21 != 0, "Not a non baering twin");
            _burn(id);
            delete lockedIdToAddress[id];
            safeTransferFrom(address(this), msg.sender, nonBaeringIdToId[id]);
            delete nonBaeringIdToId[id];
        }
    }

    function releaseShares(IERC721 _address, address _to, uint[] memory _ids) public onlyRole(ADMIN){
        for (uint i = 0; i < _ids.length; i++) {
            if(address(_address) == address(this) && _ids[i] / 10e21 == 0) {
                require(lockedIdToAddress[_ids[i]] == address(0) && nonBaeringIdToId[_ids[i]] == 0, "Not owned by contract, is a twin");
            }
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

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize) internal override {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        if (!(from == address(0) || hasRole(ADMIN, msg.sender))) {
            require(!transferBlocked, "Transfers are currently blocked");
            if(transferWhiteListRequired) {
                require(whitelistAddress.whitelist(from) && whitelistAddress.whitelist(to),"Invalid token transfer");
            }
        }
    }
}