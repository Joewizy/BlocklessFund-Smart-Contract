// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockCNGN is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {}

    // Mint new tokens to a specific address (used for testing)
    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
    
    // Burn tokens from a specific address (optional, for testing)
    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }
}
