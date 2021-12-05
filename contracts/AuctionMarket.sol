// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract AuctionMarket is Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _auctionId;

    enum Status {
        OnSell,
        SoldOut,
        Revoked
    }

    struct Auction {
        address nftAddress;
        address seller;
        uint256[] _tokenIds;
        uint256 price;
    }

    event CreateNewAuction(uint256 indexed auctionId);
    event Purchase(address indexed addr, uint256[] tokenIds);
    event Revoke(address indexed addr, uint256[] tokenIds);

    // mapping of auctionId to Auction
    mapping(uint256 => Auction) public auctions;

    // mapping of auction status
    mapping(uint256 => Status) public auctionStatus;

    // car car token address
    address public immutable cctAddress;

    constructor(address _cctAddress) {
        cctAddress = _cctAddress;
    }

    /// @dev get active auction
    ///
    /// @param _aid auction id
    /// @return the details of this auction
    function getActiveAuction(uint256 _aid) external view returns (Auction memory) {
        require(auctionStatus[_aid] == Status.OnSell, "AM: Auction finished");

        return auctions[_aid];
    }

    /// @notice user must approve this contract to take ownership of their nfts
    /// @dev user sell their nft with provided price and amount
    ///
    /// @param _nftAddress Address of the nft to sell
    /// @param _tokenIds Token id that use want to sell
    /// @param _price Price that use want to sell
    function sellItem(
        address _nftAddress,
        uint256[] calldata _tokenIds,
        uint256 _price
    ) external {
        address seller = msg.sender;

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            // transfer ownership to this contract
            IERC721(_nftAddress).safeTransferFrom(seller, address(this), _tokenIds[i]);
        }

        uint256 aId = _nextAuctionId();
        // create new acution
        auctions[aId] = Auction(_nftAddress, seller, _tokenIds, _price);

        auctionStatus[aId] = Status.OnSell;

        emit CreateNewAuction(aId);
    }

    /// @dev purchase the specified nft via auctionId
    ///
    /// @param _aid Auction id user want to buy
    function purchase(uint256 _aid) external {
        require(auctionStatus[_aid] == Status.OnSell, "AM: Invalid auction status");
        address buyer = msg.sender;
        Auction storage auction = auctions[_aid];
        require(buyer != auction.seller, "AM: Buyer and seller are the same");

        delete auctions[_aid];

        auctionStatus[_aid] = Status.SoldOut;

        uint256 cost = auction._tokenIds.length * auction.price;
        require(IERC20(cctAddress).balanceOf(buyer) >= cost, "AM: Buyer funds not enough");

        uint256 fee = cost / 100;
        // 1% fee to Market owner
        SafeERC20.safeTransferFrom(IERC20(cctAddress), buyer, address(this), fee);
        // the remaining to seller
        SafeERC20.safeTransferFrom(IERC20(cctAddress), buyer, auction.seller, cost - fee);

        // transfer nft from this contract to buyer
        for (uint256 i = 0; i < auction._tokenIds.length; i++) {
            IERC721(auction.nftAddress).safeTransferFrom(address(this), buyer, auction._tokenIds[i]);
        }

        emit Purchase(buyer, auction._tokenIds);
    }

    /// @dev revoke auction
    ///
    /// @param _aid Auction id to revoke
    function revoke(uint256 _aid) external {
        Auction memory auction = auctions[_aid];

        require(msg.sender == auction.seller, "AM: Unautherized revoke");
        require(auctionStatus[_aid] == Status.OnSell, "AM: Not on sell");

        // give back user's token
        for (uint256 i = 0; i < auction._tokenIds.length; i++) {
            IERC721(auction.nftAddress).safeTransferFrom(address(this), auction.seller, auction._tokenIds[i]);
        }

        emit Revoke(auction.seller, auction._tokenIds);

        delete auctions[_aid];

        auctionStatus[_aid] = Status.Revoked;
    }

    /// @dev withraw cct token to `to` address
    ///
    /// @param to Address to withraw to
    function withdraw(address to) external onlyOwner {
        uint256 balance = IERC20(cctAddress).balanceOf(address(this));
        SafeERC20.safeTransfer(IERC20(cctAddress), to, balance);
    }

    function _nextAuctionId() internal returns (uint256) {
        _auctionId.increment();
        return _auctionId.current();
    }
}
