pragma solidity ^0.7.3;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

contract CollateralToken is ERC20 {

    constructor () public ERC20("CollateralToken", "CLT") {
        _mint(msg.sender, 1000);
    }
}
