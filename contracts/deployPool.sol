// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Libraries/LibPool.sol";

contract deployPool {
    address poolOwner;
        address poolRegistry;
        uint256 paymentCycleDuration;
        uint256 paymentDefaultDuration;
        uint256 feePercent;
    constructor(
        address _poolOwner,
        address _poolRegistry,
        uint256 _paymentCycleDuration,
        uint256 _paymentDefaultDuration,
        uint256 _feePercent
    ) {
        poolOwner = _poolOwner;
        poolRegistry = _poolRegistry;
        paymentCycleDuration = _paymentCycleDuration;
        paymentDefaultDuration = _paymentDefaultDuration;
        feePercent = _feePercent;
    }
}
