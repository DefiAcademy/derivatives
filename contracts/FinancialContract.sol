// SPDX-License-Identifier: MIT

pragma solidity ^0.7.3;

import "./TokenFactory.sol";
import "./SyntheticToken.sol";
import "./CollateralToken.sol";
import "./Timer.sol";
import "./Oracle.sol";

contract FinancialContract {
    TokenFactory public tokenFactory;
    SyntheticToken public syntheticToken;
    CollateralToken public collateralToken;
    Timer public timer;
    Oracle public oracle;

    struct Position {
        uint256 tokensOutstanding;
        uint256 collateralAmount;
    }

    string public priceIdentifier;
    uint256 public finalPrice;

    enum ContractStatus {Open, Settled}

    ContractStatus public currentStatus;

    mapping(address => Position) public positions;

    uint256 public minimunNumberOfTokens;
    uint256 public collateralRatioRequired;

    constructor() {
        minimunNumberOfTokens = 100;

        tokenFactory = TokenFactory(0x9ecEA68DE55F316B702f27eE389D10C2EE0dde84);
        syntheticToken = tokenFactory.createToken("SyntheticToken", "SNT");
        collateralToken = CollateralToken(
            0x99CF4c4CAE3bA61754Abd22A8de7e8c7ba3C196d
        );
        timer = Timer(0x746C5707Bfd8a4Be44332F21AC78A28e9340a9F4);
        oracle = Oracle(0xDA0bab807633f07f013f94DD0E6A4F96F8742B53);

        priceIdentifier = "METH/USD";
        collateralRatioRequired = 2;
        currentStatus = ContractStatus.Open;
        require(
            oracle.isSupportedIdentifer(priceIdentifier),
            "Not supported price identifier"
        );
    }

    function createPosition(uint256 _numberOfTokens, uint256 _collateralAmount)
        public
    {
        require(
            _collateralAmount / _numberOfTokens > collateralRatioRequired,
            "Below collateral ratio"
        );
        require(currentStatus == ContractStatus.Open, "Contract is not open");
        require(
            _numberOfTokens >= minimunNumberOfTokens,
            "Below minimum number of tokens"
        );

        Position storage currentPosition = positions[msg.sender];
        currentPosition.tokensOutstanding = _numberOfTokens;
        currentPosition.collateralAmount = _collateralAmount;

        syntheticToken.mint(msg.sender, _numberOfTokens);
        collateralToken.transferFrom(
            msg.sender,
            address(this),
            _collateralAmount
        );
    }

    enum LiquidationStatus {
        Liquidated,
        PendingDispute,
        DisputeSucceeded,
        DisputeFailed
    }

    struct Liquidation {
        address sponsor;
        address liquidator;
        uint256 liquidationTime;
        address disputer;
        uint256 settlementPrice;
        uint256 collateralLocked; // collateral locked of disputer + liquidator
        uint256 liquidatedCollateral;
        uint256 tokensLiquidated;
        LiquidationStatus status;
    }

    uint256 public numberOfLiquidations;

    mapping(uint256 => Liquidation) public liquidations;

    function createLiquidation(address _tokenSponsor) public {
        numberOfLiquidations = numberOfLiquidations + 1;

        Position storage positionToLiquidate = positions[_tokenSponsor];

        Liquidation storage newLiquidation = liquidations[numberOfLiquidations];
        newLiquidation.sponsor = _tokenSponsor;
        newLiquidation.liquidator = msg.sender;
        newLiquidation.liquidationTime = timer.getTime();
        newLiquidation.disputer = address(0);
        newLiquidation.settlementPrice = 0;
        newLiquidation.collateralLocked = positionToLiquidate.collateralAmount;
        newLiquidation.liquidatedCollateral = positionToLiquidate
            .collateralAmount;
        newLiquidation.tokensLiquidated = positionToLiquidate.tokensOutstanding;
        newLiquidation.status = LiquidationStatus.Liquidated;
        uint256 tokensToLiquidate = positionToLiquidate.tokensOutstanding;

        syntheticToken.transferFrom(
            msg.sender,
            address(this),
            tokensToLiquidate
        );

        syntheticToken.burn(tokensToLiquidate);

        collateralToken.transferFrom(
            msg.sender,
            address(this),
            positionToLiquidate.collateralAmount
        );

        delete positions[_tokenSponsor];
    }

    function disputeLiquidation(uint256 _liquidationId) public {
        Liquidation storage liquidation = liquidations[_liquidationId];

        liquidation.disputer = msg.sender;

        liquidation.settlementPrice = oracle.getPrice(priceIdentifier);

        liquidation.collateralLocked =
            liquidation.collateralLocked +
            liquidation.liquidatedCollateral;

        collateralToken.transferFrom(
            msg.sender,
            address(this),
            liquidation.liquidatedCollateral
        );
    }

    function settleLiquidation(uint256 _liquidationId) public {
        Liquidation storage liquidation = liquidations[_liquidationId];

        require(
            (msg.sender == liquidation.disputer) ||
                (msg.sender == liquidation.liquidator) ||
                (msg.sender == liquidation.sponsor),
            "Caller cannot withdraw rewards"
        );

        uint256 tokenRedentiomValue =
            liquidation.tokensLiquidated * liquidation.settlementPrice;

        uint256 requiredCollateral =
            tokenRedentiomValue * collateralRatioRequired;

        bool disputeSucceeded =
            liquidation.liquidatedCollateral >= requiredCollateral;
        liquidation.status = disputeSucceeded
            ? LiquidationStatus.DisputeSucceeded
            : LiquidationStatus.DisputeFailed;

        if (disputeSucceeded) {
            collateralToken.transfer(
                liquidation.disputer,
                liquidation.collateralLocked
            );
        } else {
            collateralToken.transfer(
                liquidation.liquidator,
                liquidation.collateralLocked
            );
        }

        delete liquidations[_liquidationId];
    }

    function settle() public {
        currentStatus = ContractStatus.Settled;
        finalPrice = oracle.getPrice(priceIdentifier);
    }
}
