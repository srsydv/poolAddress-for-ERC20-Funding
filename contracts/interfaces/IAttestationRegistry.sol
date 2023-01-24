pragma solidity >=0.8.0 <0.9.0;

// SPDX-License-Identifier: MIT

interface IAttestationRegistry {
    struct ASRecord {
        // A unique identifier of the Attestation Registry.
        bytes32 uuid;
        // Auto-incrementing index for reference, assigned by the registry itself.
        uint256 index;
        // Custom specification of the Attestation Registry (e.g., an ABI).
        bytes schema;
    }

    function register(bytes calldata schema) external returns (bytes32);

    function getAS(bytes32 uuid) external view returns (ASRecord memory);
}
