// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 Provides mul and div function for wads (decimal numbers with 18 digits precision) and rays (decimals with 27 digits)
 */
library WadRayMath {
    using SafeMath for uint256;

    uint256 internal constant WAD = 1e18;
    uint256 internal constant halfWAD = WAD / 2;

    function wad() internal pure returns (uint256) {
        return WAD;
    }

    function pctToWad(uint16 a) internal pure returns (uint256) {
        return uint256(a).mul(WAD).div(1e4);
    }

    function halfWad() internal pure returns (uint256) {
        return halfWAD;
    }

    function wadMul(uint256 a, uint256 b) internal pure returns (uint256) {
        return halfWAD.add(a.mul(b)).div(WAD);
    }

    function wadDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 halfB = b / 2;

        return halfB.add(a.mul(WAD)).div(b);
    }

    function wadPow(uint256 x, uint256 n) internal pure returns (uint256) {
        return _pow(x, n, WAD, wadMul);
    }

    function _pow(
        uint256 x,
        uint256 n,
        uint256 p,
        function(uint256, uint256) internal pure returns (uint256) mul
    ) internal pure returns (uint256 z) {
        z = n % 2 != 0 ? x : p;

        for (n /= 2; n != 0; n /= 2) {
            x = mul(x, x);

            if (n % 2 != 0) {
                z = mul(z, x);
            }
        }
    }
}
