// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./piNFT.sol";
import "./CollectionFactory.sol";
import "./CollectionMethods.sol";
import "./utils/LibShare.sol";

contract piMarket is ERC721Holder, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter internal _saleIdCounter;
    Counters.Counter private _swapIdCounter;

    address internal feeAddress;

    struct TokenMeta {
        uint256 saleId;
        address tokenContractAddress;
        uint256 tokenId;
        uint256 price;
        bool directSale;
        bool bidSale;
        bool status;
        uint256 bidStartTime;
        uint256 bidEndTime;
        address currentOwner;
    }

    struct BidOrder {
        uint256 bidId;
        uint256 saleId;
        address sellerAddress;
        address buyerAddress;
        uint256 price;
        bool withdrawn;
    }

    struct Swap {
        address NFTContractAddress;
        address initiator;
        uint256 initiatorNftId;
        address secondUser;
        uint256 secondUserNftId;
        bool status;
    }

    mapping(uint256 => TokenMeta) public _tokenMeta;
    mapping(uint256 => BidOrder[]) public Bids;
    mapping(uint256 => Swap) public _swaps;

    event TokenMetaReturn(TokenMeta data, uint256 id);
    event BidOrderReturn(BidOrder bid);
    event BidExecuted(uint256 price);
    event SwapProposed(
        address indexed from,
        address indexed to,
        uint256 indexed swapId
    );

    constructor(address _feeAddress) {
        require(_feeAddress != address(0), "Fee address cannot be zero");
        feeAddress = _feeAddress;
    }

    modifier onlyOwnerOfToken(address _contractAddress, uint256 _tokenId) {
        require(
            msg.sender == ERC721(_contractAddress).ownerOf(_tokenId),
            "Only token owner can execute"
        );
        _;
    }

    /*
    @params
    * _contractAddress if _fromCollection is true then collection contract Address and if false piNFT contract Address
    */

    function sellNFT(
        address _contractAddress,
        uint256 _tokenId,
        uint256 _price,
        bool _fromCollection
    ) external onlyOwnerOfToken(_contractAddress, _tokenId) nonReentrant {
        _saleIdCounter.increment();

        if (_fromCollection) {
            setTokenMetaForCollection(_contractAddress, _tokenId, _price);
        } else {
            //needs approval on frontend
            ERC721(_contractAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _tokenId
            );

            TokenMeta memory meta = TokenMeta(
                _saleIdCounter.current(),
                _contractAddress,
                _tokenId,
                _price,
                true,
                false,
                true,
                0,
                0,
                msg.sender
            );

            _tokenMeta[_saleIdCounter.current()] = meta;

            emit TokenMetaReturn(meta, _saleIdCounter.current());
        }
    }

    function setTokenMetaForCollection(
        address _contractAddress,
        uint256 _tokenId,
        uint256 _price
    ) internal onlyOwnerOfToken(_contractAddress, _tokenId) nonReentrant {
        //needs approval on frontend
        ERC721(_contractAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        TokenMeta memory meta = TokenMeta(
            _saleIdCounter.current(),
            _contractAddress,
            _tokenId,
            _price,
            true,
            false,
            true,
            0,
            0,
            msg.sender
        );

        _tokenMeta[_saleIdCounter.current()] = meta;

        emit TokenMetaReturn(meta, _saleIdCounter.current());
    }

    function retrieveRoyalty(address _contractAddress, uint256 _tokenId)
        public
        view
        returns (LibShare.Share[] memory)
    {
        return piNFT(_contractAddress).getRoyalties(_tokenId);
    }

    // Get Collection Royalty
    function getCollectionRoyalty(
        address _collectionFactoryAddress,
        uint256 _collectionId
    ) public view returns (LibShare.Share[] memory) {
        return
            CollectionFactory(_collectionFactoryAddress).getCollectionRoyalties(
                _collectionId
            );
    }

    // Get Collection validator Royalty by collection TokenId
    function getCollectionValidatorRoyalty(
        address _collectionAddress,
        uint256 _tokenId
    ) public view returns (LibShare.Share[] memory) {
        return
            CollectionMethods(_collectionAddress).getValidatorRoyalties(
                _tokenId
            );
    }

    // Retrieve validator Royality
    function retrieveValidatorRoyalty(
        address _contractAddress,
        uint256 _tokenId
    ) public view returns (LibShare.Share[] memory) {
        return piNFT(_contractAddress).getValidatorRoyalties(_tokenId);
    }

    function BuyNFT(uint256 _saleId, bool _fromCollection)
        external
        payable
        nonReentrant
    {
        TokenMeta memory meta = _tokenMeta[_saleId];

        LibShare.Share[] memory royalties;
        LibShare.Share[] memory validatorRoyalties;
        if (_fromCollection) {
            royalties = getCollectionRoyalty(
                meta.tokenContractAddress,
                meta.tokenId
            );
            validatorRoyalties = getCollectionValidatorRoyalty(
                meta.tokenContractAddress,
                meta.tokenId
            );
        } else {
            royalties = retrieveRoyalty(
                meta.tokenContractAddress,
                meta.tokenId
            );
            validatorRoyalties = retrieveValidatorRoyalty(
                meta.tokenContractAddress,
                meta.tokenId
            );
        }

        require(meta.status, "token must be on sale");
        require(
            msg.sender != address(0) && msg.sender != meta.currentOwner,
            "invalid address"
        );
        require(!meta.bidSale);
        require(msg.value >= meta.price, "value less than price");

        transfer(_tokenMeta[_saleId], msg.sender);

        uint256 sum = msg.value;
        uint256 val = msg.value;
        uint256 fee = msg.value / 100;

        for (uint256 i = 0; i < royalties.length; i++) {
            uint256 amount = (royalties[i].value * val) / 10000;
            // address payable receiver = royalties[i].account;
            (bool royalSuccess, ) = payable(royalties[i].account).call{
                value: amount
            }("");
            require(royalSuccess, "Royalty Transfer failed");
            sum = sum - amount;
        }

        for (uint256 i = 0; i < validatorRoyalties.length; i++) {
            uint256 amount = (validatorRoyalties[i].value * val) / 10000;
            (bool royalSuccess, ) = payable(validatorRoyalties[i].account).call{
                value: amount
            }("");
            require(royalSuccess, "Royalty Transfer failed");
            sum = sum - amount;
        }

        (bool isSuccess, ) = payable(meta.currentOwner).call{
            value: (sum - fee)
        }("");
        require(isSuccess, "Transfer failed");
        (bool feeSuccess, ) = payable(feeAddress).call{value: fee}("");
        require(feeSuccess, "Fee Transfer failed");
        ERC721(meta.tokenContractAddress).safeTransferFrom(
            address(this),
            msg.sender,
            meta.tokenId
        );
    }

    function cancelSale(uint256 _saleId) external nonReentrant {
        require(
            msg.sender == _tokenMeta[_saleId].currentOwner,
            "Only owner can cancel sale"
        );
        require(_tokenMeta[_saleId].status, "Token not on sale");

        _tokenMeta[_saleId].price = 0;
        _tokenMeta[_saleId].status = false;
        ERC721(_tokenMeta[_saleId].tokenContractAddress).safeTransferFrom(
            address(this),
            _tokenMeta[_saleId].currentOwner,
            _tokenMeta[_saleId].tokenId
        );
    }

    function SellNFT_byBid(
        address _contractAddress,
        uint256 _tokenId,
        uint256 _price,
        uint256 _bidTime
    ) external onlyOwnerOfToken(_contractAddress, _tokenId) nonReentrant {
        require(_contractAddress != address(0));
        _saleIdCounter.increment();

        //needs approval on frontend
        ERC721(_contractAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        TokenMeta memory meta = TokenMeta(
            _saleIdCounter.current(),
            _contractAddress,
            _tokenId,
            _price,
            false,
            true,
            true,
            block.timestamp,
            block.timestamp + _bidTime,
            msg.sender
        );

        _tokenMeta[_saleIdCounter.current()] = meta;

        emit TokenMetaReturn(meta, _saleIdCounter.current());
    }

    function Bid(uint256 _saleId) external payable {
        require(_tokenMeta[_saleId].currentOwner != msg.sender);
        require(_tokenMeta[_saleId].status);
        require(_tokenMeta[_saleId].bidSale);
        require(block.timestamp <= _tokenMeta[_saleId].bidEndTime);
        require(
            _tokenMeta[_saleId].price +
                ((5 * _tokenMeta[_saleId].price) / 100) <=
                msg.value,
            "Bid should be more than 5% of current bid"
        );
        //  require(_timeOfAuction[_saleId] >= block.timestamp,"Auction Over");

        BidOrder memory bid = BidOrder(
            Bids[_saleId].length,
            _saleId,
            _tokenMeta[_saleId].currentOwner,
            msg.sender,
            msg.value,
            false
        );
        Bids[_saleId].push(bid);
        _tokenMeta[_saleId].price = msg.value;

        emit BidOrderReturn(bid);
    }

    function executeBidOrder(
        uint256 _saleId,
        uint256 _bidOrderID,
        bool _fromCollection
    ) external nonReentrant {
        BidOrder memory bids = Bids[_saleId][_bidOrderID];
        require(msg.sender == _tokenMeta[_saleId].currentOwner);
        require(!bids.withdrawn);
        require(_tokenMeta[_saleId].status);

        LibShare.Share[] memory royalties;
        LibShare.Share[] memory validatorRoyalties;
        if (_fromCollection) {
            royalties = getCollectionRoyalty(
                _tokenMeta[_saleId].tokenContractAddress,
                _tokenMeta[_saleId].tokenId
            );
            validatorRoyalties = getCollectionValidatorRoyalty(
                _tokenMeta[_saleId].tokenContractAddress,
                _tokenMeta[_saleId].tokenId
            );
        } else {
            royalties = retrieveRoyalty(
                _tokenMeta[_saleId].tokenContractAddress,
                _tokenMeta[_saleId].tokenId
            );
            validatorRoyalties = retrieveValidatorRoyalty(
                _tokenMeta[_saleId].tokenContractAddress,
                _tokenMeta[_saleId].tokenId
            );
        }

        _tokenMeta[_saleId].status = false;
        _tokenMeta[_saleId].price = bids.price;
        Bids[_saleId][_bidOrderID].withdrawn = true;

        ERC721(_tokenMeta[_saleId].tokenContractAddress).safeTransferFrom(
            address(this),
            bids.buyerAddress,
            _tokenMeta[_saleId].tokenId
        );

        uint256 sum = bids.price;
        uint256 fee = bids.price / 100;

        for (uint256 i = 0; i < royalties.length; i++) {
            uint256 amount = (royalties[i].value * bids.price) / 10000;
            // address payable receiver = royalties[i].account;
            (bool royalSuccess, ) = payable(royalties[i].account).call{
                value: amount
            }("");
            require(royalSuccess, "Royalty transfer failed");
            sum = sum - amount;
        }

        for (uint256 i = 0; i < validatorRoyalties.length; i++) {
            uint256 amount = (validatorRoyalties[i].value * bids.price) / 10000;
            (bool royalSuccess, ) = payable(validatorRoyalties[i].account).call{
                value: amount
            }("");
            require(royalSuccess, "Royalty transfer failed");
            sum = sum - amount;
        }

        (bool isSuccess, ) = payable(msg.sender).call{value: (sum - fee)}("");
        require(isSuccess, "Transfer failed");
        (bool feeSuccess, ) = payable(feeAddress).call{value: fee}("");
        require(feeSuccess, "Fee Transfer failed");

        emit BidExecuted(bids.price);
    }

    function withdrawBidMoney(uint256 _saleId, uint256 _bidId)
        external
        nonReentrant
    {
        require(msg.sender != _tokenMeta[_saleId].currentOwner);
        // BidOrder[] memory bids = Bids[_tokenId];
        BidOrder memory bids = Bids[_saleId][_bidId];
        require(_tokenMeta[_saleId].price != bids.price);
        require(bids.buyerAddress == msg.sender);
        require(!bids.withdrawn);
        (bool success, ) = payable(msg.sender).call{value: bids.price}("");
        if (success) {
            Bids[_saleId][_bidId].withdrawn = true;
        } else {
            revert("No Money left!");
        }
    }

    function transfer(TokenMeta storage token, address _to) internal {
        token.currentOwner = _to;
        token.status = false;
        token.directSale = false;
        token.bidSale = false;
    }

    function swapTokens(
        address contractAddress,
        uint256 token1,
        uint256 token2
    )
        public
        onlyOwnerOfToken(contractAddress, token1)
        nonReentrant
        returns (uint256)
    {
        address token2Owner = ERC721((contractAddress)).ownerOf(token2);
        require(token2Owner != msg.sender, "Cannot Swap Between Your Tokens");
        uint256 swapsId = _swapIdCounter.current();

        ERC721(contractAddress).safeTransferFrom(
            msg.sender,
            address(this),
            token1
        );

        Swap memory swap = Swap(
            contractAddress,
            msg.sender,
            token1,
            token2Owner,
            token2,
            true
        );

        _swaps[swapsId] = swap;

        _swapIdCounter.increment();

        emit SwapProposed(msg.sender, token2Owner, swapsId);

        return swapsId;
    }

    function cancelSwap(uint256 _swapId) public nonReentrant {
        require(
            msg.sender == _swaps[_swapId].initiator,
            "Only owner can cancel sale"
        );
        require(_swaps[_swapId].status, "Token not on swap");
        _swaps[_swapId].status = false;
        ERC721(_swaps[_swapId].NFTContractAddress).safeTransferFrom(
            address(this),
            _swaps[_swapId].initiator,
            _swaps[_swapId].initiatorNftId
        );
    }

    function acceptSwap(uint256 swapId) public nonReentrant {
        Swap memory swap = _swaps[swapId];
        require(swap.status, "token must be on swap");
        require(swap.secondUser == msg.sender, "Only owner can accept swap");
        swap.status = false;
        ERC721(swap.NFTContractAddress).safeTransferFrom(
            address(this),
            msg.sender,
            swap.initiatorNftId
        );
        ERC721(swap.NFTContractAddress).safeTransferFrom(
            msg.sender,
            swap.initiator,
            swap.secondUserNftId
        );
    }

    function rejectSwap(uint256 swapId) public nonReentrant {
        Swap memory swap = _swaps[swapId];
        require(swap.status, "token must be on swap");
        require(swap.secondUser == msg.sender, "Only owner can accept swap");
        _swaps[swapId].status = false;
        ERC721(swap.NFTContractAddress).safeTransferFrom(
            address(this),
            swap.initiator,
            swap.initiatorNftId
        );
    }
}
