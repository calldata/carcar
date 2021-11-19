// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract CarCarNft is ERC1155, Ownable, AccessControl {

    // 4 sort of cars
    uint256 public constant nClassCar = 0;
    uint256 public constant rClassCar = 1;
    uint256 public constant srClassCar = 2;
    uint256 public constant ssrClassCar = 3;
    // Velodrome land
    uint256 public constant velodromeLand = 4;

    // winner fragment
    uint256 public constant winnerFragment = 5;
    // winner box
    uint256 public constant winnerBox = 6;

    // upgrade components
    uint256 public constant nClassUpgradeComp = 7;
    uint256 public constant rClassUpgradeComp = 8;
    uint256 public constant srClassUpgradeComp = 9;
    uint256 public constant ssrClassUpgradeComp = 10;

    // velodrome
    uint256 public constant velodrome = 11;

    constructor() ERC1155("ipfs://xxxx") {
        // pre minted
        _mint(msg.sender, nClassCar, 400000, "");
        _mint(msg.sender, nClassCar, 80000, "");
        _mint(msg.sender, nClassCar, 18000, "");
        _mint(msg.sender, nClassCar, 2000, "");

        _mint(msg.sender, velodromeLand, 1000, "");
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return ERC1155.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }

    function burn(address to, uint256 tokenId, uint256 amount) external {
        require(hasRole("GAME_CONTROLER", msg.sender), "Unauthorized caller");

        _burn(to, tokenId, amount);
    }

    function mint(address to, uint256 tokenId, uint256 amount) external {
        require(hasRole("GAME_CONTROLER", msg.sender), "Unauthorized caller");

        _mint(to, tokenId, amount, "");
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    function tokenIdExist(uint256 _tokenId) pure external returns(bool) {
        return _tokenId >= 0 && _tokenId <= 6;
    }
}
