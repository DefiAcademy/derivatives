pragma solidity ^0.6.10;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

abstract contract ExpandedIERC20 is ERC20 {
    function burn(uint256 value) external virtual;

    function mint(address to, uint256 value) external virtual returns (bool);
}

contract ExpandedERC20 is ExpandedIERC20 {
   
    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint8 _tokenDecimals
    ) public ERC20(_tokenName, _tokenSymbol) {
        _setupDecimals(_tokenDecimals);
        // _createExclusiveRole(uint256(Roles.Owner), uint256(Roles.Owner), msg.sender);
        // _createSharedRole(uint256(Roles.Minter), uint256(Roles.Owner), new address[](0));
        // _createSharedRole(uint256(Roles.Burner), uint256(Roles.Owner), new address[](0));
    }


    function mint(address recipient, uint256 value)
        external override
        returns (bool)
    {
        _mint(recipient, value);
        return true;
    }

    /**
     * @dev Burns `value` tokens owned by `msg.sender`.
     * @param value amount of tokens to burn.
     */
    function burn(uint256 value) external override{
        _burn(msg.sender, value);
    }
}
