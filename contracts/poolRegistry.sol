// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
// import "./utils/LibShare.sol";
import "./Libraries/LibPool.sol";
import "./AttestationServices.sol";
// import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
// 0x6515629B35208A10F3ea1142a005DF14e37FDfe5
// poolAddress": "0x9F89ACA814775181f7468a28ae63eEf36aE0fCD7"
// Libraries
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract poolRegistry {
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

    function initialize(AttestationServices _attestationServices) external {
        attestationService = _attestationServices;

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
        string metadataURI;
        uint16 poolFeePercent; // 10000 is 100%
        bool lenderAttestationRequired;
        EnumerableSet.AddressSet verifiedLendersForPool;
        mapping(address => bytes32) lenderAttestationIds;
        uint32 paymentCycleDuration; //unix time
        uint32 paymentDefaultDuration; //unix time
        uint32 bidExpirationTime; //unix time
        bool borrowerAttestationRequired;
        EnumerableSet.AddressSet verifiedBorrowersForPool;
        mapping(address => bytes32) borrowerAttestationIds;
        address feeRecipient;
    }

    mapping(uint256 => poolDetail) internal pools;
    mapping(uint256 => bool) private ClosedPools;

    uint256 public poolCount;
    event poolCreated(
        address indexed owner,
        address poolAddress,
        uint256 poolId
    );
    event SetPoolURI(uint256 poolId, string uri);
    event SetPaymentCycleDuration(uint256 poolId, uint32 duration);
    event SetPaymentDefaultDuration(uint256 poolId, uint32 duration);
    event SetPoolFee(uint256 poolId, uint16 feePct);
    event SetBidExpirationTime(uint256 poolId, uint32 duration);
    event LenderAttestation(uint256 poolId, address lender);
    event BorrowerAttestation(uint256 poolId, address borrower);

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
            address(this),
            _paymentCycleDuration,
            _paymentDefaultDuration,
            _feePercent
        );
        pools[poolId_].poolAddress = poolAddress;
        // Set the pool owner
        pools[poolId_].owner = _initialOwner;

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

        emit poolCreated(_initialOwner, poolAddress, poolId_);
    }

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

    function addLender(
        uint256 _poolId,
        address _lenderAddress,
        uint256 _expirationTime
    ) external {
        _attestAddress(_poolId, _lenderAddress, _expirationTime, true);
    }

    function addBorrower(
        uint256 _poolId,
        address _borrowerAddress,
        uint256 _expirationTime
    ) external {
        _attestAddress(_poolId, _borrowerAddress, _expirationTime, false);
    }

    function _attestAddress(
        uint256 _poolId,
        address _Address,
        uint256 _expirationTime,
        bool _isLender
    )
        internal
        lenderOrBorrowerSchema(
            _isLender ? lenderAttestationSchemaId : borrowerAttestationSchemaId
        )
    {
        require(msg.sender == pools[_poolId].owner, "Not the market owner");

        // Submit attestation for borrower to join a market
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
            // Store the lender attestation ID for the market ID
            pools[_poolId].lenderAttestationIds[_Address] = _uuid;
            // Add lender address to market set
            pools[_poolId].verifiedLendersForPool.add(_Address);

            emit LenderAttestation(_poolId, _Address);
        } else {
            // Store the lender attestation ID for the pool ID
            pools[_poolId].borrowerAttestationIds[_Address] = _uuid;
            // Add lender address to pool set
            pools[_poolId].verifiedBorrowersForPool.add(_Address);

            emit BorrowerAttestation(_poolId, _Address);
        }
    }

    function borrowerVarification(uint256 _poolId, address _borrowerAddress)
        public
        view
        returns (bool isVerified_, bytes32 uuid_)
    {
        return
            _isBorrowerVerified(
                _borrowerAddress,
                pools[_poolId].borrowerAttestationRequired,
                pools[_poolId].borrowerAttestationIds,
                pools[_poolId].verifiedBorrowersForPool
            );
    }

    function _isBorrowerVerified(
        address _borrowerAddress,
        bool _attestationRequired,
        mapping(address => bytes32) storage _stakeholderAttestationIds,
        EnumerableSet.AddressSet storage _verifiedStakeholderForPool
    ) internal view returns (bool isVerified_, bytes32 uuid_) {
        if (_attestationRequired) {
            isVerified_ =
                _verifiedStakeholderForPool.contains(_borrowerAddress) &&
                attestationService.isAddressActive(
                    _stakeholderAttestationIds[_borrowerAddress]
                );
            uuid_ = _stakeholderAttestationIds[_borrowerAddress];
        } else {
            isVerified_ = true;
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

    function getBidExpirationTime(uint256 poolId) public view returns (uint32) {
        return pools[poolId].bidExpirationTime;
    }
}
