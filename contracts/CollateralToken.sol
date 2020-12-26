// SPDX-License-Identifier: MIT

pragma solidity ^0.7.3;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.2.0-solc-0.7/contracts/token/ERC20/ERC20.sol";

contract CollateralToken is ERC20 {
    constructor() ERC20("METH", "METH") {
        _setupDecimals(0);
        _mint(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 100000); // token sponsor
        _mint(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, 100000); // liquidator
        _mint(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db, 100000); // disputer
    }
}
