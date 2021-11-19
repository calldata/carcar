// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract CarCarGameLogic is Ownable {
    using Address for address;

    // player's car broken or not
    mapping(address => mapping(uint256 => bool)) public isCarBroken;
    
    // player's car in game or not
    mapping(address => mapping(uint256 => bool)) public isCarInGame;

    address public nftAddress;
    IERC20 public cctAddress;
    address public carRepairFeeAddress;
    address public nftOwner;

    event OpenBlindBox(address indexed player);
    event CarRepaired(address indexed player, uint256 indexed carClass);

    constructor(address _nftAddress, address _cctAddress, address _carRepairFeeAddress, address _nftOwner) {
        nftAddress = _nftAddress;
        cctAddress = IERC20(_cctAddress);
        carRepairFeeAddress = _carRepairFeeAddress;
        nftOwner = _nftOwner;
    }

    /// @dev player call this method to enter the game
    ///
    /// @param carClass Wich sort of car player want to use to enter the game
    function enterGame(uint256 carClass) external {
        // TODO: check car class is valid
        address player = msg.sender;
        require(!isCarInGame[player][carClass], "This sort of car is in game");
        isCarInGame[player][carClass] = true;
        require(IERC1155(nftAddress).isApprovedForAll(address(this), player), "Not approved");
        isCarBroken[player][carClass] = false;

        // lock player's car to contract temporarily
        IERC1155(nftAddress).safeTransferFrom(player, address(this), carClass, 1, "");
    }

    /// @dev player call this method to exit the game and check if we should give the car back to him
    ///
    /// @param carClass Which sort of car to exit the game
    /// @return If the car not broken return true, otherwise false
    function exitGame(uint256 carClass) external returns(bool) {
        address player = msg.sender;
        if (isCarBroken[player][carClass]) {
            // player's car is brokn down. he needs to repair the car so that we can give it back to him
            return false;
        } else {
            isCarInGame[player][carClass] = false;
            // player's car is not broken dwon. we just give it back to him
            IERC1155(nftAddress).safeTransferFrom(address(this), player, carClass, 1, "");
            return true;
        }
    }

    /// @dev player call this method to repair their broken car
    ///
    /// @param carClass Which sort of car to repair
    function repair(uint256 carClass) external {
        address player = msg.sender;
        require(isCarBroken[player][carClass], "Car not break down");

        isCarBroken[player][carClass] = false;
        // 50% repair fee be burned
        SafeERC20.safeTransferFrom(cctAddress, msg.sender, address(0), 5000);
        // 50% repair fee as reward to deliver to holder of velodrome
        SafeERC20.safeTransferFrom(cctAddress, msg.sender, carRepairFeeAddress, 5000);

        // emit player's car repaired event
        emit CarRepaired(player, carClass);
    }

    /// @dev deliver repair fee to velodrome holders
    ///
    /// @param addrs Addresses to deliver
    /// @param amounts Amount to deliver for every addr
    function deliverRepairFee(address[] calldata addrs, uint256[] calldata amounts) external onlyOwner {
        require(addrs.length == amounts.length, "length not equal");

        for (uint i = 0; i < addrs.length; i++) {
            SafeERC20.safeTransferFrom(cctAddress, carRepairFeeAddress, addrs[i], amounts[i]);
        }
    }

    /// @dev check if this sort of car is broken
    ///
    /// @param carClass Check which sort of car
    function carBroken(uint256 carClass) view external returns(bool) {
        return isCarBroken[msg.sender][carClass];
    }

    /// @dev let player's car be broken, only owner can call
    ///
    /// @param whose Player that whose car is broken
    /// @param carClass Which sort of car is broken
    function setCarBroken(address whose, uint256 carClass) external onlyOwner {
        require(whose != address(0), "Set zero address");
        require(carClass >= 0 && carClass <= 4, "Unknown car type");
        isCarBroken[whose][carClass] = true;
    }

    /// @dev give away winner fragment to player
    ///
    /// @param to Player address to give awaty winner fragment
    function giveAwayWinnerFragment(address to) external onlyOwner {
        require(to != address(0), "mint to zero address");
        nftAddress.functionCall(abi.encodeWithSignature("mint(address,uint256,uint256)", to));
    }

    /// @dev player claim 1 winner blind box using 10 winner fragments
    function claimWinnerBlindBox() external {
        address player = msg.sender;
        require(player != address(0), "mint to zero address");
        require(IERC1155(nftAddress).balanceOf(player, 5) >= 10, "winner fragments not enough");

        // burn 10 winner fragments
        nftAddress.functionCall(abi.encodeWithSignature("burn(address,uint256,uint256)", player, 5, 10));
        // to mint 1 winner box
        nftAddress.functionCall(abi.encodeWithSignature("mint(address,uint256,uint256)", player, 6, 1));
    }

    /// @dev open winner blind box. player calls this method to trigger an `OpenBlindBox` event.
    /// the backend detect this event and determine which token to deliver to player via calling
    /// `deliverOpenedBlindBox` method
    function openWinnerBlindBoxRequest() external {
        address player = msg.sender;
        require(IERC1155(nftAddress).balanceOf(player, 6) >= 1, "Player has no blind box");

        emit OpenBlindBox(player);
    }

    /// @dev deliver opened blind box to player
    ///
    /// @param player Address to deliver
    /// @param tokenId Which sort of token to deliver
    /// @param amount Amount of token
    function deliverOpenedBlindBox(address player, uint256 tokenId, uint256 amount) external onlyOwner {
        require(player != address(0), "deliver to zero address");

        // pre minted
        if (tokenId >= 0 && tokenId <= 4) {
            IERC1155(nftAddress).safeTransferFrom(nftOwner, player, tokenId, amount, "");
        }

        // fresh mint
        if (tokenId >= 7 && tokenId <= 11) {
            nftAddress.functionCall(abi.encodeWithSignature("mint(address,uint256,uint256)", player, tokenId, amount));
        }
    }
}
