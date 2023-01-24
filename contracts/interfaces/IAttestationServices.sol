pragma solidity >=0.8.0 <0.9.0;

// SPDX-License-Identifier: MIT

interface IAttestationServices {
    function register(bytes calldata schema) external returns (bytes32);
}
