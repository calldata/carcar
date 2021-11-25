// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Staking is Ownable {
    using Address for address;

    struct StakingStrategy {
        uint256 amount;
        uint256 duration;
        address rewardNft;
    }

    struct StakingDetail {
        address staker;
        bytes32 strategyId;
        uint256 startAt;
    }

    // mapping of id to stake details
    mapping(bytes32 => StakingDetail) public allStakings;

    // mapping of strategies
    mapping(bytes32 => StakingStrategy) public strategies;

    // mapping of if strategy has active user
    mapping(bytes32 => uint256) public strategyActiveUsers;

    // mapping of strategy will be removed or not
    mapping(bytes32 => bool) public strategyWillBeRemoved;

    // cct token address
    IERC20 public cctToken;

    event CreateNewStrategy(uint256 amount, uint256 duration, address rewardNft);
    event RemoveStrategy(bytes32 strategyId);

    event CreateNewStaking(
        address indexed staker,
        bytes32 indexed stakingId,
        bytes32 indexed strategyId,
        uint256 startAt
    );
    event StakingFinished(address indexed staker, bytes32 indexed stakingId);
    event EarlyUnstake(address indexed staker, bytes32 indexed stakingId);

    constructor(address _cctToken) {
        cctToken = IERC20(_cctToken);
    }

    /// @dev create a new staking strategy
    ///
    /// @param amount How much cct tokens needed
    /// @param duration Staking duration in seconds
    /// @param rewardNft Which nft will be rewarded when staking finshed
    function createNewStrategy(
        uint256 amount,
        uint256 duration,
        address rewardNft
    ) external onlyOwner {
        bytes32 strategyId = calcStrategyId(amount, duration, rewardNft);
        strategies[strategyId] = StakingStrategy(amount, duration, rewardNft);

        emit CreateNewStrategy(amount, duration, rewardNft);
    }

    function calcStrategyId(
        uint256 amount,
        uint256 duration,
        address rewardNft
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(amount, duration, rewardNft));
    }

    function calcStakingId(
        address staker,
        bytes32 strategyId,
        uint256 startAt
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(staker, strategyId, startAt));
    }

    function getStakeStrategy(bytes32 strategyId) external view returns (StakingStrategy memory) {
        return strategies[strategyId];
    }

    function getStakeDetail(bytes32 stakeId) external view returns (StakingDetail memory) {
        return allStakings[stakeId];
    }

    /// @dev remove a staking strategy
    ///
    /// @param strategyId strategy id
    function removeStrategy(bytes32 strategyId) external onlyOwner {
        require(strategies[strategyId].rewardNft != address(0), "Stake: Strategy id not exist");
        require(strategyActiveUsers[strategyId] == 0, "Stake: Strategy has active user");

        delete strategies[strategyId];

        emit RemoveStrategy(strategyId);
    }

    function setStrategyWillBeRemoved(bytes32 strategyId, bool remove) external onlyOwner {
        strategyWillBeRemoved[strategyId] = remove;
    }

    function stake(bytes32 strategyId) external {
        require(!strategyWillBeRemoved[strategyId], "Stake: This Strategy will be removed");
        StakingStrategy memory strategy = strategies[strategyId];

        address staker = msg.sender;
        // transfer user's cct token to contract
        SafeERC20.safeTransferFrom(cctToken, staker, address(this), strategy.amount);

        uint256 startAt = block.timestamp;
        bytes32 stakeId = calcStakingId(staker, strategyId, startAt);
        allStakings[stakeId] = StakingDetail(staker, strategyId, startAt);

        // incement strategy active user
        strategyActiveUsers[strategyId]++;

        emit CreateNewStaking(staker, stakeId, strategyId, block.timestamp);
    }

    function unstake(bytes32 stakeId) external {
        address staker = msg.sender;

        StakingDetail storage detail = allStakings[stakeId];

        require(detail.staker == staker, "Stake: Unautherized caller");

        StakingStrategy memory strategy = strategies[detail.strategyId];
        bytes32 stakingId = calcStakingId(staker, detail.strategyId, detail.startAt);

        if (detail.startAt + strategy.duration < block.timestamp) {
            // backend detect this event and deliver reward to player
            emit StakingFinished(staker, stakingId);
        } else {
            // early unstake will not be rewarded
            emit EarlyUnstake(staker, stakingId);
        }

        // decrement strategy active user
        strategyActiveUsers[detail.strategyId]--;

        delete allStakings[stakeId];

        // no matter staking finshed or not, we will give back staked token to player
        SafeERC20.safeTransfer(cctToken, staker, strategy.amount);
    }
}
