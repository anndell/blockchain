// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// anndellsplit.sol is an advanced Solidity contract that extends the Anndell tokenization platform, 
// enabling hierarchical split collections of NFTs, and allowing for the division of NFT ownership 
// across multiple sub-levels while maintaining a connection to the root Anndell contract. 
// Key features include initialization, split level tracking, fund distribution and withdrawal, and 
// event emission, with the contract designed to work seamlessly alongside the AnndellFee contract for 
// fee management.

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "../interfaces/IAnndellFee.sol";
import "../interfaces/IAnndell.sol"; 

contract AnndellSplit is ERC721Upgradeable, ERC721HolderUpgradeable {

    bytes32 public constant ADMIN = keccak256("ADMIN");

    // make sure both are anndell contracts
    function initialize (IAnndell _root, address _parent, IAnndellFee _anndellFee, uint _splitLevel) public initializer{ 
        __ERC721_init("", "");
        root = _root;
        parent = _parent;
        splitLevel = _splitLevel;
        fee = _anndellFee;
        periodLength = root.periodLength();
        flushDelay = root.flushDelay();
        firstPeriodStart = root.firstPeriodStart();
    }

    modifier hasRoleInRoot(bytes32 role){
        require(root.hasRole(role, msg.sender), "Not correct Role in root");
        _;
    }

    IAnndell public root;
    address public parent;

    IAnndellFee private fee;

    uint public splitLevel;
    uint public supply;
    uint public tokenCount;
    
    uint public firstPeriodStart;
    uint public periodLength;
    uint public flushDelay;

    uint[] public tokensFromAbove;

    mapping(address => uint) public retroactiveTotals;
    mapping(address => ClaimPeriod[]) public token;
    mapping(uint => address) public lockedIdToAddress;
    mapping(uint => uint) public nonBaeringIdToId;

    struct ClaimPeriod {
        uint start;
        uint startId;
        uint supply;
        uint shareEarnings;
        uint earningsAccountedFor;
        mapping(uint => uint) claimedPerShare;
    }

    event EarningsClaimed(address user, address token, uint totalAmount, uint[] shareIds, uint periodIndex);
    event Flush(address token, uint periodIndex);
    event ForceBackShares(uint[] shareIds);
    event CalculateTokenDistribution(address token, uint newShareEarnings);

    // require that it is a non-baering token
    function deposit(uint[] memory _tokens) external {
        for (uint i = 0; i < _tokens.length; i++) {
            require(_tokens[i] / 10e21 == 0, "Can not deposit non-bearing Anndell token");
            require(msg.sender == IERC721Upgradeable(parent).ownerOf(_tokens[i]));
            IERC721Upgradeable(parent).safeTransferFrom(msg.sender, address(this), _tokens[i]);
            tokensFromAbove.push(_tokens[i]);
            for (uint j = tokenCount + 1; j < tokenCount + 11; j++) {
                _safeMint(msg.sender, j);
            }
            tokenCount += 10;
            supply += 10;
        }
    }

    function releaseParent(uint[] calldata _tokens) external {
        uint l = _tokens.length;
        require(l > 0 && l % 10 == 0);
        for (uint256 i = 0; i < l/10; i++) {
            for (uint256 j = 0; j < (i + 1) * 10; j++) {
                require(_tokens[j] / 10e21 == 0, "Can not release Anndell token with non-baering tokens");
                require(ownerOf(_tokens[j]) == msg.sender);
                _burn(_tokens[j]);
            }
            supply -= 10;
            IERC721Upgradeable(parent).safeTransferFrom(address(this), msg.sender, tokensFromAbove[tokensFromAbove.length - 1]);
            tokensFromAbove.pop();
        }
    }

    function calculateTokensDistribution(address[] calldata _tokens) external {
        for (uint256 index = 0; index < _tokens.length; index++) {
            calculateTokenDistribution(_tokens[index]);
        }
    }

    function calculateTokenDistribution(address _token) public {
        require(supply != 0, "No shares yet");
        ClaimPeriod[] storage claimPeriods = token[_token];
        if(claimPeriods.length == 0){
            claimPeriods.push();
            // require thath one calculate disitribution has happened in root ??
            claimPeriods[0].start = firstPeriodStart;
            claimPeriods[0].supply = supply;
            claimPeriods[0].startId = tokenCount;
        }

        uint activePeriodIndex = claimPeriods.length - 1;
        ClaimPeriod storage activePeriod = claimPeriods[activePeriodIndex];

        if(block.timestamp < activePeriod.start + periodLength){
            _distribution(activePeriod, _token);
        }else{
            claimPeriods.push();
            ClaimPeriod storage nextPeriod = claimPeriods[activePeriodIndex + 1];
            // nextPeriod.startMaxTokenId = supplyCap + burnCount;
            nextPeriod.start = activePeriod.start + (block.timestamp - activePeriod.start) / periodLength;
            retroactiveTotals[_token] += activePeriod.earningsAccountedFor;
            nextPeriod.supply = supply;
            nextPeriod.startId = tokenCount;
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
            _period.shareEarnings += (balance - _period.earningsAccountedFor) / _period.supply;
            _period.earningsAccountedFor = balance;
        }else {
            uint balance = IERC20Upgradeable(_token).balanceOf(address(this)) - retroactiveTotals[_token];
            (address receiver, uint amount) = fee.getQuote(address(this), balance);
            IERC20Upgradeable(_token).transfer(receiver, amount);
            balance -= amount;
            _period.shareEarnings += (balance - _period.earningsAccountedFor) / _period.supply;
            _period.earningsAccountedFor = balance;
        }
        emit CalculateTokenDistribution(_token, _period.shareEarnings);
    }

    function claimEarnings(address _token, uint _claimPeriod, address _owner, uint[] calldata _shareIds) external { // add loop over periods?
        uint totalToGet = _totalToGet(_token, _claimPeriod, _owner, _shareIds);
        if (totalToGet != 0){
            if(_token == address(0)){
                (bool sent, ) = _owner.call{value: totalToGet}(""); // test if zero
                require(sent, "Failed to transfer native token");
            } else {
                IERC20Upgradeable(_token).transfer(_owner, totalToGet); // test if zero
            }
        }
        emit EarningsClaimed(_owner, _token, totalToGet, _shareIds, _claimPeriod);
    }

    function _totalToGet(address _token, uint _periodIndex, address _owner, uint[] calldata _shareIds) internal returns (uint totalToGet){
        require(_owner != address(this));
        ClaimPeriod storage period = token[_token][_periodIndex];
        if(root.claimWhiteListRequired()){
            require(root.isAddressWhitelisted(_owner), "Address not whitelisted");
        }
        require(period.earningsAccountedFor != 0, "Nothing to claim or flushed"); // CHECK FLUSHED?
        uint target = period.shareEarnings;

        for (uint256 index = 0; index < _shareIds.length; index++) {
            uint share = _shareIds[index];
            if(period.claimedPerShare[share] == 0 && share >= period.startId){ 
                period.claimedPerShare[share] = target;
                period.supply += 1;
            }else {
                if (ownerOf(share) == _owner || lockedIdToAddress[share] == _owner) { ////// hmmmmmm
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

    function flush(uint _periodIndex, address[] calldata _tokens) external hasRoleInRoot(ADMIN) {
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
            IERC20Upgradeable(_token).transfer(msg.sender, period.earningsAccountedFor);
        }
        period.earningsAccountedFor = 0;
        emit Flush(_token, _periodIndex);
    }

    function adminForceBackShares(uint[] calldata _ids, address _to) external hasRoleInRoot(ADMIN) {
        require(!root.adminForceBackDisabled(), "Force back has been disabled");
        for (uint256 index = 0; index < _ids.length; index++) {
            _transfer(ownerOf(_ids[index]), _to, _ids[index]);
        }
        emit ForceBackShares(_ids);
    }

    receive() external payable {}
    
    function getBalance() public view returns(uint){
        return address(this).balance;
    }

    function issueNonBaering(uint[] memory _tokenIds, address _receiverAddress) external {
        uint idToIssue;
        uint id;
        for (uint i = 0; i < _tokenIds.length; i++) {
            id = _tokenIds[i];
            require(ownerOf(id) == msg.sender, "Not owner of share.");
            require(nonBaeringIdToId[id] == 0 && id / 10e21 == 0);
            IERC721Upgradeable(address(this)).safeTransferFrom(msg.sender, address(this), id); // how does this work with whitelist and shit?
            lockedIdToAddress[id] = _receiverAddress;
            idToIssue = id + 10e21;
            nonBaeringIdToId[idToIssue] = id;
            _safeMint(msg.sender, idToIssue);
        }
    }

    function redeemNonBaeringToken(uint[] memory _tokenIds) external {
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

    function releaseShares(IERC721Upgradeable _address, address _to, uint[] memory _ids) external hasRoleInRoot(ADMIN) { // this must be better checked
        for (uint i = 0; i < _ids.length; i++) {
            if(address(_address) == address(this) && _ids[i] / 10e21 == 0) {
                require(lockedIdToAddress[_ids[i]] == address(0) && nonBaeringIdToId[_ids[i]] == 0, "Not owned by contract, is a twin");
            }
            _address.safeTransferFrom(address(this), _to, _ids[i]);
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize) internal override {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        if (!(from == address(0) || root.hasRole(ADMIN, msg.sender))) {
            require(!root.transferBlocked(), "Transfers are currently blocked");
            if(root.transferWhiteListRequired()) {
                require(root.isAddressWhitelisted(from) && root.isAddressWhitelisted(to),"Invalid token transfer");
            }
        }
    }

    function name() public view override returns (string memory) {
        return string.concat(root.name(), (string.concat(" 1/", StringsUpgradeable.toString(splitLevel))));
        
    }

    function symbol() public view override returns (string memory) {
        return string.concat(root.symbol(), (string.concat(" 1/", StringsUpgradeable.toString(splitLevel))));
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return string.concat(root.baseURI(), (string.concat(StringsUpgradeable.toString(splitLevel), "/")));
    }
}