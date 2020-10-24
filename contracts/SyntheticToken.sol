pragma solidity ^0.7.3;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

contract SyntheticToken is ERC20 {

    constructor (string memory tokenName, string memory tokenSymbol) public ERC20(tokenName, tokenSymbol) {
        _mint(msg.sender, 1000);
    }
    
    function mint(address recipient, uint256 value) external returns (bool) {
        _mint(recipient, value);
        return true;
    }

    function burn(uint256 value) external {
        _burn(msg.sender, value);
    }
}
