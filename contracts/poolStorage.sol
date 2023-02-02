pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract poolStorage {
    using EnumerableSet for EnumerableSet.UintSet;
    // Current number of loans.
    uint256 public loanId = 0;

    // Mapping of loanId to loan information.
    mapping(uint256 => Loan) public loans;

    //poolId => loanId => LoanState
    mapping(uint256 => uint256) public poolLoans;

    struct FundDetail {
        uint256 amount;
        uint32 expiration;
        uint32 maxDuration;
        uint16 interestRate;
        uint256 bidId;
    }

    // Mapping of lender address => poolId => ERC20 token => FundDetail
    mapping(address => mapping(uint256 => mapping(address => FundDetail)))
        public lenderPoolFundDetails;

    enum LoanState {
        NONEXISTENT,
        PENDING,
        CANCELLED,
        ACCEPTED,
        PAID,
        LIQUIDATED
    }

    /**
     * Represents a total amount for a payment.
     ~principal Amount that counts towards the principal.
     ~interest  Amount that counts toward interest.
     */
    struct Payment {
        uint256 principal;
        uint256 interest;
    }

    /**
     * Details about the loan.
     ~lendingToken The token address for the loan.
     ~principal The amount of tokens initially lent out.
     ~totalRepaid Payment struct that represents the total principal and interest amount repaid.
     ~timestamp Timestamp, in seconds, of when the bid was submitted by the borrower.
     ~acceptedTimestamp Timestamp, in seconds, of when the bid was accepted by the lender.
     ~lastRepaidTimestamp Timestamp, in seconds, of when the last payment was made
     ~loanDuration The duration of the loan.
     */
    struct LoanDetails {
        ERC20 lendingToken;
        uint256 principal;
        Payment totalRepaid;
        uint32 timestamp;
        uint32 acceptedTimestamp;
        uint32 lastRepaidTimestamp;
        uint32 loanDuration;
    }

    /**
     *  Details about a loan request.
     ~ borrower Account address who is requesting a loan.
     ~ receiver Account address who will receive the loan amount.
     ~ lender Account address who accepted and funded the loan request.
     ~ poolId ID of the pool the bid was submitted to.
     ~ metadataURI ID of off chain metadata to find additional information of the loan request.
     ~ loanDetails Struct of the specific loan details.
     ~ terms Struct of the loan request terms.
     ~ state Represents the current state of the loan.
     */

    /**
     *   Information on the terms of a loan request
     ~paymentCycleAmount Value of tokens expected to be repaid every payment cycle.
     ~paymentCycle Duration, in seconds, of how often a payment must be made.
     ~APR Annual percentage rating to be applied on repayments. (10000 == 100%)
     */
    struct Terms {
        uint256 paymentCycleAmount;
        uint32 paymentCycle;
        uint16 APR;
    }

    struct Loan {
        address borrower;
        address receiver;
        address lender;
        uint256 poolId;
        LoanDetails loanDetails;
        Terms terms;
        LoanState state;
    }

    // Mapping of borrowers to borrower requests.
    mapping(address => EnumerableSet.UintSet) internal borrowerActiveLoans;

    // Amount filled by all lenders.
    // Asset address => Volume amount
    mapping(address => uint256) public totalERC20Amount;

    // Mapping of borrowers to borrower requests.
    mapping(address => uint256[]) public borrowerLoans;
    mapping(uint256 => uint32) public loanDefaultDuration;
    mapping(uint256 => uint32) public loanExpirationTime;

    // Mapping of amount filled by lenders.
    // Asset address => Lender address => Lend amount
    mapping(address => mapping(address => uint256)) public lenderLendAmount;
}
