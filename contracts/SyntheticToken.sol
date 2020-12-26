// SPDX-License-Identifier: MIT

pragma solidity ^0.7.3;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.2.0-solc-0.7/contracts/token/ERC20/ERC20.sol";

contract SyntheticToken is ERC20 {
    constructor(string memory _tokenName, string memory _tokenSymbol)
        ERC20(_tokenName, _tokenSymbol)
    {
        _setupDecimals(0);
    }

    function mint(address _recipient, uint256 _value) public returns (bool) {
        _mint(_recipient, _value);
        return true;
    }

    function burn(uint256 _value) public {
        _burn(msg.sender, _value);
    }
}
