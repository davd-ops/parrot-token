// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./IParrotRewards.sol";

// maybe add reentrancy guard just to be sure
contract ParrotRewards is IParrotRewards, Ownable {
    // usdc contract interface
    IERC20 public usdc;

    address public immutable shareholderToken;
    uint256 public totalLockedUsers;
    uint256 public totalSharesDeposited;

    // amount of shares a user has
    mapping(address => uint256) public shares;
    mapping(address => uint256) public unclaimedRewards;
    address[] public shareHolders;
    // reward information per user
    mapping(address => uint256) public claimedRewards;

    uint256 public totalRewards;
    uint256 public totalDistributed;

    uint256 private constant ACC_FACTOR = 10 ** 36;

    event ClaimReward(address wallet);
    event DistributeReward(address indexed wallet, address receiver);
    event DepositRewards(address indexed wallet, uint256 amountETH);

    constructor(address _shareholderToken) {
        shareholderToken = _shareholderToken;
    }

    function deposit(uint256 _amount) external {
        IERC20 tokenContract = IERC20(shareholderToken);
        tokenContract.transferFrom(msg.sender, address(this), _amount);
        _addShares(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external {
        address shareholder = msg.sender;
        require(
            _amount <= shares[shareholder],
            "cannot unlock more than you have locked"
        );
        _removeShares(shareholder, _amount);
        IERC20(shareholderToken).transfer(shareholder, _amount);
    }

    function _addShares(address shareholder, uint256 amount) internal {
        uint256 sharesBefore = shares[shareholder];
        totalSharesDeposited += amount;
        shares[shareholder] += amount;
        if (sharesBefore == 0 && shares[shareholder] > 0) {
            totalLockedUsers++;
        }
    }

    function _removeShares(address shareholder, uint256 amount) internal {
        require(
            shares[shareholder] > 0 && amount <= shares[shareholder],
            "only withdraw what you deposited"
        );
        _distributeReward(shareholder);

        totalSharesDeposited -= amount;
        shares[shareholder] -= amount;
        if (shares[shareholder] == 0) {
            totalLockedUsers--;
        }
    }

    function depositRewards(uint256 _amount) external {
        require(totalSharesDeposited > 0, "no reward recipients");
        usdc.transferFrom(msg.sender, address(this), _amount);
        uint256 shareCount = shareHolders.length;
        uint256 shareAmount = (ACC_FACTOR * _amount) / totalSharesDeposited;
        for (uint256 i = 0; i < shareCount; ) {
            uint256 userCut = shareAmount * shares[shareHolders[i]];
            unclaimedRewards[shareHolders[i]] += userCut;
            unchecked {
                ++i;
            }
        }

        totalRewards += _amount;
        emit DepositRewards(msg.sender, _amount);
    }

    function _distributeReward(address shareholder) internal {
        require(shares[shareholder] > 0, "no shares owned");

        uint256 amount = getUnpaid(shareholder);
        if (amount > 0) {
            claimedRewards[shareholder] += amount;

            usdc.transferFrom(address(this), shareholder, amount);
            totalDistributed += amount;
            emit DistributeReward(shareholder, shareholder);
        }
    }

    function claimReward() external {
        _distributeReward(msg.sender);
        emit ClaimReward(msg.sender);
    }

    function setUSDCAddress(address _usdc) external onlyOwner {
        usdc = IERC20(_usdc);
    }

    // returns the unpaid rewards
    function getUnpaid(address shareholder) public view returns (uint256) {
        return unclaimedRewards[shareholder];
    }

    function getShares(address user) external view returns (uint256) {
        return shares[user];
    }
}
