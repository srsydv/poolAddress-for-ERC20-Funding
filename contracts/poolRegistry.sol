// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "./AconomyFee.sol";
import "./Libraries/LibPool.sol";
import "./AttestationServices.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract poolRegistry is ReentrancyGuard {
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.AddressSet;

    modifier ownsPool(uint256 _poolId) {
        require(pools[_poolId].owner == msg.sender, "Not the owner");
        _;
    }

    AttestationServices public attestationService;
    bytes32 public lenderAttestationSchemaId;
    bytes32 public borrowerAttestationSchemaId;
    bytes32 private _attestingSchemaId;
    address public AconomyFeeAddress;

    constructor(AttestationServices _attestationServices, address AconomyFee) {
        attestationService = _attestationServices;
        AconomyFeeAddress = AconomyFee;

        lenderAttestationSchemaId = _attestationServices
            .getASRegistry()
            .register("(uint256 poolId, address lenderAddress)");
        borrowerAttestationSchemaId = _attestationServices
            .getASRegistry()
            .register("(uint256 poolId, address borrowerAddress)");
    }

    modifier lenderOrBorrowerSchema(bytes32 schemaId) {
        _attestingSchemaId = schemaId;
        _;
        _attestingSchemaId = bytes32(0);
    }

    function guess(string memory _word, bytes32 ans)
        public
        view
        returns (bool)
    {
        return keccak256(abi.encodePacked(_word)) == ans;
    }

    struct poolDetail {
        address poolAddress;
        address owner;
        string URI;
        uint16 APR;
        uint16 poolFeePercent; // 10000 is 100%
        bool lenderAttestationRequired;
        EnumerableSet.AddressSet verifiedLendersForPool;
        mapping(address => bytes32) lenderAttestationIds;
        uint32 paymentCycleDuration;
        uint32 paymentDefaultDuration;
        uint32 loanExpirationTime;
        bool borrowerAttestationRequired;
        EnumerableSet.AddressSet verifiedBorrowersForPool;
        mapping(address => bytes32) borrowerAttestationIds;
    }

    //poolId => poolDetail
    mapping(uint256 => poolDetail) internal pools;
    //poolId => close or open
    mapping(uint256 => bool) private ClosedPools;

    uint256 public poolCount;
    event poolCreated(
        address indexed owner,
        address poolAddress,
        uint256 poolId
    );
    event SetPaymentCycleDuration(uint256 poolId, uint32 duration);
    event SetPaymentDefaultDuration(uint256 poolId, uint32 duration);
    event SetPoolFee(uint256 poolId, uint16 feePct);
    event SetloanExpirationTime(uint256 poolId, uint32 duration);
    event LenderAttestation(uint256 poolId, address lender);
    event BorrowerAttestation(uint256 poolId, address borrower);
    event SetPoolURI(uint256 marketId, string uri);
    event SetAPR(uint256 marketId, uint16 APR);
    event poolClosed(uint256 poolId);

    //Create Pool
    function createPool(
        uint32 _paymentCycleDuration,
        uint32 _paymentDefaultDuration,
        uint32 _loanExpirationTime,
        uint16 _poolFeePercent,
        uint16 _apr,
        string calldata _uri,
        bool _requireLenderAttestation,
        bool _requireBorrowerAttestation
    ) external returns (uint256 poolId_) {
        // Increment pool ID counter
        poolId_ = ++poolCount;

        //Deploy Pool Address
        address poolAddress = LibPool.deployPoolAddress(
            msg.sender,
            address(this),
            _paymentCycleDuration,
            _paymentDefaultDuration,
            _poolFeePercent
        );
        pools[poolId_].poolAddress = poolAddress;
        // Set the pool owner
        pools[poolId_].owner = msg.sender;

        setApr(poolId_, _apr);
        setPaymentCycleDuration(poolId_, _paymentCycleDuration);
        setPaymentDefaultDuration(poolId_, _paymentDefaultDuration);
        setPoolFeePercent(poolId_, _poolFeePercent);
        setloanExpirationTime(poolId_, _loanExpirationTime);
        setPoolURI(poolId_, _uri);

        // Check if pool requires lender attestation to join
        if (_requireLenderAttestation) {
            pools[poolId_].lenderAttestationRequired = true;
        }
        // Check if pool requires borrower attestation to join
        if (_requireBorrowerAttestation) {
            pools[poolId_].borrowerAttestationRequired = true;
        }

        emit poolCreated(msg.sender, poolAddress, poolId_);
    }

    function setApr(uint256 _poolId, uint16 _apr) public ownsPool(_poolId) {
        if (_apr != pools[_poolId].APR) {
            pools[_poolId].APR = _apr;

            emit SetAPR(_poolId, _apr);
        }
    }

    function setPaymentCycleDuration(uint256 _poolId, uint32 _duration)
        public
        ownsPool(_poolId)
    {
        if (_duration != pools[_poolId].paymentCycleDuration) {
            pools[_poolId].paymentCycleDuration = _duration;

            emit SetPaymentCycleDuration(_poolId, _duration);
        }
    }

    function setPoolURI(uint256 _poolId, string calldata _uri)
        public
        ownsPool(_poolId)
    {
        if (
            keccak256(abi.encodePacked(_uri)) !=
            keccak256(abi.encodePacked(pools[_poolId].URI))
        ) {
            pools[_poolId].URI = _uri;

            emit SetPoolURI(_poolId, _uri);
        }
    }

    function setPaymentDefaultDuration(uint256 _poolId, uint32 _duration)
        public
        ownsPool(_poolId)
    {
        if (_duration != pools[_poolId].paymentDefaultDuration) {
            pools[_poolId].paymentDefaultDuration = _duration;

            emit SetPaymentDefaultDuration(_poolId, _duration);
        }
    }

    function setPoolFeePercent(uint256 _poolId, uint16 _newPercent)
        public
        ownsPool(_poolId)
    {
        require(_newPercent <= 10000, "invalid percent");
        if (_newPercent != pools[_poolId].poolFeePercent) {
            pools[_poolId].poolFeePercent = _newPercent;
            emit SetPoolFee(_poolId, _newPercent);
        }
    }

    function setloanExpirationTime(uint256 _poolId, uint32 _duration)
        public
        ownsPool(_poolId)
    {
        if (_duration != pools[_poolId].loanExpirationTime) {
            pools[_poolId].loanExpirationTime = _duration;

            emit SetloanExpirationTime(_poolId, _duration);
        }
    }

    function addLender(
        uint256 _poolId,
        address _lenderAddress,
        uint256 _expirationTime
    ) external ownsPool(_poolId) {
        _attestAddress(_poolId, _lenderAddress, _expirationTime, true);
    }

    function addBorrower(
        uint256 _poolId,
        address _borrowerAddress,
        uint256 _expirationTime
    ) external ownsPool(_poolId) {
        _attestAddress(_poolId, _borrowerAddress, _expirationTime, false);
    }

    function _attestAddress(
        uint256 _poolId,
        address _Address,
        uint256 _expirationTime,
        bool _isLender
    )
        internal
        nonReentrant
        lenderOrBorrowerSchema(
            _isLender ? lenderAttestationSchemaId : borrowerAttestationSchemaId
        )
    {
        require(msg.sender == pools[_poolId].owner, "Not the pool owner");

        // Submit attestation for borrower to join a pool
        bytes32 uuid = attestationService.attest(
            _Address,
            _attestingSchemaId, // set by the modifier
            _expirationTime,
            0,
            abi.encode(_poolId, _Address)
        );

        _attestAddressVerification(_poolId, _Address, uuid, _isLender);
    }

    function _attestAddressVerification(
        uint256 _poolId,
        address _Address,
        bytes32 _uuid,
        bool _isLender
    ) internal {
        if (_isLender) {
            // Store the lender attestation ID for the pool ID
            pools[_poolId].lenderAttestationIds[_Address] = _uuid;
            // Add lender address to pool set
            //    (bool isSuccess ) =  pools[_poolId].verifiedLendersForPool.add(_Address);
            require(
                pools[_poolId].verifiedLendersForPool.add(_Address),
                "add lender to poolfailed"
            );

            emit LenderAttestation(_poolId, _Address);
        } else {
            // Store the lender attestation ID for the pool ID
            pools[_poolId].borrowerAttestationIds[_Address] = _uuid;
            // Add lender address to pool set
            require(
                pools[_poolId].verifiedBorrowersForPool.add(_Address),
                "add borrower failed, verifiedBorrowersForPool.add failed"
            );

            emit BorrowerAttestation(_poolId, _Address);
        }
    }

    function getPoolFee(uint256 _poolId) public view returns (uint16 fee) {
        return pools[_poolId].poolFeePercent;
    }

    function borrowerVarification(uint256 _poolId, address _borrowerAddress)
        public
        view
        returns (bool isVerified_, bytes32 uuid_)
    {
        return
            _isAddressVerified(
                _borrowerAddress,
                pools[_poolId].borrowerAttestationRequired,
                pools[_poolId].borrowerAttestationIds,
                pools[_poolId].verifiedBorrowersForPool
            );
    }

    function lenderVarification(uint256 _poolId, address _lenderAddress)
        public
        view
        returns (bool isVerified_, bytes32 uuid_)
    {
        return
            _isAddressVerified(
                _lenderAddress,
                pools[_poolId].lenderAttestationRequired,
                pools[_poolId].lenderAttestationIds,
                pools[_poolId].verifiedLendersForPool
            );
    }

    function _isAddressVerified(
        address _wltAddress,
        bool _attestationRequired,
        mapping(address => bytes32) storage _stakeholderAttestationIds,
        EnumerableSet.AddressSet storage _verifiedStakeholderForPool
    ) internal view returns (bool isVerified_, bytes32 uuid_) {
        if (_attestationRequired) {
            isVerified_ =
                _verifiedStakeholderForPool.contains(_wltAddress) &&
                attestationService.isAddressActive(
                    _stakeholderAttestationIds[_wltAddress]
                );
            uuid_ = _stakeholderAttestationIds[_wltAddress];
        } else {
            isVerified_ = true;
        }
    }

    function closePool(uint256 _poolId) public ownsPool(_poolId) {
        if (!ClosedPools[_poolId]) {
            ClosedPools[_poolId] = true;

            emit poolClosed(_poolId);
        }
    }

    function ClosedPool(uint256 _poolId) public view returns (bool) {
        return ClosedPools[_poolId];
    }

    function getPaymentCycleDuration(uint256 _poolId)
        public
        view
        returns (uint32)
    {
        return pools[_poolId].paymentCycleDuration;
    }

    function getPaymentDefaultDuration(uint256 _poolId)
        public
        view
        returns (uint32)
    {
        return pools[_poolId].paymentDefaultDuration;
    }

    function getloanExpirationTime(uint256 poolId)
        public
        view
        returns (uint32)
    {
        return pools[poolId].loanExpirationTime;
    }

    function getPoolAddress(uint256 _poolId) public view returns (address) {
        return pools[_poolId].poolAddress;
    }

    function getPoolOwner(uint256 _poolId) public view returns (address) {
        return pools[_poolId].owner;
    }

    function getPoolApr(uint256 _poolId) public view returns (uint16) {
        return pools[_poolId].APR;
    }

    function getAconomyFee() public view returns (uint16) {
        return AconomyFee(AconomyFeeAddress).protocolFee();
    }

    function getAconomyOwner() public view returns (address) {
        return AconomyFee(AconomyFeeAddress).getAconomyOwnerAddress();
    }
}
