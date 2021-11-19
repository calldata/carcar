// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @notice A mintable ERC20
 */
contract CarCarToken is ERC20, Ownable {
    constructor() ERC20("Car Car Token", "CCT") {
        // 100 billion
        _mint(msg.sender, 1000 * 100000000 * 1 ether);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
