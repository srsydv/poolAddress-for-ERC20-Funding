// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./AttestationRegistry.sol";
import "./interfaces/IAttestationServices.sol";
import "./interfaces/IAttestationRegistry.sol";

contract AttestationServices {
    // The AS global registry.
    IAttestationRegistry private immutable _asRegistry;
    address AttestationRegistryAddress;

    constructor(IAttestationRegistry registry) {
        if (address(registry) == address(0x0)) {
            revert("InvalidRegistry");
        }
        _asRegistry = registry;
        // AttestationRegistryAddress=_asRegistry;
    }

    struct Attestation {
        // A unique identifier of the attestation.
        bytes32 uuid;
        // A unique identifier of the AS.
        bytes32 schema;
        // The recipient of the attestation.
        address recipient;
        // The attester/sender of the attestation.
        address attester;
        // The time when the attestation was created (Unix timestamp).
        uint256 time;
        // The time when the attestation expires (Unix timestamp).
        uint256 expirationTime;
        // The time when the attestation was revoked (Unix timestamp).
        uint256 revocationTime;
        // Custom attestation data.
        bytes data;
    }

    // The global counter for the total number of attestations.
    uint256 private _attestationsCount;

    bytes32 private constant EMPTY_UUID = 0;

    // The global mapping between attestations and their UUIDs.
    mapping(bytes32 => Attestation) private _db;

    /**
     *  Triggered when an attestation has been made.
     ~recipient The recipient of the attestation.
     ~attester The attesting account.
     ~uuid The UUID the revoked attestation.
     ~schema The UUID of the AS.
     */
    event Attested(
        address indexed recipient,
        address indexed attester,
        bytes32 uuid,
        bytes32 indexed schema
    );

    function getASRegistry() external view returns (IAttestationRegistry) {
        return _asRegistry;
    }

    function attest(
        address recipient,
        bytes32 schema,
        uint256 expirationTime,
        bytes calldata data
    ) public virtual returns (bytes32) {
        return _attest(recipient, schema, expirationTime, data, msg.sender);
    }

    function _attest(
        address recipient,
        bytes32 schema,
        uint256 expirationTime,
        bytes calldata data,
        address attester
    ) private returns (bytes32) {
        if (expirationTime <= block.timestamp) {
            revert("InvalidExpirationTime");
        }

        IAttestationRegistry.ASRecord memory asRecord = _asRegistry.getAS(
            schema
        );
        if (asRecord.uuid == EMPTY_UUID) {
            revert("InvalidSchema");
        }

        Attestation memory attestation = Attestation({
            uuid: EMPTY_UUID,
            schema: schema,
            recipient: recipient,
            attester: attester,
            time: block.timestamp,
            expirationTime: expirationTime,
            revocationTime: 0,
            data: data
        });

        bytes32 _lastUUID;
        _lastUUID = _getUUID(attestation);
        attestation.uuid = _lastUUID;

        _db[_lastUUID] = attestation;
        _attestationsCount++;

        emit Attested(recipient, attester, _lastUUID, schema);

        return _lastUUID;
    }

    function _getUUID(Attestation memory attestation)
        private
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    attestation.schema,
                    attestation.recipient,
                    attestation.attester,
                    attestation.time,
                    attestation.expirationTime,
                    attestation.data,
                    _attestationsCount
                )
            );
    }

    function isAddressActive(bytes32 uuid) public view returns (bool) {
        return
            isAddressValid(uuid) &&
            _db[uuid].expirationTime >= block.timestamp &&
            _db[uuid].revocationTime == 0;
    }

    function isAddressValid(bytes32 uuid) public view returns (bool) {
        return _db[uuid].uuid != 0;
    }
}
