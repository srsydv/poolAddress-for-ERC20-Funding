// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./WadRayMath.sol";


library LibCalculations {

using WadRayMath for uint256;
    /**
 * @title WadRayMath library
 * @dev Provides mul and div function for wads (decimal numbers with 18 digits precision) and rays (decimals with 27 digits)
 */



    /**
     * @notice Calculates the payment amount for a cycle duration.
     *  The formula is calculated based on the standard Estimated Monthly Installment (https://en.wikipedia.org/wiki/Equated_monthly_installment)
     *  EMI = [P x R x (1+R)^N]/[(1+R)^N-1]
     * @param principal The starting amount that is owed on the loan.
     * @param loanDuration The length of the loan.
     * @param cycleDuration The length of the loan's payment cycle.
     * @param apr The annual percentage rate of the loan.
     */

     function payment(
        uint256 principal,
        uint32 loanDuration,
        uint32 cycleDuration,
        uint16 apr
    ) internal pure returns (uint256) {
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
}