// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./poolRegistry.sol";
import "./poolStorage.sol";
import "./AconomyFee.sol";
import "./Libraries/LibCalculations.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract poolAddress is poolStorage {
    address poolRegistryAddress;
    address AconomyFeeAddress;
    address public poolOwner;
    uint256 public paymentCycleDuration;
    uint256 public paymentDefaultDuration;
    uint256 public feePercent;
    uint256 public createdAt;

    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    constructor(
        address _poolOwner,
        address _poolRegistry,
        address _AconomyFeeAddress,
        uint256 _paymentCycleDuration,
        uint256 _paymentDefaultDuration,
        uint256 _feePercent
    ) {
        poolOwner = _poolOwner;
        poolRegistryAddress = _poolRegistry;
        AconomyFeeAddress = _AconomyFeeAddress;
        paymentCycleDuration = _paymentCycleDuration;
        paymentDefaultDuration = _paymentDefaultDuration;
        feePercent = _feePercent;
        createdAt = block.timestamp;
    }

    modifier pendingBid(uint256 _loanId) {
        if (loans[_loanId].state != LoanState.PENDING) {
            revert("Bid must be pending");
        }
        _;
    }

    event loanAccepted(uint256 indexed loanId, address indexed lender);
    event AcceptedLoanDetail(
        uint256 indexed loanId,
        string indexed feeType,
        uint256 indexed amount
    );

    event SubmittedLoan(
        uint256 indexed loanId,
        address indexed borrower,
        address receiver,
        uint256 paymentCycleAmount
    );

    function loanRequest(
        address _lendingToken,
        uint256 _poolId,
        uint256 _principal,
        uint32 _duration,
        uint16 _APR,
        address _receiver
    ) public returns (uint256 loanId_) {
        (bool isVerified, ) = poolRegistry(poolRegistryAddress)
            .borrowerVarification(_poolId, msg.sender);
        require(isVerified, "Not verified borrower");
        require(
            !poolRegistry(poolRegistryAddress).ClosedPool(_poolId),
            "Pool is closed"
        );

        loanId_ = loanId;

        // Create and store our loan into the mapping
        Loan storage loan = loans[loanId];
        loan.borrower = msg.sender;
        loan.receiver = _receiver != address(0) ? _receiver : loan.borrower;
        loan.poolId = _poolId;
        loan.loanDetails.lendingToken = ERC20(_lendingToken);
        loan.loanDetails.principal = _principal;
        loan.loanDetails.loanDuration = _duration;
        loan.loanDetails.timestamp = uint32(block.timestamp);

        loan.terms.paymentCycle = poolRegistry(poolRegistryAddress)
            .getPaymentCycleDuration(_poolId);

        loan.terms.APR = _APR;

        loanDefaultDuration[loanId] = poolRegistry(poolRegistryAddress)
            .getPaymentDefaultDuration(_poolId);

        loanExpirationTime[loanId] = poolRegistry(poolRegistryAddress)
            .getloanExpirationTime(_poolId);

        loan.terms.paymentCycleAmount = LibCalculations.payment(
            _principal,
            _duration,
            loan.terms.paymentCycle,
            _APR
        );

        loan.state = LoanState.PENDING;

        emit SubmittedLoan(
            loanId,
            loan.borrower,
            loan.receiver,
            loan.terms.paymentCycleAmount
        );

        // Store bid inside borrower loans mapping
        borrowerLoans[loan.borrower].push(loanId);

        // Increment loan id counter
        loanId++;
    }

    function AcceptLoan(uint256 _loanId)
        external
        pendingBid(_loanId)
        returns (
            uint256 amountToAconomy,
            uint256 amountToPool,
            uint256 amountToBorrower
        )
    {
        Loan storage loan = loans[_loanId];

        (bool isVerified, ) = poolRegistry(poolRegistryAddress)
            .lenderVarification(loan.poolId, msg.sender);

        require(isVerified, "Not verified lender");
        require(
            !poolRegistry(poolRegistryAddress).ClosedPool(loan.poolId),
            "Pool is closed"
        );
        require(!isLoanExpired(_loanId), "Loan has expired");

        loan.loanDetails.acceptedTimestamp = uint32(block.timestamp);
        loan.loanDetails.lastRepaidTimestamp = uint32(block.timestamp);

        loan.state = LoanState.ACCEPTED;

        loan.lender = msg.sender;

        //Aconomy Fee
        amountToAconomy = LibCalculations.percent(
            loan.loanDetails.principal,
            AconomyFee(AconomyFeeAddress).protocolFee()
        );

        //Pool Fee
        amountToPool = LibCalculations.percent(
            loan.loanDetails.principal,
            poolRegistry(poolRegistryAddress).getPoolFee(loan.poolId)
        );

        //Amount to Borrower
        amountToBorrower =
            loan.loanDetails.principal -
            amountToAconomy -
            amountToPool;

        //Transfer Aconomy Fee
        IERC20(loan.loanDetails.lendingToken).transferFrom(
            loan.lender,
            AconomyFee(AconomyFeeAddress).getAconomyOwnerAddress(),
            amountToAconomy
        );

        //Transfer Aconomy Pool Owner
        IERC20(loan.loanDetails.lendingToken).transferFrom(
            loan.lender,
            poolRegistry(poolRegistryAddress).getPoolOwner(loan.poolId),
            amountToPool
        );

        //transfer funds to borrower
        IERC20(loan.loanDetails.lendingToken).transferFrom(
            loan.lender,
            loan.borrower,
            amountToBorrower
        );

        // Record Amount filled by lenders
        lenderLendAmount[address(loan.loanDetails.lendingToken)][
            loan.lender
        ] += loan.loanDetails.principal;
        totalERC20Amount[address(loan.loanDetails.lendingToken)] += loan
            .loanDetails
            .principal;

        // Store Borrower's active loan
        borrowerActiveLoans[loan.borrower].add(_loanId);

        emit loanAccepted(_loanId, loan.lender);

        emit AcceptedLoanDetail(_loanId, "protocol", amountToAconomy);
        emit AcceptedLoanDetail(_loanId, "Pool", amountToPool);
        emit AcceptedLoanDetail(_loanId, "Borrower", amountToBorrower);
    }

    function isLoanExpired(uint256 _loanId) public view returns (bool) {
        Loan storage loan = loans[_loanId];

        if (loan.state != LoanState.PENDING) return false;
        if (loanExpirationTime[_loanId] == 0) return false;

        return (uint32(block.timestamp) >
            loan.loanDetails.timestamp + loanExpirationTime[_loanId]);
    }
}
