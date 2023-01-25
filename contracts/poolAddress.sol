// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./poolRegistry.sol";
import "./poolStorage.sol";
import "./Libraries/LibCalculations.sol";

contract poolAddress is poolStorage {
    address poolRegistryAddress;
    address public poolOwner;
    uint256 public paymentCycleDuration;
    uint256 public paymentDefaultDuration;
    uint256 public feePercent;
    uint256 public createdAt;

    using SafeMath for uint256;

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
        createdAt = block.timestamp;
    }

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
            .getBidExpirationTime(_poolId);

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
}
