// SPDX-License-Identifier: MIT

pragma solidity ^0.7.3;

import "./SyntheticToken.sol";

contract TokenFactory {
    function createToken(string memory _tokenName, string memory _tokenSymbol)
        public
        returns (SyntheticToken)
    {
        SyntheticToken newSyntheticToken =
            new SyntheticToken(_tokenName, _tokenSymbol);

        return newSyntheticToken;
    }
}
