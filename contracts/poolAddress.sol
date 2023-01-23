// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract poolAddress {
    address public poolOwner;
    uint256 public paymentCycleDuration;
    uint256 public paymentDefaultDuration;
    uint256 public bidExpirationTime;
    uint256 public feePercent;
    uint256 public createdAt;
    uint256 public repayStartDate;
    uint256 public repayInstallment;
    uint256 public totalRepayDeadLine;

    uint256 public constant SECONDS_PER_DAY = 60 * 60 * 24;
    using SafeMath for uint256;

    constructor(
        address _poolOwner,
        uint256 _paymentCycleDuration,
        uint256 _paymentDefaultDuration,
        uint256 _bidExpirationTime,
        uint256 _feePercent
    ) {
        poolOwner = _poolOwner;
        paymentCycleDuration = _paymentCycleDuration;
        paymentDefaultDuration = _paymentDefaultDuration;
        bidExpirationTime = _bidExpirationTime;
        feePercent = _feePercent;
        createdAt = block.timestamp;
    }
}
