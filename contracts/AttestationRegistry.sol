// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Constants.sol";
import "./interfaces/IAttestationServices.sol";
import "./interfaces/IAttestationRegistry.sol";

contract AttestationRegistry is IAttestationRegistry {
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

// 1 = 0xbd590158631F4B5f38B5FbC2336DBe94A2787B9c
// 0xf8e81D47203A594245E36C48e151709F0C19fBe8
