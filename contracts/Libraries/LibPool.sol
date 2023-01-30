// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "../poolAddress.sol";

library LibPool {
    function deployPoolAddress(
        address _poolOwner,
        address _poolRegistry,
        address _AconomyFeeAddress,
        address _accountStatusAddress,
        uint256 _paymentCycleDuration,
        uint256 _paymentDefaultDuration,
        uint256 _feePercent
    ) external returns (address) {
        poolAddress tokenAddress = new poolAddress(
            _poolOwner,
            _poolRegistry,
            _AconomyFeeAddress,
            _accountStatusAddress,
            _paymentCycleDuration,
            _paymentDefaultDuration,
            _feePercent
        );

        return address(tokenAddress);
    }
}
