// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Libraries/LibPool.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./Libraries/LibCalculations.sol";
import "./poolRegistry.sol";

contract deployPool {
    address poolOwner;
    address poolRegistryAddress;
    uint256 paymentCycleDuration;
    uint256 paymentDefaultDuration;
    uint256 feePercent;

    constructor(
        address _poolOwner,
        address _poolRegistry,
        uint256 _paymentCycleDuration,
        uint256 _paymentDefaultDuration,
        uint256 _feePercent
    ) {
        poolOwner = _poolOwner;
        poolRegistryAddress = _poolRegistry;
        paymentCycleDuration = _paymentCycleDuration;
        paymentDefaultDuration = _paymentDefaultDuration;
        feePercent = _feePercent;
    }

    modifier onlyPoolOwner(uint256 poolId) {
        require(
            msg.sender == poolRegistry(poolRegistryAddress).getPoolOwner(poolId)
        );
        _;
    }

    uint256 public bidId = 0;

    event BidRepaid(uint256 indexed bidId);
    event BidRepayment(uint256 indexed bidId);

    event AcceptedBid(
        address reciever,
        uint256 BidId,
        uint256 PoolId,
        uint256 Amount,
        uint256 paymentCycleAmount
    );

    event SupplyToPool(
        address indexed lender,
        uint256 indexed poolId,
        uint256 BidId,
        address indexed ERC20Token,
        uint256 tokenAmount
    );

    event repaidAmounts(
        uint256 owedAmount,
        uint256 dueAmount,
        uint256 interest
    );

    event paidAmount(uint256 Amount, uint256 interest);

    struct FundDetail {
        uint256 amount;
        uint32 expiration;
        uint32 maxDuration;
        uint16 interestRate;
        BidState state;
        uint32 bidTimestamp;
        uint32 acceptBidTimestamp;
        uint256 paymentCycleAmount;
        uint256 totalRepaidPrincipal;
        uint32 lastRepaidTimestamp;
        RePayment Repaid;
    }

    struct RePayment {
        uint256 amount;
        uint256 interest;
    }

    enum BidState {
        PENDING,
        CANCELLED,
        ACCEPTED,
        PAID
    }

    // Mapping of lender address => poolId => ERC20 token => FundDetail
    mapping(address => mapping(uint256 => mapping(address => mapping(uint256 => FundDetail))))
        public lenderPoolFundDetails;

    //Supply to pool by lenders
    function supplyToPool(
        uint256 _poolId,
        address _ERC20Address,
        uint256 _amount,
        uint32 _maxLoanDuration,
        uint16 _interestRate,
        uint32 _expiration
    ) external {
        (bool isVerified, ) = poolRegistry(poolRegistryAddress)
            .lenderVarification(_poolId, msg.sender);

        require(isVerified, "Not verified lender");

        address lender = msg.sender;
        require(_expiration > uint32(block.timestamp), "wrong timestamp");
        uint256 _bidId = bidId;
        FundDetail storage fundDetail = lenderPoolFundDetails[lender][_poolId][
            _ERC20Address
        ][_bidId];
        fundDetail.amount = _amount;
        fundDetail.expiration = _expiration;
        fundDetail.maxDuration = _maxLoanDuration;
        fundDetail.interestRate = _interestRate;
        fundDetail.bidTimestamp = uint32(block.timestamp);

        fundDetail.state = BidState.PENDING;

        address _poolAddress = poolRegistry(poolRegistryAddress).getPoolAddress(
            _poolId
        );

        // Send payment to the Pool
        IERC20(_ERC20Address).transferFrom(lender, _poolAddress, _amount);
        bidId++;

        emit SupplyToPool(lender, _poolId, _bidId, _ERC20Address, _amount);
    }

    function AcceptBid(
        uint256 _poolId,
        address _ERC20Address,
        uint256 _bidId,
        address _lender,
        address _receiver
    ) external onlyPoolOwner(_poolId) {
        FundDetail storage fundDetail = lenderPoolFundDetails[_lender][_poolId][
            _ERC20Address
        ][_bidId];
        if (fundDetail.state != BidState.PENDING) {
            revert("Bid must be pending");
        }
        fundDetail.acceptBidTimestamp = uint32(block.timestamp);
        uint256 amount = fundDetail.amount;
        fundDetail.state = BidState.ACCEPTED;
        address _poolAddress = poolRegistry(poolRegistryAddress).getPoolAddress(
            _poolId
        );
        uint32 paymentCycle = poolRegistry(poolRegistryAddress)
            .getPaymentCycleDuration(_poolId);

        fundDetail.paymentCycleAmount = LibCalculations.payment(
            amount,
            fundDetail.maxDuration,
            paymentCycle,
            fundDetail.interestRate
        );

        IERC20(_ERC20Address).approve(_receiver, amount);
        IERC20(_ERC20Address).transfer(_receiver, amount);

        emit AcceptedBid(
            _receiver,
            _bidId,
            _poolId,
            amount,
            fundDetail.paymentCycleAmount
        );
    }

    function RepayInstallment(
        uint256 _poolId,
        address _ERC20Address,
        uint256 _bidId,
        address _lender
    ) external onlyPoolOwner(_poolId) {
        FundDetail storage fundDetail = lenderPoolFundDetails[_lender][_poolId][
            _ERC20Address
        ][_bidId];
        if (fundDetail.state != BidState.ACCEPTED) {
            revert("Bid must be pending");
        }

        uint32 paymentCycle = poolRegistry(poolRegistryAddress)
            .getPaymentCycleDuration(_poolId);

        (
            uint256 owedAmount,
            uint256 dueAmount,
            uint256 interest
        ) = LibCalculations.calculateInstallmentAmount(
                fundDetail.amount,
                fundDetail.Repaid.amount,
                fundDetail.interestRate,
                fundDetail.paymentCycleAmount,
                paymentCycle,
                fundDetail.lastRepaidTimestamp,
                block.timestamp,
                fundDetail.acceptBidTimestamp,
                fundDetail.maxDuration
            );
        _repayBid(
            _poolId,
            _ERC20Address,
            _bidId,
            _lender,
            dueAmount,
            interest,
            owedAmount + interest
        );

        emit repaidAmounts(owedAmount, dueAmount, interest);
    }

    function RepayFullAmount(
        uint256 _poolId,
        address _ERC20Address,
        uint256 _bidId,
        address _lender
    ) external onlyPoolOwner(_poolId) {
        FundDetail storage fundDetail = lenderPoolFundDetails[_lender][_poolId][
            _ERC20Address
        ][_bidId];
        if (fundDetail.state != BidState.ACCEPTED) {
            revert("Bid must be pending");
        }

        uint32 paymentCycle = poolRegistry(poolRegistryAddress)
            .getPaymentCycleDuration(_poolId);

        (uint256 owedAmount, , uint256 interest) = LibCalculations
            .calculateInstallmentAmount(
                fundDetail.amount,
                fundDetail.Repaid.amount,
                fundDetail.interestRate,
                fundDetail.paymentCycleAmount,
                paymentCycle,
                fundDetail.lastRepaidTimestamp,
                block.timestamp,
                fundDetail.acceptBidTimestamp,
                fundDetail.maxDuration
            );
        _repayBid(
            _poolId,
            _ERC20Address,
            _bidId,
            _lender,
            owedAmount,
            interest,
            owedAmount + interest
        );

        emit paidAmount(owedAmount, interest);
    }

    function _repayBid(
        uint256 _poolId,
        address _ERC20Address,
        uint256 _bidId,
        address _lender,
        uint256 _amount,
        uint256 _interest,
        uint256 _owedAmount
    ) internal {
        FundDetail storage fundDetail = lenderPoolFundDetails[_lender][_poolId][
            _ERC20Address
        ][_bidId];

        uint256 paymentAmount = _amount + _interest;

        // Check if we are sending a payment or amount remaining
        if (paymentAmount >= _owedAmount) {
            paymentAmount = _owedAmount;

            fundDetail.state = BidState.PAID;
            emit BidRepaid(_bidId);
        } else {
            emit BidRepayment(_bidId);
        }
        // Send payment to the lender
        IERC20(_ERC20Address).transferFrom(msg.sender, _lender, paymentAmount);

        fundDetail.Repaid.amount += _amount;
        fundDetail.Repaid.interest += _interest;
        fundDetail.lastRepaidTimestamp = uint32(block.timestamp);
    }
}
