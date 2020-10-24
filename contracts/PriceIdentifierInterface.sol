pragma solidity ^0.7.3;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

interface PriceIdentifierInterface {
    function addSupportedIdentifier(bytes32 identifier) external;

    function removeSupportedIdentifier(bytes32 identifier) external;

    function isIdentifierSupported(bytes32 identifier) external view returns (bool);
}

contract PriceIdentifier is  PriceIdentifierInterface, Ownable {
    mapping(bytes32 => bool) private supportedIdentifiers;

    function addSupportedIdentifier(bytes32 identifier) external override onlyOwner {
        if (!supportedIdentifiers[identifier]) {
            supportedIdentifiers[identifier] = true;
        }
    }
    
   function removeSupportedIdentifier(bytes32 identifier) external override onlyOwner {
        if (supportedIdentifiers[identifier]) {
            supportedIdentifiers[identifier] = false;
        }
    }
    
    function isIdentifierSupported(bytes32 identifier) external override view returns (bool) {
        return supportedIdentifiers[identifier];
    }
     
}
