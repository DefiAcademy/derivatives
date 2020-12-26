// SPDX-License-Identifier: MIT

pragma solidity ^0.7.3;

contract Oracle {
    // How are prices stored?
    // price identifier => ETH/USD, ETH/BTC
    mapping(string => bool) private supportedIdentifiers;
    mapping(string => uint256) private prices;

    function setPrice(string memory _priceIdentifier, uint256 _newPrice)
        public
    {
        require(
            supportedIdentifiers[_priceIdentifier],
            "Not supported price identifier"
        );
        prices[_priceIdentifier] = _newPrice;
    }

    function getPrice(string memory _priceIdentifier)
        public
        view
        returns (uint256)
    {
        return prices[_priceIdentifier];
    }

    function addPriceIdentifier(string memory _priceIdentifier) public {
        supportedIdentifiers[_priceIdentifier] = true;
    }

    function isSupportedIdentifer(string memory _priceIdentifier)
        public
        view
        returns (bool)
    {
        return supportedIdentifiers[_priceIdentifier];
    }
}
