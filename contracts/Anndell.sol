// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../contracts/WhitelistEnabledFor.sol";

contract Anndell is ERC721, WhitelistEnabledFor {

    constructor (string memory _name, string memory _symbol, address _default_admin) ERC721 (_name, _symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _default_admin);
        whitelistAddress = this;
    }

    receive() external payable {}
    function getBalance() public view returns(uint){
        return address(this).balance;
    }

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant MINT = keccak256("MINT");
    bytes32 public constant FLUSH = keccak256("FLUSH");

    Whitelist public whitelistAddress;

    string name_;
    string symbol_;
    string baseURI_;

    uint public supplyCap;
    uint public circulatingSupply;
    uint public burnCount;

    bool public nameSymbolLocked;
    bool public baseURILocked;
    bool public supplyCapLocked;
    bool public adminForceBackDisabled;
    bool public burnEnabled;
    bool public burnLocked;
    bool public whitelistAddressLocked;

    uint public lockIssuanceUntil;
    
    uint public firstPeriodStart;
    uint public periodLength = 365 days;
    uint public flushDelay = 90 days;

    mapping(address => uint) public retroactiveTotals;
    mapping(address => ClaimPeriod[]) public token;

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
    event ChangeNameAndTicker(string oldName, string oldSymbol, string newName, string newSymbol);
    event ChangeBaseURI(string oldBase, string newBase);
    event CalculateTokenDistribution(address token, uint newShareEarnings);
    event IssuanceLockedUntil(uint timestamp);
    event ChangeWhitelist(address old, address _new);
    
    function issuanceOfShares(uint _nrToIssue) public onlyRole(ADMIN) {
        require(!supplyCapLocked, "No more shares can be issued");
        require(supplyCap == circulatingSupply, "You can not issue more shares before minting existing ones");
        require(_nrToIssue > 0, "Can not issue 0");
        if(lockIssuanceUntil != 0){
            require(lockIssuanceUntil < block.timestamp, "New issuance locked for a set time frame");
        }
        if(supplyCap == 0){firstPeriodStart = block.timestamp;}
        supplyCap += _nrToIssue;
        emit IssuanceOfShares(circulatingSupply, supplyCap - _nrToIssue, supplyCap);
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
            _period.shareEarnings += (balance - _period.earningsAccountedFor) / _period.startCap;
            _period.earningsAccountedFor = balance;
        }else {
            uint balance = IERC20(_token).balanceOf(address(this)) - retroactiveTotals[_token];
            _period.shareEarnings += (balance - _period.earningsAccountedFor) / _period.startCap;
            _period.earningsAccountedFor = balance;
        }
        emit CalculateTokenDistribution(_token, _period.shareEarnings);
    }

    function mint(address _to, uint _quantity) public onlyRole(MINT) {
        uint target = circulatingSupply + _quantity;
        require(target <= supplyCap, "Cap overflow");
        uint idTarget = target + burnCount;
        for (uint256 index = circulatingSupply + burnCount + 1; index <= idTarget; index++) {
            _safeMint(_to, index);
        }
        emit IssuerMintOfShares(circulatingSupply, target);
        circulatingSupply = target; 
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

    function setBurnEnabled(bool _enabled) external onlyRole(ADMIN) {
        require(!burnLocked, "Burn state is locked");
        burnEnabled = _enabled;
    }

    function lockBurnEnabled() external onlyRole(ADMIN) {
        burnLocked = true;
        emit Lock(6);
    }

    function claimEarnings(address _token, uint _claimPeriod, address _owner, uint[] calldata _shareIds) public { // add loop over periods?
        uint totalToGet = _totalToGet(_token, _claimPeriod, _owner, _shareIds);
        IERC20(_token).transfer(_owner, totalToGet); // test if zero
        emit EarningsClaimed(_owner, _token, totalToGet, _shareIds, _claimPeriod);
    }

    function claimEarningsNative(uint _claimPeriod, address _owner, uint[] calldata _shareIds) public { // add loop over periods?
        uint totalToGet = _totalToGet(address(0), _claimPeriod, _owner, _shareIds);
        (bool sent, ) = _owner.call{value: totalToGet}(""); // test if zero
        require(sent, "Failed to transfer native token");
        emit EarningsClaimed(_owner, address(0), totalToGet, _shareIds, _claimPeriod);
    }

    function _totalToGet(address _token, uint _periodIndex, address _owner, uint[] calldata _shareIds) internal returns (uint totalToGet){
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
                require(ownerOf(share) == _owner, "Not owner of share");
                totalToGet += target - period.claimedPerShare[share];
                period.claimedPerShare[share] = target;
            }
        }
        if(_periodIndex < token[_token].length - 1){
            retroactiveTotals[_token] -= totalToGet;
        }
        period.earningsAccountedFor -= totalToGet; // TEST IF FAIL ON FLUSHED
    } 

    function flush(uint _periodIndex, address[] calldata _tokens) public onlyRole(FLUSH){
        for (uint256 index = 0; index < _tokens.length; index++) {
            _flush(_periodIndex, _tokens[index]);
        }
    }

    function _flush(uint _periodIndex, address _token) internal {
        ClaimPeriod storage period = token[_token][_periodIndex];
        require(period.start > block.timestamp + periodLength + flushDelay, "Not Possible to flush this deposit period yet.");
        if(_token == address(0)){
            retroactiveTotals[address(0)] -= period.earningsAccountedFor;
            uint toSend = period.earningsAccountedFor; // prevent reentrancy
            period.earningsAccountedFor = 0;
            (bool sent, ) = msg.sender.call{value: toSend}("");
            require(sent, "Failed to transfer native token");
        }else{
            retroactiveTotals[_token] -= period.earningsAccountedFor;
            IERC20(_token).transfer(msg.sender, period.earningsAccountedFor);
            period.earningsAccountedFor = 0;
        }
        emit Flush(_token, _periodIndex);
    }

    function lockCap() public onlyRole(ADMIN){
        require(supplyCap != 0, "Can not lock contract without issuing any shares");
        supplyCapLocked = true;
        emit Lock(2);
    }

    function setPeriodAndDelay(uint _periodLength, uint _flushDelay) public onlyRole(ADMIN){
        require(firstPeriodStart == 0, "Contract already started");
        periodLength = _periodLength;
        flushDelay = _flushDelay;
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

    function adminForceBackShares(uint[] calldata _ids, address _to) external onlyRole(ADMIN){
        require(!adminForceBackDisabled, "Force back has been disabled");
        for (uint256 index = 0; index < _ids.length; index++) {
            _transfer(ownerOf(_ids[index]), _to, _ids[index]);
        }
        emit ForceBackShares(_ids);
    }

    function disableAdminForceBack() external onlyRole(ADMIN){
       adminForceBackDisabled = true;
       emit Lock(3);
    }

    function setNameAndSymbol(string memory _name, string memory _symbol) external onlyRole(ADMIN){
        require(!nameSymbolLocked, "Name and Symbol is locked");
        emit ChangeNameAndTicker(name_, symbol_, _name, _symbol);
        name_ = _name;
        symbol_ = _symbol;
    }

    function lockNameAndSymbol() external onlyRole(ADMIN){
       nameSymbolLocked = true;
       emit Lock(4);
    }

    function name() public view override returns (string memory) {
        return name_;
    }

    function symbol() public view override returns (string memory) {
        return symbol_;
    }

    function setBaseURI(string memory _base) external onlyRole(ADMIN){
        require(!baseURILocked, "base uri can not be changed");
        emit ChangeBaseURI(baseURI_, _base);
        baseURI_ = _base;
    } 

    function lockBaseURI() external onlyRole(ADMIN){
        baseURILocked = true;
        emit Lock(5);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI_;
    }

    function setWhitelist(Whitelist newWhitelist) public onlyRole(ADMIN){
        require(whitelistAddressLocked, "can not change whitelist");
        emit ChangeWhitelist(address(whitelistAddress), address(newWhitelist));
        whitelistAddress = newWhitelist;
    }

    function lockWhitelist() external onlyRole(ADMIN){
        whitelistAddressLocked = true;
        emit Lock(7);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize) internal override {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        if (!(from == address(0) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender))) {
            require(!transferBlocked, "Transfers are currently blocked");
            if(transferWhiteListRequired) {
                require(whitelistAddress.whitelist(from) && whitelistAddress.whitelist(to),"Invalid token transfer");
            }
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}