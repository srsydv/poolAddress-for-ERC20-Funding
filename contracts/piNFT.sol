// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./utils/LibShare.sol";

contract piNFT is ERC721URIStorage{

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    // tokenId => (token contract => balance)
    mapping(uint256 => mapping(address => uint256)) erc20Balances;

    // tokenId => token contract
    mapping(uint256 => address[]) erc20Contracts;

    // tokenId => royalties
    mapping(uint256 => LibShare.Share[]) public royaltiesByTokenId;

    // tokenId => (token contract => token contract index)
    mapping(uint256 => mapping(address => uint256)) erc20ContractIndex;

    event ReceivedERC20(address indexed _from, uint256 indexed _tokenId, address indexed _erc20Contract, uint256 _value);
    event TransferERC20(uint256 indexed _tokenId, address indexed _to, address indexed _erc20Contract, uint256 _value);
    event RoyaltiesSetForTokenId(uint256 indexed tokenId, LibShare.Share[] indexed royalties);

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    modifier onlyOwnerOfToken(uint256 _tokenId) {
        require(msg.sender == ERC721.ownerOf(_tokenId), 'Only token owner can execute');
        _;
    }
    
    // mints an ERC721 token to _to with _uri as token uri
    function mintNFT(address _to, string memory _uri, LibShare.Share[] memory royalties) public returns (uint256) {
        uint256 tokenId_ = _tokenIdCounter.current();
        _setRoyaltiesByTokenId(tokenId_, royalties);
        _safeMint(_to, tokenId_);
        _setTokenURI(tokenId_, _uri);
        _tokenIdCounter.increment();
        return tokenId_;
    }

    function _setRoyaltiesByTokenId(
        uint256 _tokenId,
        LibShare.Share[] memory royalties
    ) internal {
        require(royalties.length <= 10, 'Atmost 10 royalties can be added');
        delete royaltiesByTokenId[_tokenId];
        uint256 sumRoyalties = 0;
        for (uint256 i = 0; i < royalties.length; i++) {
            require(
                royalties[i].account != address(0x0),
                "Royalty recipient should be present"
            );
            require(royalties[i].value != 0, "Royalty value should be > 0");
            royaltiesByTokenId[_tokenId].push(royalties[i]);
            sumRoyalties += royalties[i].value;
        }
        require(sumRoyalties < 10000, "Sum of Royalties > 100%");

        emit RoyaltiesSetForTokenId(_tokenId, royalties);
    }

    function getRoyalties(uint256 _tokenId)
        external
        view
        returns (LibShare.Share[] memory)
    {
        return royaltiesByTokenId[_tokenId];
    }

    // this function requires approval of tokens by _erc20Contract
    // adds ERC20 tokens to the token with _tokenId(basically trasnfer ERC20 to this contract)
    function addERC20(address _from, uint256 _tokenId, address _erc20Contract, uint256 _value) public {
        require(_from == msg.sender, "not allowed to add ERC20");
        erc20Received(_from, _tokenId, _erc20Contract, _value);
        require(IERC20(_erc20Contract).transferFrom(_from, address(this), _value), "ERC20 transfer failed.");
    }

    // update the mappings for a token on recieving ERC20 tokens
    function erc20Received(address _from, uint256 _tokenId, address _erc20Contract, uint256 _value) private {
        require(ERC721.ownerOf(_tokenId) != address(0), "_tokenId does not exist.");
        if (_value == 0) {
            return;
        }
        uint256 erc20Balance = erc20Balances[_tokenId][_erc20Contract];
        if (erc20Balance == 0) {
            erc20ContractIndex[_tokenId][_erc20Contract] = erc20Contracts[_tokenId].length;
            erc20Contracts[_tokenId].push(_erc20Contract);
        }
        erc20Balances[_tokenId][_erc20Contract] += _value;
        emit ReceivedERC20(_from, _tokenId, _erc20Contract, _value);
    }

    function redeemPiNFT(uint256 _tokenId, address _nftReciever, address _validatorAddress, address _erc20Contract, uint256 _value) external onlyOwnerOfToken(_tokenId){
        require(_nftReciever != address(0), 'cannot transfer to zero address');
        _transferERC20(_tokenId, _validatorAddress, _erc20Contract, _value);
        ERC721.safeTransferFrom(msg.sender, _nftReciever, _tokenId);
    }

    function burnPiNFT(uint256 _tokenId, address _nftReciever, address _erc20Reciever, address _erc20Contract, uint256 _value) external onlyOwnerOfToken(_tokenId){
        require(_nftReciever != address(0), 'cannot transfer to zero address');
        _transferERC20(_tokenId, _erc20Reciever, _erc20Contract, _value);
        ERC721.safeTransferFrom(msg.sender, _nftReciever, _tokenId);
    }

    // transfers the ERC 20 tokens from _tokenId(this contract) to _to address
    function _transferERC20(uint256 _tokenId, address _to, address _erc20Contract, uint256 _value) private {
        require(_to != address(0), 'cannot send to zero address');
        address rootOwner = ERC721.ownerOf(_tokenId);
        require(rootOwner == msg.sender, 'only owner can transfer');
        removeERC20(_tokenId, _erc20Contract, _value);
        require(IERC20(_erc20Contract).transfer(_to, _value), "ERC20 transfer failed.");
        emit TransferERC20(_tokenId, _to, _erc20Contract, _value);
    }

    // update the mappings for a token when ERC20 tokens gets removed
    function removeERC20(uint256 _tokenId, address _erc20Contract, uint256 _value) private {
        if (_value == 0) {
            return;
        }
        uint256 erc20Balance = erc20Balances[_tokenId][_erc20Contract];
        require(erc20Balance >= _value, "Not enough token available to transfer.");
        uint256 newERC20Balance = erc20Balance - _value;
        erc20Balances[_tokenId][_erc20Contract] = newERC20Balance;
        if (newERC20Balance == 0) {
            uint256 lastContractIndex = erc20Contracts[_tokenId].length - 1;
            address lastContract = erc20Contracts[_tokenId][lastContractIndex];
            if (_erc20Contract != lastContract) {
                uint256 contractIndex = erc20ContractIndex[_tokenId][_erc20Contract];
                erc20Contracts[_tokenId][contractIndex] = lastContract;
                erc20ContractIndex[_tokenId][lastContract] = contractIndex;
            }
            delete erc20ContractIndex[_tokenId][_erc20Contract];
            erc20Contracts[_tokenId].pop();

        }
    }

    // view ERC 20 token balance of a token
    function viewBalance(uint256 _tokenId, address _erc20Address) public view returns (uint256) {
        return erc20Balances[_tokenId][_erc20Address];
    }

    //Create Pool

    modifier ownsPool(uint256 _poolId) {
        require(markets[_poolId].owner == _msgSender(), "Not the owner");
        _;
    }

    struct poolDetail {
        address poolAddress;
        address owner;
        string metadataURI;
        uint16 poolFeePercent; // 10000 is 100%
        bool lenderAttestationRequired;
        mapping(address => bytes32) lenderAttestationIds;
        uint32 paymentCycleDuration; //unix time
        uint32 paymentDefaultDuration; //unix time
        uint32 bidExpirationTime; //unix time
        bool borrowerAttestationRequired;
        mapping(address => bytes32) borrowerAttestationIds;
        address feeRecipient;
        // V2Calculations.PaymentType paymentType;
    }

    mapping(uint256 => poolDetail) public markets;
    uint256 public poolCount;
    event MarketCreated(address indexed owner, uint256 poolId);
    event SetMarketURI(uint256 poolId, string uri);
    event SetPaymentCycleDuration(uint256 poolId, uint32 duration);
    event SetPaymentDefaultDuration(uint256 poolId, uint32 duration);
    event SetMarketFee(uint256 poolId, uint16 feePct);
    event SetBidExpirationTime(uint256 poolId, uint32 duration);

        // V2Calculations.PaymentType _paymentType,
    function createMarket(
        address _initialOwner,
        uint32 _paymentCycleDuration,
        uint32 _paymentDefaultDuration,
        uint32 _bidExpirationTime,
        uint16 _feePercent,
        bool _requireLenderAttestation,
        bool _requireBorrowerAttestation,
        string calldata _uri
    ) external returns (uint256 poolId_) {
        poolId_ = _createMarket(
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


// Creates a new market.
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
        // Increment market ID counter
        poolId_ = ++poolCount;

        // Set the market owner
        markets[poolId_].owner = _initialOwner;

        setMarketURI(poolId_, _uri);
        setPaymentCycleDuration(poolId_, _paymentCycleDuration);
        setPaymentDefaultDuration(poolId_, _paymentDefaultDuration);
        setMarketFeePercent(poolId_, _feePercent);
        setBidExpirationTime(poolId_, _bidExpirationTime);
        // setMarketPaymentType(marketId_, _paymentType);

        // Check if market requires lender attestation to join
        if (_requireLenderAttestation) {
            markets[poolId_].lenderAttestationRequired = true;
        }
        // Check if market requires borrower attestation to join
        if (_requireBorrowerAttestation) {
            markets[poolId_].borrowerAttestationRequired = true;
        }

        emit MarketCreated(_initialOwner, poolId_);
    }

    function setMarketURI(uint256 _poolId, string calldata _uri)
        public
        ownsPool(_poolId)
    {
        //We do string comparison by checking the hashes of the strings against one another
        if (
            keccak256(abi.encodePacked(_uri)) !=
            keccak256(abi.encodePacked(markets[_poolId].metadataURI))
        ) {
            markets[_poolId].metadataURI = _uri;

            emit SetMarketURI(_poolId, _uri);
        }
    }

    function setPaymentCycleDuration(uint256 _poolId, uint32 _duration)
        public
        ownsPool(_poolId)
    {
        if (_duration != markets[_poolId].paymentCycleDuration) {
            markets[_poolId].paymentCycleDuration = _duration;

            emit SetPaymentCycleDuration(_poolId, _duration);
        }
    }

    function setPaymentDefaultDuration(uint256 _poolId, uint32 _duration)
        public
        ownsPool(_poolId)
    {
        if (_duration != markets[_poolId].paymentDefaultDuration) {
            markets[_poolId].paymentDefaultDuration = _duration;

            emit SetPaymentDefaultDuration(_poolId, _duration);
        }
    }

    function setMarketFeePercent(uint256 _poolId, uint16 _newPercent)
        public
        ownsPool(_poolId)
    {
        require(_newPercent >= 0 && _newPercent <= 10000, "invalid percent");
        if (_newPercent != markets[_poolId].poolFeePercent) {
            markets[_poolId].poolFeePercent = _newPercent;
            emit SetMarketFee(_poolId, _newPercent);
        }
    }

    function setBidExpirationTime(uint256 _poolId, uint32 _duration)
        public
        ownsPool(_poolId)
    {
        if (_duration != markets[_poolId].bidExpirationTime) {
            markets[_poolId].bidExpirationTime = _duration;

            emit SetBidExpirationTime(_poolId, _duration);
        }
    }



}