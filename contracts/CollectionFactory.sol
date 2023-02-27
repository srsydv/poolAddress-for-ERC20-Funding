// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./utils/LibShare.sol";
import "./Libraries/LibCollection.sol";

contract CollectionFactory {
    using Counters for Counters.Counter;

    struct CollectionMeta {
        string name;
        string symbol;
        string URI;
        address contractAddress;
        address owner;
        string description;
    }

    // collectionId => collwctionMeta
    mapping(uint256 => CollectionMeta) public collections;

    // collectionId => royalties
    mapping(uint256 => LibShare.Share[]) public royaltiesForCollection;

    uint256 public collectionId;

    event SetCollectionURI(uint256 collectionId, string uri);

    event SetName(uint256 collectionId, string name);

    event SetDescription(uint256 collectionId, string Description);

    event SetSymbol(uint256 collectionId, string Symbol);

    event CollectionCreated(uint256 collectionId, address CollectionAddress);

    event Royalties(
        uint256 indexed tokenId,
        LibShare.Share[] indexed royalties
    );

    // constructor(){}

    modifier collectionOwner(uint256 _collectionId) {
        require(
            collections[_collectionId].owner == msg.sender,
            "Not the owner"
        );
        _;
    }

    // Create Collection
    function createCollection(
        string memory _name,
        string memory _symbol,
        string calldata _uri,
        string memory _description,
        LibShare.Share[] memory royalties
    ) public returns (uint256 collectionId_) {
        collectionId_ = ++collectionId;

        //Deploy collection Address
        address collectionAddress = LibCollection.deployCollectionAddress(
            msg.sender,
            address(this),
            _name,
            _symbol
        );

        CollectionMeta memory details = CollectionMeta(
            _name,
            _symbol,
            _uri,
            collectionAddress,
            msg.sender,
            _description
        );

        collections[collectionId_] = details;
        setRoyaltiesForCollection(collectionId_, royalties);

        emit CollectionCreated(collectionId_, collectionAddress);
    }

    //Set Royalties for Collection
    function setRoyaltiesForCollection(
        uint256 _collectionId,
        LibShare.Share[] memory royalties
    ) internal {
        require(royalties.length <= 10, "Atmost 10 royalties can be added");
        delete royaltiesForCollection[_collectionId];
        uint256 sumRoyalties = 0;
        for (uint256 i = 0; i < royalties.length; i++) {
            require(
                royalties[i].account != address(0x0),
                "Royalty recipient should be present"
            );
            require(royalties[i].value != 0, "Royalty value should be > 0");
            royaltiesForCollection[_collectionId].push(royalties[i]);
            sumRoyalties += royalties[i].value;
        }
        require(sumRoyalties < 10000, "Sum of Royalties > 100%");

        emit Royalties(_collectionId, royalties);
    }

    function setCollectionURI(uint256 _collectionId, string calldata _uri)
        public
        collectionOwner(_collectionId)
    {
        if (
            keccak256(abi.encodePacked(_uri)) !=
            keccak256(abi.encodePacked(collections[_collectionId].URI))
        ) {
            collections[_collectionId].URI = _uri;

            emit SetCollectionURI(_collectionId, _uri);
        }
    }

    function setCollectionName(uint256 _collectionId, string memory _name)
        public
        collectionOwner(_collectionId)
    {
        if (
            keccak256(abi.encodePacked(_name)) !=
            keccak256(abi.encodePacked(collections[_collectionId].name))
        ) {
            collections[_collectionId].name = _name;

            emit SetName(_collectionId, _name);
        }
    }

    function setCollectionSymbol(uint256 _collectionId, string memory _symbol)
        public
        collectionOwner(_collectionId)
    {
        if (
            keccak256(abi.encodePacked(_symbol)) !=
            keccak256(abi.encodePacked(collections[_collectionId].symbol))
        ) {
            collections[_collectionId].symbol = _symbol;

            emit SetSymbol(_collectionId, _symbol);
        }
    }

    function setCollectionDescription(
        uint256 _collectionId,
        string memory _description
    ) public collectionOwner(_collectionId) {
        if (
            keccak256(abi.encodePacked(_description)) !=
            keccak256(abi.encodePacked(collections[_collectionId].description))
        ) {
            collections[_collectionId].description = _description;

            emit SetDescription(_collectionId, _description);
        }
    }

    function getCollectionRoyalties(uint256 _collectionId)
        external
        view
        returns (LibShare.Share[] memory)
    {
        return royaltiesForCollection[_collectionId];
    }
}
