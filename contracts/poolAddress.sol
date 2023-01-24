// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./poolRegistry.sol";
import "./poolStorage.sol";

contract poolAddress is poolStorage {
    address poolRegistryAddress;
    address public poolOwner;
    uint256 public paymentCycleDuration;
    uint256 public paymentDefaultDuration;
    // uint256 public bidExpirationTime;
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

    function loanRequest(
        address _lendingToken,
        uint256 _poolId,
        uint256 _principal,
        uint32 _duration,
        uint16 _APR,
        string calldata _metadataURI,
        address _receiver
    ) public returns (uint256 loanId_) {
        (bool isVerified, ) = poolRegistry(poolRegistryAddress)
            .borrowerVarification(_poolId, msg.sender);
        require(isVerified, "Not verified borrower");
        require(
            !poolRegistry(poolRegistryAddress).ClosedPool(_poolId),
            "Market is closed"
        );

        loanId_ = loanId;

        // Create and store our bid into the mapping
        Loan storage loan = loans[loanId];
        loan.borrower = msg.sender;
        loan.receiver = _receiver != address(0) ? _receiver : loan.borrower;
        loan.marketplaceId = _poolId;
        loan.loanDetails.lendingToken = ERC20(_lendingToken);
        loan.loanDetails.principal = _principal;
        loan.loanDetails.loanDuration = _duration;
        loan.loanDetails.timestamp = uint32(block.timestamp);

        loan.terms.paymentCycle = poolRegistry(poolRegistryAddress)
            .getPaymentCycleDuration(_poolId);

        loan.terms.APR = _APR;

        bidDefaultDuration[loanId] = poolRegistry(poolRegistryAddress)
            .getPaymentDefaultDuration(_poolId);

        bidExpirationTime[loanId] = poolRegistry(poolRegistryAddress)
            .getBidExpirationTime(_poolId);
    }
}

library Calculations {}
