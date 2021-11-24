// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract CarCarGameLogic is Ownable {
    using Address for address;

    // player's car broken or not
    mapping(address => mapping(bytes32 => bool)) public isCarBroken;

    // player's car in game or not
    mapping(address => mapping(bytes32 => bool)) public isCarInGame;

    // burn address
    address public constant BURN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    IERC20 public cctAddress;
    address public carRepairFeeAddress;

    event PlayerCarBroken(address indexed player);
    event CarRepaired(address indexed player, uint256 indexed carClass);
    event PlayerEnterGame(address indexed player);
    event PlayerExitGame(address indexed player);

    constructor(address _cctAddress, address _carRepairFeeAddress) {
        cctAddress = IERC20(_cctAddress);
        carRepairFeeAddress = _carRepairFeeAddress;
    }

    /// @dev player call this method to enter the game
    ///
    /// @param carNftAddress Player's car nft address
    /// @param carId Car's token id
    function enterGame(address carNftAddress, uint256 carId) external {
        address player = msg.sender;
        bytes32 id = keccak256(abi.encode(carNftAddress, carId));
        require(!isCarInGame[player][id], "CCGL: Car in game");

        isCarInGame[player][id] = true;

        // transfer the ownership of this car to contract
        IERC721(carNftAddress).transferFrom(player, address(this), carId);

        emit PlayerEnterGame(player);
    }

    /// @dev player call this method to exit the game and check if we should give the car back to him
    ///
    /// @param carNftAddress Player's car nft address
    /// @param carId Car token id to exit
    function exitGame(address carNftAddress, uint256 carId) external {
        address player = msg.sender;
        bytes32 id = keccak256(abi.encode(carNftAddress, carId));

        if (!isCarBroken[player][id]) {
            isCarInGame[player][id] = false;
            // player's car is not broken, we just give it back to him
            IERC721(carNftAddress).transferFrom(address(this), player, carId);
        } else {
            revert("CCGL: Player car broken");
        }
    }

    /// @dev player call this method to repair their broken car
    ///
    /// @param carNftAddress Player's car nft address
    /// @param carId Car token id
    function repair(address carNftAddress, uint256 carId) external {
        address player = msg.sender;
        bytes32 id = keccak256(abi.encode(carNftAddress, carId));
        require(isCarBroken[player][id], "CCGL: Car not broken");

        isCarBroken[player][id] = false;
        // 50% repair fee be burned
        SafeERC20.safeTransferFrom(cctAddress, player, BURN_ADDRESS, 5000);
        // 50% repair fee as reward to deliver to holder of velodrome
        SafeERC20.safeTransferFrom(cctAddress, player, carRepairFeeAddress, 5000);

        // emit player's car repaired event
        emit CarRepaired(player, carId);
    }

    /// @dev check if this sort of car is broken
    ///
    /// @param carNftAddress Player's car nft address
    /// @param carId Car token id
    function carBroken(address carNftAddress, uint256 carId) external view returns (bool) {
        bytes32 id = keccak256(abi.encode(carNftAddress, carId));
        return isCarBroken[msg.sender][id];
    }

    /// @dev let player's car be broken, only owner can call
    ///
    /// @param carNftAddress Player's car nft address
    /// @param player Whose car is broken
    /// @param carId Car token id
    function setCarBroken(
        address carNftAddress,
        uint256 carId,
        address player
    ) external onlyOwner {
        bytes32 id = keccak256(abi.encode(carNftAddress, carId));
        require(isCarInGame[player][id], "CCGL: Player car not in game");

        isCarBroken[player][id] = true;

        emit PlayerCarBroken(player);
    }

    /// @dev deliver repair fee to velodrome holders
    ///
    /// @param addrs Addresses to deliver
    /// @param amounts Amount to deliver for every addr
    function deliverRepairFee(address[] calldata addrs, uint256[] calldata amounts) external onlyOwner {
        require(addrs.length == amounts.length, "CCGL: Length not equal");

        for (uint256 i = 0; i < addrs.length; i++) {
            SafeERC20.safeTransferFrom(cctAddress, carRepairFeeAddress, addrs[i], amounts[i]);
        }
    }
}
