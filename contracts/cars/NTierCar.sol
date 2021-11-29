// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NTierCar is ERC721, ERC721Burnable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("Normal Tier Car", "N") {}

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function batchMint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "N: Mint to zero address");
        require(amount > 0, "N: Amount must greater than 0");

        uint256 tokenId = _tokenIdCounter.current();

        for (uint256 i = tokenId; i < tokenId + amount; i++) {
            _safeMint(to, i);
            _tokenIdCounter.increment();
        }
    }

    function batchTransferFrom(address from, address to, uint256[] calldata tokenIds) external {
        require(from != address(0),  "N: Transfer from zero address");
        require(to != address(0), "N: Transfer to zero address");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            safeTransferFrom(from, to, tokenIds[i]);
        }
    }
}
