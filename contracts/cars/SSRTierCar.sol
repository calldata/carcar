// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SSRTierCar is ERC721, ERC721Burnable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    bool public isPreMinted;

    constructor() ERC721("Super Super Rare Tier Car", "SSR") {}

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function preMint(uint256 amount, address to) external onlyOwner {
        require(to != address(0), "SSR: Pre minted to zero address");
        require(!isPreMinted, "SSR: Already pre minted");

        for (uint256 i = 0; i < amount; i++) {
            safeMint(to);
        }

        isPreMinted = true;
    }
}
