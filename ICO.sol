// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract ICO is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
 
    uint256 public tokenPrice;
    ERC20 public rewardToken;
    uint256 public decimals;
    uint256 public startTimestamp;
    uint256 public finishTimestamp;
    bool public Claimenabled;
    uint256 public minInvestment;
    uint256 public maxInvestment;
    uint256 public maxDistributedTokenAmount;
    uint256 public minDistributedTokenAmount;
    uint256 public tokensForDistribution;
    uint256 public distributedTokens;
    uint256 public totalBNBraise;

    struct UserInfo {
        uint debt;
        uint totalInvestedETH;
    }

    mapping(address => UserInfo) public userInfo;
    mapping (address => bool) public existingUser;

    address[] public users;

    address[] public whitelistedUsers;
    mapping (address => bool) private isWhitelistedUser;
    mapping (address => bool) public claimBlocked;
 
    uint public round;

    event TokensDebt(
        address indexed holder,
        uint256 ethAmount,
        uint256 tokenAmount
    );
    
    event TokensWithdrawn(address indexed holder, uint256 amount);

    constructor(
        uint256 _tokenPrice,
        ERC20 _rewardToken,
        uint256 _startTimestamp,
        uint256 _finishTimestamp,
        uint256 _minEthPayment,
        uint256 _maxEthPayment,
        uint256 _hardCap,
        uint256 _SoftCap

    )  {
        tokenPrice = _tokenPrice;
        rewardToken = _rewardToken;
        decimals = rewardToken.decimals();

        require(
            _startTimestamp < _finishTimestamp,
            "Start timestamp must be less than finish timestamp"
        );
        require(
            _finishTimestamp > block.timestamp,
            "Finish timestamp must be more than current block"
        );
        startTimestamp = _startTimestamp;
        finishTimestamp = _finishTimestamp;
        minInvestment = _minEthPayment;
        maxInvestment = _maxEthPayment;
        maxDistributedTokenAmount = _hardCap;
        minDistributedTokenAmount = _SoftCap;
    }

//2857000000000
//0x2F39D4AdEf5Cc232a735C9a86e7A613C337f18A0
//1642918878
//1642919778
//100000000000000000
//500000000000000000
//875000000000000000000000
//350000000000000000000000


    function Invest() payable external {
    
        require(block.timestamp >= startTimestamp, "Not started");
        require(block.timestamp < finishTimestamp, "Ended");

        if (round == 0) {
            require (isWhitelistedUser[msg.sender] == true, "Not a whitelised User");
        }
 
        if (!existingUser[msg.sender]) {
            require (msg.value >= minInvestment, "Please Stake min amount");
            existingUser[msg.sender] = true;
            users.push(msg.sender);
        }
         
        uint256 tokenAmount = getTokenAmount(msg.value);
        require(tokensForDistribution.add(tokenAmount) <= maxDistributedTokenAmount, "PreSale is Sold Out");

        UserInfo storage user = userInfo[msg.sender];
        require(user.totalInvestedETH.add(msg.value) <= maxInvestment, "More then max amount");

        tokensForDistribution = tokensForDistribution.add(tokenAmount);
        user.totalInvestedETH = user.totalInvestedETH.add(msg.value);
        totalBNBraise = totalBNBraise.add(msg.value); 
        user.debt = user.debt.add(tokenAmount);

        emit TokensDebt(msg.sender, msg.value, tokenAmount);
    }                     // 2857000000000
                          // 

    function getTokenAmount(uint256 ethAmount)
        internal                   
        view
        returns (uint256)     
    {
        return ethAmount.mul(10**decimals).div(tokenPrice);
    }

    function startWhitelistingRound() public onlyOwner {
        round = 0;
    }

    function starPublicRound() public onlyOwner {
        round = 1;
    }

    function blockclaim(address _user, bool _status) public onlyOwner {
        claimBlocked[_user] = _status;
    }


    /// @dev Allows to claim tokens for the specific user.
    /// @param _user Token receiver.
    function claimFor(address _user) external {
        proccessClaim(_user);
    }

    /// @dev Allows to claim tokens for themselves.
    function claim() external {
        proccessClaim(msg.sender);
    }

    /// @dev Proccess the claim.
    /// @param _receiver Token receiver.
    function proccessClaim(
        address _receiver
    ) internal nonReentrant {
        require(claimBlocked[_receiver]==false, "Bad address"); 
        require(Claimenabled == true, "Distribution not started");
        UserInfo storage user = userInfo[_receiver];
        uint256 _amount = user.debt;
        uint eth = user.totalInvestedETH;
        
        if (minDistributedTokenAmount <= tokensForDistribution) {
            require (_amount > 0, "No tokens to claim");
                user.debt = 0;            
                distributedTokens = distributedTokens.add(_amount);
                rewardToken.safeTransfer(_receiver, _amount);
                emit TokensWithdrawn(_receiver,_amount);
        } 
        else {
            require (eth > 0, "No BNB to claim");
             user.totalInvestedETH = 0; 
             user.debt = 0;
             (bool success, ) = msg.sender.call{value: eth}("");
             require(success, "Transfer failed.");
        }        
    }

    function StartClaim() external onlyOwner {
        Claimenabled = true;
    }

    function StopClaim() external onlyOwner {
        Claimenabled = false;
    } 

    function checkWhitelisted(address _user) public view returns (bool) {
        return isWhitelistedUser[_user];
    }
 
    function withdrawETH(uint256 amount) external onlyOwner {
        // This forwards all available gas. Be sure to check the return value!
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed.");
    }

    function withdrawNotSoldTokens() external onlyOwner {
        require(block.timestamp > finishTimestamp, "Withdraw allowed after stop accept ETH");
        uint256 balance = rewardToken.balanceOf(address(this));
        rewardToken.safeTransfer(msg.sender, balance.add(distributedTokens).sub(tokensForDistribution));
    }

    function extendICOTime(uint _sec) external onlyOwner {
        finishTimestamp += _sec;
    }

    function emergencyWithdraw(ERC20 _address, uint _amnt) external onlyOwner {
        ERC20(_address).transfer(msg.sender, _amnt);
    }

    function totalUsers() external view returns(uint _users)
      {
    return users.length;
     }

    function addWhitelistedUser(address[] calldata _users) external onlyOwner {
        
        for (uint i =0; i < _users.length; i++) {
            whitelistedUsers.push(_users[i]);
            isWhitelistedUser[_users[i]] = true;   
        }
    } 

}
