// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract AuctionMarket is Ownable {
    struct Auction {
        address seller;
        uint256 tokenId;
        uint256 price;
        uint256 amount;
    }

    event NewItemAuctionId(bytes32 indexed auctionId);

    mapping(bytes32 => Auction) public auctions;
    address public immutable cctAddress;
    address public immutable nftAddress;

    constructor(address _cctAddress, address _nftAddress) {
        cctAddress = _cctAddress;
        nftAddress = _nftAddress;
    }

    function getAuctionItem(bytes32 auctionId) view external returns(Auction memory) {
        return auctions[auctionId];
    }

    function calcItemAuctionId(Auction calldata auction) pure external returns(bytes32) {
        return keccak256(abi.encodePacked(auction.seller, auction.tokenId, auction.price));
    }

    /// @dev use sell their nft with provided price and amount
    ///
    /// @param _tokenId Token id that use want to sell
    /// @param _price Price that use want to sell
    /// @param _amount Amount that user want to sell
    function sellItem(uint256 _tokenId, uint256 _price, uint256 _amount) external {
        require(_amount > 0, "Invalid param");

        address seller = msg.sender;

        require(IERC1155(nftAddress).isApprovedForAll(seller, address(this)), "Not approved"); 

        bytes32 auctionId = keccak256(abi.encodePacked(seller, _tokenId, _price));

        // seller append more tokens with same price
        if (auctions[auctionId].seller != address(0)) {
            auctions[auctionId].amount += _amount;
        } else {
            auctions[auctionId] = Auction(seller, _tokenId, _price, _amount);
        }

        emit NewItemAuctionId(auctionId);
    }

    /// @dev purchase the specified nft via auctionId
    ///
    /// @param auctionId Auction id user want to buy
    /// @param _amount Aount user want to buy
    function purchase(bytes32 auctionId, uint256 _amount) external {
        // TODO: optimzie gas usage
        address buyer = msg.sender;
        Auction storage auction = auctions[auctionId];
        require(auction.amount >= _amount, "Not enough token to sell");
        uint256 cost = _amount * auction.price;
        require(IERC20(cctAddress).balanceOf(buyer) >= cost, "Buyer funds not enough");

        auction.amount -= _amount;

        uint256 fee = cost / 100;
        // 1% fee to Market owner
        SafeERC20.safeTransferFrom(IERC20(cctAddress), buyer, address(this), fee);
        // the remaining to seller
        SafeERC20.safeTransferFrom(IERC20(cctAddress), buyer, auction.seller, cost - fee);
        IERC1155(nftAddress).safeTransferFrom(auction.seller, buyer, auction.tokenId, auction.amount, "");
    }

    /// @dev revoke auction
    ///
    /// @param auctionId Auction id to revoke
    function revoke(bytes32 auctionId) external {
        Auction memory auction = auctions[auctionId];
        require(auction.seller != address(0), "unknown auctionId");
        delete auctions[auctionId];
    }

    /// @dev withraw cct token to `to` address
    ///
    /// @param to Address to withraw to
    function withdraw(address to) external onlyOwner {
        uint256 balance = IERC20(cctAddress).balanceOf(address(this));
        SafeERC20.safeTransfer(IERC20(cctAddress), to, balance);
    }
}
