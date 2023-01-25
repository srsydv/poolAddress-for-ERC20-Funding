// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Constants.sol";
import "./interfaces/IAttestationServices.sol";
import "./interfaces/IAttestationRegistry.sol";

contract AttestationRegistry is IAttestationRegistry {
    // The global mapping between AS records and their IDs.
    // mapping(bytes32 => ASRecord) private _registry;
    mapping(bytes32 => ASRecord) public _registry;
    event Registered(
        bytes32 indexed uuid,
        uint256 indexed index,
        bytes schema,
        address attester
    );

    uint256 private _asCount;

    function register(bytes calldata schema)
        external
        override
        returns (bytes32)
    {
        uint256 index = ++_asCount;

        ASRecord memory asRecord = ASRecord({
            uuid: EMPTY_UUID,
            index: index,
            schema: schema
        });

        bytes32 uuid = _getUUID(asRecord);
        if (_registry[uuid].uuid != EMPTY_UUID) {
            revert("AlreadyExists");
        }

        asRecord.uuid = uuid;
        _registry[uuid] = asRecord;

        emit Registered(uuid, index, schema, msg.sender);

        return uuid;
    }

    function _getUUID(ASRecord memory asRecord) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(asRecord.schema));
    }

    function getAS(bytes32 uuid)
        external
        view
        override
        returns (ASRecord memory)
    {
        return _registry[uuid];
    }
}

// 1 = 0x905Ea6c3F2a570477C028a201c037c3ba24D0cd6
