// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../FundingPool.sol";

library LibPool {
    function deployPoolAddress(
        address _poolOwner,
        address _poolRegistry,
        uint256 _paymentCycleDuration,
        uint256 _paymentDefaultDuration,
        uint256 _feePercent
    ) external returns (address) {
        FundingPool tokenAddress = new FundingPool(
            _poolOwner,
            _poolRegistry,
            _paymentCycleDuration,
            _paymentDefaultDuration,
            _feePercent
        );

        return address(tokenAddress);
    }
}
