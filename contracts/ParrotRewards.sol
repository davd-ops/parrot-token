// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./IParrotRewards.sol";

// maybe add reentrancy guard just to be sure
contract ParrotRewards is IParrotRewards, Ownable {
    // uint256 private constant ONE_DAY = 60 * 60 * 24;
    // int256 private constant OFFSET19700101 = 2440588;

    struct Reward {
        uint256 totalExcluded;
        uint256 totalRealised;
        uint256 lastClaim;
    }

    // struct Share {
    //     uint256 amount;
    //     uint256 lockedTime;
    // }

    // usdc contract interface
    IERC20 public usdc;

    // uint256 public timeLock = 30 days;
    address public immutable shareholderToken;
    uint256 public totalLockedUsers;
    uint256 public totalSharesDeposited;

    // uint8 public minDayOfMonthCanLock = 1;
    // uint8 public maxDayOfMonthCanLock = 5;

    // amount of shares a user has
    mapping(address => uint256) public shares;
    mapping(address => uint256) public unclaimedRewards;
    address[] public shareHolders;
    // reward information per user
    mapping(address => uint256) public claimedRewards;

    uint256 public totalRewards;
    uint256 public totalDistributed;
    // uint256 public rewardsPerShare;

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

    //   function lock(uint256 _amount) external {
    //     uint256 _currentDayOfMonth = _dayOfMonth(block.timestamp);
    //     require(
    //       _currentDayOfMonth >= minDayOfMonthCanLock &&
    //         _currentDayOfMonth <= maxDayOfMonthCanLock,
    //       'outside of allowed lock window'
    //     );
    //     address shareholder = msg.sender;
    //     IERC20 tokenContract = IERC20(shareholderToken);
    //     _amount = _amount == 0 ? tokenContract.balanceOf(shareholder) : _amount;
    //     tokenContract.transferFrom(shareholder, address(this), _amount);
    //     _addShares(shareholder, _amount);
    //   }

    function withdraw(uint256 _amount) external {
        address shareholder = msg.sender;
        require(
            _amount <= shares[shareholder],
            "cannot unlock more than you have locked"
        );
        _removeShares(shareholder, _amount);
        IERC20(shareholderToken).transfer(shareholder, _amount);
    }

    // function unlock(uint256 _amount) external {
    //     address shareholder = msg.sender;
    //     require(
    //         block.timestamp >= shares[shareholder].lockedTime + timeLock,
    //         "must wait the time lock before unstaking"
    //     );
    //     _amount = _amount == 0 ? shares[shareholder].amount : _amount;
    //     require(_amount > 0, "need tokens to unlock");
    //     require(
    //         _amount <= shares[shareholder].amount,
    //         "cannot unlock more than you have locked"
    //     );
    //     IERC20(shareholderToken).transfer(shareholder, _amount);
    //     _removeShares(shareholder, _amount);
    // }

    function _addShares(address shareholder, uint256 amount) internal {
        // _distributeReward(shareholder);

        uint256 sharesBefore = shares[shareholder];
        totalSharesDeposited += amount;
        shares[shareholder] += amount;
        // shares[shareholder].lockedTime = block.timestamp;
        if (sharesBefore == 0 && shares[shareholder] > 0) {
            totalLockedUsers++;
        }
        // rewards[shareholder].totalExcluded = getCumulativeRewards(
        //     shares[shareholder]
        // );
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
        // rewards[shareholder].totalExcluded = getCumulativeRewards(
        //     shares[shareholder]
        // );
    }

    // function depositRewards() public payable override {
    //     _depositRewards(msg.value);
    // }

    function depositRewards(uint256 _amount) internal {
        require(totalSharesDeposited > 0, "no reward recipients");
        usdc.transferFrom(msg.sender, address(this), _amount);
        uint256 shareCount = shareHolders.length;
        // uint256 rewardsPerShare += (ACC_FACTOR * _amount) / totalSharesDeposited;
        uint256 shareAmount = (ACC_FACTOR * _amount) / totalSharesDeposited;
        for (uint256 i = 0; i < shareCount; ) {
            uint256 userCut = shareAmount * shares[shareHolders[i]];
            unclaimedRewards[shareHolders[i]] += userCut;
            unchecked {
                ++i;
            }
        }

        totalRewards += _amount;
        // rewardsPerShare += (ACC_FACTOR * _amount) / totalSharesDeposited;
        emit DepositRewards(msg.sender, _amount);
    }

    function _distributeReward(address shareholder) internal {
        require(shares[shareholder] > 0, "no shares owned");

        uint256 amount = getUnpaid(shareholder);

        // rewards[shareholder].totalExcluded = getCumulativeRewards(
        //     shares[shareholder].amount
        // );
        // rewards[shareholder].lastClaim = block.timestamp;
        if (amount > 0) {
            claimedRewards[shareholder] += amount;

            usdc.transferFrom(address(this), shareholder, amount);
            totalDistributed += amount;
            // uint256 balanceBefore = address(this).balance;
            //unsecure
            // (success, ) = receiver.call{value: amount}("");
            // require(address(this).balance >= balanceBefore - amount);
            emit DistributeReward(shareholder, shareholder);
        }
    }

    // function _dayOfMonth(uint256 _timestamp) internal pure returns (uint256) {
    //     (, , uint256 day) = _daysToDate(_timestamp / ONE_DAY);
    //     return day;
    // }

    // date conversion algorithm from http://aa.usno.navy.mil/faq/docs/JD_Formula.php
    // function _daysToDate(
    //     uint256 _days
    // ) internal pure returns (uint256, uint256, uint256) {
    //     int256 __days = int256(_days);

    //     int256 L = __days + 68569 + OFFSET19700101;
    //     int256 N = (4 * L) / 146097;
    //     L = L - (146097 * N + 3) / 4;
    //     int256 _year = (4000 * (L + 1)) / 1461001;
    //     L = L - (1461 * _year) / 4 + 31;
    //     int256 _month = (80 * L) / 2447;
    //     int256 _day = L - (2447 * _month) / 80;
    //     L = _month / 11;
    //     _month = _month + 2 - 12 * L;
    //     _year = 100 * (N - 49) + _year + L;

    //     return (uint256(_year), uint256(_month), uint256(_day));
    // }

    function claimReward() external {
        _distributeReward(msg.sender);
        emit ClaimReward(msg.sender);
    }

    function setUSDCAddress(address _usdc) external onlyOwner {
        usdc = IERC20(_usdc);
    }

    // returns the unpaid rewards
    function getUnpaid(address shareholder) public view returns (uint256) {
        // uint256 earnedRewards = getCumulativeRewards(
        //     shares[shareholder]
        // );
        // uint256 rewardsExcluded = rewards[shareholder].totalExcluded;
        // if (earnedRewards <= rewardsExcluded) {
        //     return 0;
        // }

        // return earnedRewards - rewardsExcluded;
        return unclaimedRewards[shareholder];
    }

    // function getCumulativeRewards(
    //     uint256 share
    // ) internal view returns (uint256) {
    //     return (share * rewardsPerShare) / ACC_FACTOR;
    // }

    function getShares(address user) external view override returns (uint256) {
        return shares[user];
    }

    // function setMinDayOfMonthCanLock(uint8 _day) external onlyOwner {
    //     require(_day <= maxDayOfMonthCanLock, "can set min day above max day");
    //     minDayOfMonthCanLock = _day;
    // }

    // function setMaxDayOfMonthCanLock(uint8 _day) external onlyOwner {
    //     require(_day >= minDayOfMonthCanLock, "can set max day below min day");
    //     maxDayOfMonthCanLock = _day;
    // }

    // function setTimeLock(uint256 numSec) external onlyOwner {
    //     require(numSec <= 365 days, "must be less than a year");
    //     timeLock = numSec;
    // }

    // receive() external payable {
    //     _depositRewards(msg.value);
    // }
}
