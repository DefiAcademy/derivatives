pragma solidity ^0.7.3;
pragma experimental ABIEncoderV2;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol";

import "./TokenFactory.sol";
import "./PriceIdentifier.sol";
// import "./ExpandedERC20.sol";
import "./Timer.sol";

contract Derivative
{
    using SafeMath for uint256;
    
     // Synthetic token created by this contract.
    PriceIdentifierInterface public priceIdentifierInterfaceInstance;
    ExpandedIERC20 public tokenCurrency;
    Timer public timerInstance;
    ExpandedIERC20 public collateralCurrency;

    // struct Params {
    //     uint256 expirationTimestamp;
    //     address collateralAddress;
    //     address tokenFactoryAddress;
    //     address timerAddress;
    //     bytes32 priceFeedIdentifier;
    //     string syntheticName;
    //     string syntheticSymbol;
    // }
    
    bytes32 public priceIdentifier;
    // Time that this contract expires. Should not change post-construction.
    uint256 public expirationTimestamp;
    
    
    uint256 public minPositionTokens;

    // Stores the state of the PricelessPositionManager. Set on expiration, emergency shutdown, or settlement.
    enum ContractState { Open, ExpiredPriceRequested, ExpiredPriceReceived }
    ContractState public contractState;
    
    // Represents a single sponsor's position. All collateral is held by this contract.
    // This struct acts as bookkeeping for how much of that collateral is allocated to each sponsor.
    struct PositionData {
        uint256 tokensOutstanding;
        // Tracks pending withdrawal requests. A withdrawal request is pending if `withdrawalRequestPassTimestamp != 0`.
        // uint256 withdrawalRequestPassTimestamp;
        // uint256 withdrawalRequestAmount;
        // Raw collateral value. This value should never be accessed directly -- always use _getFeeAdjustedCollateral().
        // To add or remove collateral, use _addCollateral() and _removeCollateral().
        // FixedPoint.Unsigned rawCollateral;
        // Tracks pending transfer position requests. A transfer position request is pending if `transferPositionRequestPassTimestamp != 0`.
        // uint256 transferPositionRequestPassTimestamp;
    }

    // Maps sponsor addresses to their positions. Each sponsor can have only one position.
    mapping(address => PositionData) public positions;
    uint256 public totalTokensOutstanding;

    // Similar to the rawCollateral in PositionData, this value should not be used directly.
    // _getFeeAdjustedCollateral(), _addCollateral() and _removeCollateral() must be used to access and adjust.
    uint256 public rawTotalPositionCollateral;

    // Events
    event PositionCreated(address indexed sponsor, uint256 indexed collateralAmount, uint256 indexed tokenAmount);
    event NewSponsor(address indexed sponsor);
    event Deposit(address indexed sponsor, uint256 indexed collateralAmount);

    constructor(
        uint256 _expirationTimestamp,
        bytes32 _priceIdentifier,
        address _priceIdentifierAdress,
        address _collateralAddress,
        address _tokenFactoryAddress,
        address _timerAddress,
        uint256 _minPositionTokens) public {
        
        timerInstance = Timer(_timerAddress);
        priceIdentifierInterfaceInstance = PriceIdentifierInterface(_priceIdentifierAdress);
        
        require(priceIdentifierInterfaceInstance.isIdentifierSupported(_priceIdentifier), "Unsupported price identifier");
        require(_expirationTimestamp > timerInstance.getCurrentTime(), "Invalid expiration in future");
        
        minPositionTokens = _minPositionTokens;
        priceIdentifier = _priceIdentifier;
        TokenFactory tokenFactory = TokenFactory(_tokenFactoryAddress);
        tokenCurrency = tokenFactory.createToken("SyntheticToken", "SNT");
    }
    
    function createPosition(uint256 collateralAmount, uint256 numTokens) public {
        require(_checkCollateralization(collateralAmount, numTokens), "CR below GCR");

        PositionData storage positionData = positions[msg.sender];
        // require(positionData.withdrawalRequestPassTimestamp == 0, "Pending withdrawal");
        if (positionData.tokensOutstanding == 0) {
            require(numTokens > minPositionTokens, "Below minimum sponsor position");
            emit NewSponsor(msg.sender);
        }

        // Increase the position and global collateral balance by collateral amount.
        // _incrementCollateralBalances(positionData, collateralAmount);

        // Add the number of tokens created to the position's outstanding tokens.
        positionData.tokensOutstanding = positionData.tokensOutstanding.add(numTokens);

        totalTokensOutstanding = totalTokensOutstanding.add(numTokens);

        emit PositionCreated(msg.sender, collateralAmount, numTokens);

        // Transfer tokens into the contract from caller and mint corresponding synthetic tokens to the caller's address.
        collateralCurrency.transferFrom(msg.sender, address(this), collateralAmount);
        require(tokenCurrency.mint(msg.sender, numTokens), "Minting synthetic tokens failed");
    }
    // function isIdentifierSupported() internal returns(bool result){
    //     return PriceIdentifierInterface();
    // }
    
    function deposit(uint256 collateralAmount) public {
        // This is just a thin wrapper over depositTo that specified the sender as the sponsor.
        // depositTo(msg.sender, collateralAmount);
        require(collateralAmount > 0, "Invalid collateral amount");
        PositionData storage positionData = _getPositionData(msg.sender);

        // Increase the position and global collateral balance by collateral amount.
        _incrementCollateralBalances(positionData, collateralAmount);

        emit Deposit(msg.sender, collateralAmount.rawValue);

        // Move collateral currency from sender to contract.
        collateralCurrency.safeTransferFrom(msg.sender, address(this), collateralAmount.rawValue);
    }
    
    function _getPositionData(address sponsor)
        internal
        view
        returns (PositionData storage)
    {
        return positions[sponsor];
    }
        // Checks whether the provided `collateral` and `numTokens` have a collateralization ratio above the global
    // collateralization ratio.
    function _checkCollateralization(uint256 collateral, uint256 numTokens) private view returns (bool) {
        uint256 global = _getCollateralizationRatio(
            rawTotalPositionCollateral,
            totalTokensOutstanding
        );
        uint256 thisChange = _getCollateralizationRatio(collateral, numTokens);
        return !(global > thisChange);
    }

    function _getCollateralizationRatio(uint256 collateral, uint256 numTokens) private pure returns (uint256 ratio) {
        return collateral.div(numTokens);
    }
    
    // Ensure individual and global consistency when increasing collateral balances. Returns the change to the position.
    function _incrementCollateralBalances(PositionData storage positionData, uint256 memory collateralAmount) internal returns (uint256) {
        _addCollateral(positionData.rawCollateral, collateralAmount);
        return _addCollateral(rawTotalPositionCollateral, collateralAmount);
    }
    
    // Increase rawCollateral by a fee-adjusted collateralToAdd amount. Fee adjustment scales up collateralToAdd
    // by dividing it by cumulativeFeeMultiplier. There is potential for this quotient to be floored, therefore
    // rawCollateral is increased by less than expected. Because this method is usually called in conjunction with an
    // actual addition of collateral to this contract, return the fee-adjusted amount that the rawCollateral is
    // increased by so that the caller can minimize error between collateral added and rawCollateral credited.
    // NOTE: This return value exists only for the sake of symmetry with _removeCollateral. We don't actually use it
    // because we are OK if more collateral is stored in the contract than is represented by rawTotalPositionCollateral.
    function _addCollateral(uint256 rawCollateral, uint256 collateralToAdd) internal returns (uint256 addedCollateral) {
        FixedPoint.Unsigned memory initialBalance = _getFeeAdjustedCollateral(rawCollateral);
        FixedPoint.Unsigned memory adjustedCollateral = _convertToRawCollateral(collateralToAdd);
        rawCollateral.rawValue = rawCollateral.add(adjustedCollateral).rawValue;
        addedCollateral = _getFeeAdjustedCollateral(rawCollateral).sub(initialBalance);
    }
    
        /**
     * @notice Locks contract state in expired and requests oracle price.
     * @dev this function can only be called once the contract is expired and can't be re-called.
     */
    function expire() external onlyPostExpiration() onlyOpenState() fees() nonReentrant() {
        contractState = ContractState.ExpiredPriceRequested;

        // The final fee for this request is paid out of the contract rather than by the caller.
        _payFinalFees(address(this), _computeFinalFees());
        _requestOraclePrice(expirationTimestamp);

        emit ContractExpired(msg.sender);
    }
    
        // Returns the user's collateral minus any fees that have been subtracted since it was originally
    // deposited into the contract. Note: if the contract has paid fees since it was deployed, the raw
    // value should be larger than the returned value.
    function _getFeeAdjustedCollateral(FixedPoint.Unsigned memory rawCollateral)
        internal
        view
        returns (FixedPoint.Unsigned memory collateral)
    {
        return rawCollateral.mul(cumulativeFeeMultiplier);
    }
    /**
     * @notice After a contract has passed expiry all token holders can redeem their tokens for underlying at the
     * prevailing price defined by the DVM from the `expire` function.
     * @dev This burns all tokens from the caller of `tokenCurrency` and sends back the proportional amount of
     * `collateralCurrency`. Might not redeem the full proportional amount of collateral in order to account for
     * precision loss. This contract must be approved to spend `tokenCurrency` at least up to the caller's full balance.
     * @return amountWithdrawn The actual amount of collateral withdrawn.
     */
    function settleExpired() external returns (uint256 amountWithdrawn){
        require(contractState != ContractState.Open, "Unexpired position");
    }
    //     // If the contract state is open and onlyPostExpiration passed then `expire()` has not yet been called.
    //     

    //     // Get the current settlement price and store it. If it is not resolved will revert.
    //     if (contractState != ContractState.ExpiredPriceReceived) {
    //         expiryPrice = _getOraclePrice(expirationTimestamp);
    //         contractState = ContractState.ExpiredPriceReceived;
    //     }

    //     // Get caller's tokens balance and calculate amount of underlying entitled to them.
    //     FixedPoint.Unsigned memory tokensToRedeem = FixedPoint.Unsigned(tokenCurrency.balanceOf(msg.sender));
    //     FixedPoint.Unsigned memory totalRedeemableCollateral = tokensToRedeem.mul(expiryPrice);

    //     // If the caller is a sponsor with outstanding collateral they are also entitled to their excess collateral after their debt.
    //     PositionData storage positionData = positions[msg.sender];
    //     if (_getFeeAdjustedCollateral(positionData.rawCollateral).isGreaterThan(0)) {
    //         // Calculate the underlying entitled to a token sponsor. This is collateral - debt in underlying.
    //         FixedPoint.Unsigned memory tokenDebtValueInCollateral = positionData.tokensOutstanding.mul(expiryPrice);
    //         FixedPoint.Unsigned memory positionCollateral = _getFeeAdjustedCollateral(positionData.rawCollateral);

    //         // If the debt is greater than the remaining collateral, they cannot redeem anything.
    //         FixedPoint.Unsigned memory positionRedeemableCollateral = tokenDebtValueInCollateral.isLessThan(
    //             positionCollateral
    //         )
    //             ? positionCollateral.sub(tokenDebtValueInCollateral)
    //             : FixedPoint.Unsigned(0);

    //         // Add the number of redeemable tokens for the sponsor to their total redeemable collateral.
    //         totalRedeemableCollateral = totalRedeemableCollateral.add(positionRedeemableCollateral);

    //         // Reset the position state as all the value has been removed after settlement.
    //         delete positions[msg.sender];
    //         emit EndedSponsorPosition(msg.sender);
    //     }

    //     // Take the min of the remaining collateral and the collateral "owed". If the contract is undercapitalized,
    //     // the caller will get as much collateral as the contract can pay out.
    //     FixedPoint.Unsigned memory payout = FixedPoint.min(
    //         _getFeeAdjustedCollateral(rawTotalPositionCollateral),
    //         totalRedeemableCollateral
    //     );

    //     // Decrement total contract collateral and outstanding debt.
    //     amountWithdrawn = _removeCollateral(rawTotalPositionCollateral, payout);
    //     totalTokensOutstanding = totalTokensOutstanding.sub(tokensToRedeem);

    //     emit SettleExpiredPosition(msg.sender, amountWithdrawn.rawValue, tokensToRedeem.rawValue);

    //     // Transfer tokens & collateral and burn the redeemed tokens.
    //     collateralCurrency.safeTransfer(msg.sender, amountWithdrawn.rawValue);
    //     tokenCurrency.safeTransferFrom(msg.sender, address(this), tokensToRedeem.rawValue);
    //     tokenCurrency.burn(tokensToRedeem.rawValue);
    // }
}
