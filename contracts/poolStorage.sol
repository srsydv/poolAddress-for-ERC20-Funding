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

    enum LoanState {
        PENDING,
        CANCELLED,
        ACCEPTED,
        PAID
    }

    struct Payment {
        uint256 principal;
        uint256 interest;
    }

    struct LoanDetails {
        ERC20 lendingToken;
        uint256 principal;
        Payment totalRepaid;
        uint32 timestamp;
        uint32 acceptedTimestamp;
        uint32 lastRepaidTimestamp;
        uint32 loanDuration;
    }

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
