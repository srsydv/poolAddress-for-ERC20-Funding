// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./WadRayMath.sol";
import "../poolAddress.sol";

library LibCalculations {
    using WadRayMath for uint256;

    uint256 internal constant WAD = 1e18;

    function percentFactor(uint256 decimals) internal pure returns (uint256) {
        return 100 * (10**decimals);
    }

    /**
     * Returns a percentage value of a number.
     self The number to get a percentage of.
     percentage The percentage value to calculate with 2 decimal places (10000 = 100%).
     */
    function percent(uint256 self, uint16 percentage)
        public
        pure
        returns (uint256)
    {
        return percent(self, percentage, 2);
    }

    /**
     * Returns a percentage value of a number.
     self The number to get a percentage of.
     percentage The percentage value to calculate with.
     decimals The number of decimals the percentage value is in.
     */
    function percent(
        uint256 self,
        uint256 percentage,
        uint256 decimals
    ) internal pure returns (uint256) {
        return (self * percentage) / percentFactor(decimals);
    }

    function payment(
        uint256 principal,
        uint32 loanDuration,
        uint32 cycleDuration,
        uint16 apr
    ) public pure returns (uint256) {
        uint256 n = loanDuration / cycleDuration;
        if (apr == 0) return (principal / n);

        uint256 one = WadRayMath.wad();
        uint256 r = WadRayMath.pctToWad(apr).wadMul(cycleDuration).wadDiv(
            365 days
        );
        uint256 exp = (one + r).wadPow(n);
        uint256 numerator = principal.wadMul(r).wadMul(exp);
        uint256 denominator = exp - one;

        return numerator.wadDiv(denominator);
    }

    function lastRepaidTimestamp(poolAddress.Loan storage _loan)
        internal
        view
        returns (uint32)
    {
        return
            _loan.loanDetails.lastRepaidTimestamp == 0
                ? _loan.loanDetails.acceptedTimestamp
                : _loan.loanDetails.lastRepaidTimestamp;
    }

    function calculateInstallmentAmount(
        uint256 amount,
        uint256 leftAmount,
        uint16 interestRate,
        uint256 paymentCycleAmount,
        uint256 paymentCycle,
        uint32 lastRepaidTimestamp,
        uint256 timestamp,
        uint256 acceptBidTimestamp,
        uint256 maxDuration
    )
        internal
        view
        returns (
            uint256 owedPrincipal_,
            uint256 duePrincipal_,
            uint256 interest_
        )
    {
        return
            calculateOwedAmount(
                amount,
                leftAmount,
                interestRate,
                paymentCycleAmount,
                paymentCycle,
                lastRepaidTimestamp,
                timestamp,
                acceptBidTimestamp,
                maxDuration
            );
    }

    function owedAmount(poolAddress.Loan storage _loan, uint256 _timestamp)
        internal
        view
        returns (
            uint256 owedPrincipal_,
            uint256 duePrincipal_,
            uint256 interest_
        )
    {
        // Total Amount left to pay
        return
            calculateOwedAmount(
                _loan.loanDetails.principal,
                _loan.loanDetails.totalRepaid.principal,
                _loan.terms.APR,
                _loan.terms.paymentCycleAmount,
                _loan.terms.paymentCycle,
                lastRepaidTimestamp(_loan),
                _timestamp,
                _loan.loanDetails.acceptedTimestamp,
                _loan.loanDetails.loanDuration
            );
    }

    function calculateOwedAmount(
        uint256 principal,
        uint256 totalRepaidPrincipal,
        uint16 _interestRate,
        uint256 _paymentCycleAmount,
        uint256 _paymentCycle,
        uint256 _lastRepaidTimestamp,
        uint256 _timestamp,
        uint256 _startTimestamp,
        uint256 _loanDuration
    )
        internal
        pure
        returns (
            uint256 owedPrincipal_,
            uint256 duePrincipal_,
            uint256 interest_
        )
    {
        owedPrincipal_ = principal - totalRepaidPrincipal;

        uint256 interestInAYear = percent(owedPrincipal_, _interestRate);
        uint256 owedTime = _timestamp - uint256(_lastRepaidTimestamp);
        interest_ = (interestInAYear * owedTime) / 365 days;

        // Cast to int265 to avoid underflow errors (negative means loan duration has passed)
        int256 durationLeftOnLoan = int256(_loanDuration) -
            (int256(_timestamp) - int256(_startTimestamp));
        bool isLastPaymentCycle = durationLeftOnLoan < int256(_paymentCycle) || // Check if current payment cycle is within or beyond the last one
            owedPrincipal_ + interest_ <= _paymentCycleAmount; // Check if what is left to pay is less than the payment cycle amount

        // Max payable amount in a cycle
        // NOTE: the last cycle could have less than the calculated payment amount
        uint256 maxCycleOwed = isLastPaymentCycle
            ? owedPrincipal_ + interest_
            : _paymentCycleAmount;

        // Calculate accrued amount due since last repayment
        uint256 Amount = (maxCycleOwed * owedTime) / _paymentCycle;
        duePrincipal_ = Math.min(Amount - interest_, owedPrincipal_);
    }
}
