// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./WadRayMath.sol";

library LibCalculations {
    // contract LibCalculations {
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
}
