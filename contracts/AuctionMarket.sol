// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract AuctionMarket is Ownable {
    enum Status {
        OnSell,
        SoldOut,
        Revoked
    }

    struct Auction {
        address seller;
        address nftAddress;
        uint256 tokenId;
        uint256 price;
        uint256 amount;
        Status status;
    }

    // TODO: do we need this event ?
    event NewAuction(address indexed seller, uint256 indexed tokenId);

    mapping(bytes32 => Auction) public auctions;
    address public immutable cctAddress;
    address public immutable nftAddress;

    constructor(address _cctAddress, address _nftAddress) {
        cctAddress = _cctAddress;
        nftAddress = _nftAddress;
    }

    // @dev use sell their nft with provided price and amount
    //
    // @param _tokenId Token id that use want to sell
    // @param _price Price that use want to sell
    // @param _amount Amount that user want to sell
    // @return 
    function enterAuctionMarket(uint256 _tokenId, uint256 _price, uint256 _amount) external returns(bytes32) {
        // TODO: check tokenId exist
        require(_price > 0 && _amount > 0, "Invalid param");

        address seller = msg.sender;

        require(IERC1155(nftAddress).isApprovedForAll(seller, address(this)), "Not approved"); 

        bytes32 auctionId = keccak256(abi.encodePacked(seller, nftAddress, _tokenId, _price));

        if (auctions[auctionId].seller != address(0)) {
            Auction storage auction = auctions[auctionId];
            require(auction.status != Status.SoldOut, "already sold out");
            uint256 totalAuctionAmount = auction.amount + _amount;
            require(totalAuctionAmount <= IERC1155(nftAddress).balanceOf(seller, _tokenId), "User not have enough tokens");
            auction.amount = totalAuctionAmount;
        } else {
            auctions[auctionId] = Auction(seller, nftAddress, _tokenId, _price, _amount, Status.OnSell);
        }

        return auctionId;
    }

    // @dev purchase the specified nft via auctionId
    //
    // @param aunctionId Auction id user want to buy
    // @param _amount Aount user want to buy
    function purchase(bytes32 auctionId, uint256 _amount) external {
        // TODO: optimzie gas usage
        address buyer = msg.sender;
        Auction storage auction = auctions[auctionId];
        require(auction.status == Status.OnSell, "Sold out or revoked");
        require(auction.amount >= _amount, "Not enough token to sell");
        uint256 cost = _amount * auction.price;
        require(IERC20(cctAddress).balanceOf(buyer) >= cost, "Buyer funds not enough");

        auction.status = Status.SoldOut;
        auction.amount -= _amount;

        uint256 fee = cost / 100;
        // 1% fee to Market owner
        SafeERC20.safeTransferFrom(IERC20(cctAddress), buyer, address(this), fee);
        // 99% to seller
        SafeERC20.safeTransferFrom(IERC20(cctAddress), buyer, auction.seller, cost - fee);
        IERC1155(nftAddress).safeTransferFrom(auction.seller, buyer, auction.tokenId, auction.amount, "");
    }

    // @dev revoke auction
    //
    // @param auctionId Auction id to revoke
    function revoke(bytes32 auctionId) external {
        Auction memory auction = auctions[auctionId];
        require(auction.seller != address(0), "unknown auctionId");
        require(auction.status == Status.OnSell, "Only revoke OnSell status auction");

        auctions[auctionId].status = Status.Revoked;
    }

    // @dev withraw cct token to `to` address
    //
    // @param to Address to withraw to
    function withdraw(address to) external onlyOwner {
        uint256 balance = IERC20(cctAddress).balanceOf(address(this));
        SafeERC20.safeTransfer(IERC20(cctAddress), to, balance);
    }
}
