// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./interfaces/IAttestationServices.sol";
import "./interfaces/IAttestationRegistry.sol";

contract AttestationRegistry is IAttestationRegistry {
    mapping(bytes32 => ASRecord) public _registry;
    bytes32 private constant EMPTY_UUID = 0;
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
        bytes32 uuid = _getUUID(schema);
        if (_registry[uuid].uuid != EMPTY_UUID) {
            revert("AlreadyExists");
        }

        ASRecord memory asRecord = ASRecord({
            uuid: uuid,
            index: index,
            schema: schema
        });

        _registry[uuid] = asRecord;

        emit Registered(uuid, index, schema, msg.sender);

        return uuid;
    }

    function _getUUID(bytes calldata schema) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(schema));
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
