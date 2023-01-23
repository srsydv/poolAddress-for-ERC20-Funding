// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./utils/LibShare.sol";
import "./Libraries/LibPool.sol";
import "./AttestationServices.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

// Libraries
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// 0xc920f7Cf331eA5B935f9F585f2f0f2301e441F8A
contract poolRegistry {
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.AddressSet;

    modifier ownsPool(uint256 _poolId) {
        require(pools[_poolId].owner == msg.sender, "Not the owner");
        _;
    }

    bytes32 public lenderAttestationSchemaId;
    bytes32 public borrowerAttestationSchemaId;
    bytes32 private _attestingSchemaId;

    function initialize(AttestationServices _attestationServices) external {
        // attestationServices = _attestationServices;

        lenderAttestationSchemaId = _attestationServices
            .getASRegistry()
            .register("(uint256 poolId, address lenderAddress)");
        borrowerAttestationSchemaId = _attestationServices
            .getASRegistry()
            .register("(uint256 poolId, address borrowerAddress)");
    }

    modifier withAttestingSchema(bytes32 schemaId) {
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
        string metadataURI;
        uint16 poolFeePercent; // 10000 is 100%
        bool lenderAttestationRequired;
        EnumerableSet.AddressSet verifiedLendersForMarket;
        mapping(address => bytes32) lenderAttestationIds;
        uint32 paymentCycleDuration; //unix time
        uint32 paymentDefaultDuration; //unix time
        uint32 bidExpirationTime; //unix time
        bool borrowerAttestationRequired;
        mapping(address => bytes32) borrowerAttestationIds;
        address feeRecipient;
    }

    mapping(uint256 => poolDetail) internal pools;
    uint256 public poolCount;
    event poolCreated(address indexed owner, uint256 poolId);
    event newpoolAddress(address poolAddress);
    event SetPoolURI(uint256 poolId, string uri);
    event SetPaymentCycleDuration(uint256 poolId, uint32 duration);
    event SetPaymentDefaultDuration(uint256 poolId, uint32 duration);
    event SetPoolFee(uint256 poolId, uint16 feePct);
    event SetBidExpirationTime(uint256 poolId, uint32 duration);

    //Create Pool
    function createMarket(
        address _initialOwner,
        uint32 _paymentCycleDuration,
        uint32 _paymentDefaultDuration,
        uint32 _bidExpirationTime,
        uint16 _feePercent,
        bool _requireLenderAttestation,
        bool _requireBorrowerAttestation,
        string calldata _uri
    ) external {
        _createMarket(
            _initialOwner,
            _paymentCycleDuration,
            _paymentDefaultDuration,
            _bidExpirationTime,
            _feePercent,
            _requireLenderAttestation,
            _requireBorrowerAttestation,
            _uri
        );
    }

    // Creates a new Pool.
    function _createMarket(
        address _initialOwner,
        uint32 _paymentCycleDuration,
        uint32 _paymentDefaultDuration,
        uint32 _bidExpirationTime,
        uint16 _feePercent,
        bool _requireLenderAttestation,
        bool _requireBorrowerAttestation,
        string calldata _uri
    ) internal returns (uint256 poolId_) {
        require(_initialOwner != address(0), "Invalid owner address");
        // Increment pool ID counter
        poolId_ = ++poolCount;

        //Deploy Pool Address
        address poolAddress = LibPool.deployPoolAddress(
            msg.sender,
            _paymentCycleDuration,
            _paymentDefaultDuration,
            _bidExpirationTime,
            _feePercent
        );
        pools[poolId_].poolAddress = poolAddress;
        emit newpoolAddress(poolAddress);
        // Set the pool owner
        pools[poolId_].owner = _initialOwner;

        // setPoolAddress(poolId_,poolAddress);
        setPoolURI(poolId_, _uri);
        setPaymentCycleDuration(poolId_, _paymentCycleDuration);
        setPaymentDefaultDuration(poolId_, _paymentDefaultDuration);
        setPoolFeePercent(poolId_, _feePercent);
        setBidExpirationTime(poolId_, _bidExpirationTime);

        // Check if pool requires lender attestation to join
        if (_requireLenderAttestation) {
            pools[poolId_].lenderAttestationRequired = true;
        }
        // Check if pool requires borrower attestation to join
        if (_requireBorrowerAttestation) {
            pools[poolId_].borrowerAttestationRequired = true;
        }

        emit poolCreated(_initialOwner, poolId_);
    }

    // function setPoolAddress(uint256 _poolId, address _poolAddress)
    // public
    // ownsPool(_poolId)
    // {
    //     pools[_poolId].poolAddress = _poolAddress;
    //     emit poolAddress(_poolAddress,msg.sender,_poolId);
    // }

    function setPoolURI(uint256 _poolId, string calldata _uri)
        public
        ownsPool(_poolId)
    {
        //We do string comparison by checking the hashes of the strings against one another
        if (
            keccak256(abi.encodePacked(_uri)) !=
            keccak256(abi.encodePacked(pools[_poolId].metadataURI))
        ) {
            pools[_poolId].metadataURI = _uri;

            emit SetPoolURI(_poolId, _uri);
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
        require(_newPercent >= 0 && _newPercent <= 10000, "invalid percent");
        if (_newPercent != pools[_poolId].poolFeePercent) {
            pools[_poolId].poolFeePercent = _newPercent;
            emit SetPoolFee(_poolId, _newPercent);
        }
    }

    function setBidExpirationTime(uint256 _poolId, uint32 _duration)
        public
        ownsPool(_poolId)
    {
        if (_duration != pools[_poolId].bidExpirationTime) {
            pools[_poolId].bidExpirationTime = _duration;

            emit SetBidExpirationTime(_poolId, _duration);
        }
    }

    function attestLender(
        uint256 _poolId,
        address _lenderAddress,
        uint256 _expirationTime
    ) external {
        _attestStakeholder(_poolId, _lenderAddress, _expirationTime, true);
    }

    function _attestStakeholder(
        uint256 _poolId,
        address _stakeholderAddress,
        uint256 _expirationTime,
        bool _isLender
    )
        internal
        withAttestingSchema(
            _isLender ? lenderAttestationSchemaId : borrowerAttestationSchemaId
        )
    {
        require(msg.sender == pools[_poolId].owner, "Not the market owner");

        // Submit attestation for borrower to join a market
        bytes32 uuid = AttestationServices.attest(
            _stakeholderAddress,
            _attestingSchemaId, // set by the modifier
            _expirationTime,
            0,
            abi.encode(_poolId, _stakeholderAddress)
        );

        // _attestStakeholderVerification(
        //     _poolId,
        //     _stakeholderAddress,
        //     _isLender
        // );
    }

    // function _attestStakeholderVerification(
    //     uint256 _poolId,
    //     address _stakeholderAddress,
    //     bool _isLender
    // ) internal {
    //     if (_isLender) {
    //         // Store the lender attestation ID for the market ID
    //         pools[_poolId].lenderAttestationIds[
    //             _stakeholderAddress
    //         ] = _uuid;
    //         // Add lender address to market set
    //         markets[_marketId].verifiedLendersForMarket.add(
    //             _stakeholderAddress
    //         );

    //         emit LenderAttestation(_marketId, _stakeholderAddress);
    //     } else {
    //         // Store the lender attestation ID for the market ID
    //         markets[_marketId].borrowerAttestationIds[
    //             _stakeholderAddress
    //         ] = _uuid;
    //         // Add lender address to market set
    //         markets[_marketId].verifiedBorrowersForMarket.add(
    //             _stakeholderAddress
    //         );

    //         emit BorrowerAttestation(_marketId, _stakeholderAddress);
    //     }
    // }
}
