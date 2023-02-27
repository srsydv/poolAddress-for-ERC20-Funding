// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./utils/LibShare.sol";
import "./Libraries/LibPool.sol";
import "./Libraries/LibCollection.sol";

contract piNFT is ERC721URIStorage, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    // tokenId => (token contract => balance)
    mapping(uint256 => mapping(address => uint256)) erc20Balances;

    // tokenId => token contract
    mapping(uint256 => address[]) erc20Contracts;

    // tokenId => royalties
    mapping(uint256 => LibShare.Share[]) public royaltiesByTokenId;

    mapping(uint256 => LibShare.Share[]) public royaltiesForValidator;

    // collectionId => royalties
    mapping(uint256 => LibShare.Share[]) public royaltiesForCollection;

    // tokenId => (token contract => token contract index)
    mapping(uint256 => mapping(address => uint256)) erc20ContractIndex;

    // TokenId => Owner Address
    mapping(uint256 => address) NFTowner;

    // TokenId => Amount
    mapping(uint256 => uint256) withdrawnAmount;

    uint256 public collectionId;

    event ReceivedERC20(
        address indexed _from,
        uint256 indexed _tokenId,
        address indexed _erc20Contract,
        uint256 _value
    );
    event TransferERC20(
        uint256 indexed _tokenId,
        address indexed _to,
        address indexed _erc20Contract,
        uint256 _value
    );
    event RoyaltiesSetForTokenId(
        uint256 indexed tokenId,
        LibShare.Share[] indexed royalties
    );

    event Royalties(
        uint256 indexed tokenId,
        LibShare.Share[] indexed royalties
    );

    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {}

    modifier onlyOwnerOfToken(uint256 _tokenId) {
        require(
            msg.sender == ERC721.ownerOf(_tokenId),
            "Only token owner can execute"
        );
        _;
    }

    // mints an ERC721 token to _to with _uri as token uri
    function mintNFT(
        address _to,
        string memory _uri,
        LibShare.Share[] memory royalties
    ) public returns (uint256) {
        require(_to != address(0), "You can't mint with 0 address");
        uint256 tokenId_ = _tokenIdCounter.current();
        NFTowner[tokenId_] = msg.sender;
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
        require(royalties.length <= 10, "Atmost 10 royalties can be added");
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

    function getValidatorRoyalties(uint256 _tokenId)
        external
        view
        returns (LibShare.Share[] memory)
    {
        return royaltiesForValidator[_tokenId];
    }

    // this function requires approval of tokens by _erc20Contract
    // adds ERC20 tokens to the token with _tokenId(basically trasnfer ERC20 to this contract)
    function addERC20(
        uint256 _tokenId,
        address _erc20Contract,
        uint256 _value,
        LibShare.Share[] memory royalties
    ) public {
        require(
            _erc20Contract != address(0),
            "you can't do this with zero address"
        );
        erc20Received(msg.sender, _tokenId, _erc20Contract, _value);
        setRoyaltiesForValidator(_tokenId, royalties);
        require(
            IERC20(_erc20Contract).transferFrom(
                msg.sender,
                address(this),
                _value
            ),
            "ERC20 transfer failed."
        );
    }

    // update the mappings for a token on recieving ERC20 tokens
    function erc20Received(
        address _from,
        uint256 _tokenId,
        address _erc20Contract,
        uint256 _value
    ) private {
        require(
            ERC721.ownerOf(_tokenId) != address(0),
            "_tokenId does not exist."
        );
        if (_value == 0) {
            return;
        }
        uint256 erc20Balance = erc20Balances[_tokenId][_erc20Contract];
        if (erc20Balance == 0) {
            erc20ContractIndex[_tokenId][_erc20Contract] = erc20Contracts[
                _tokenId
            ].length;
            erc20Contracts[_tokenId].push(_erc20Contract);
        }
        erc20Balances[_tokenId][_erc20Contract] += _value;
        emit ReceivedERC20(_from, _tokenId, _erc20Contract, _value);
    }

    //Set Royalties for Validator
    function setRoyaltiesForValidator(
        uint256 _tokenId,
        LibShare.Share[] memory royalties
    ) internal {
        require(royalties.length <= 10, "Atmost 10 royalties can be added");
        delete royaltiesForValidator[_tokenId];
        uint256 sumRoyalties = 0;
        for (uint256 i = 0; i < royalties.length; i++) {
            require(
                royalties[i].account != address(0x0),
                "Royalty recipient should be present"
            );
            require(royalties[i].value != 0, "Royalty value should be > 0");
            royaltiesForValidator[_tokenId].push(royalties[i]);
            sumRoyalties += royalties[i].value;
        }
        require(sumRoyalties < 10000, "Sum of Royalties > 100%");

        emit Royalties(_tokenId, royalties);
    }

    function redeemPiNFT(
        uint256 _tokenId,
        address _nftReciever,
        address _validatorAddress,
        address _erc20Contract,
        uint256 _value
    ) external onlyOwnerOfToken(_tokenId) nonReentrant {
        require(
            _erc20Contract != address(0),
            "you can't do this with zero address"
        );
        require(_nftReciever != address(0), "cannot transfer to zero address");
        _transferERC20(_tokenId, _validatorAddress, _erc20Contract, _value);
        ERC721.safeTransferFrom(msg.sender, _nftReciever, _tokenId);
    }

    function burnPiNFT(
        uint256 _tokenId,
        address _nftReciever,
        address _erc20Reciever,
        address _erc20Contract,
        uint256 _value
    ) external onlyOwnerOfToken(_tokenId) nonReentrant {
        require(
            _erc20Contract != address(0),
            "you can't do this with zero address"
        );
        require(_nftReciever != address(0), "cannot transfer to zero address");
        _transferERC20(_tokenId, _erc20Reciever, _erc20Contract, _value);
        ERC721.safeTransferFrom(msg.sender, _nftReciever, _tokenId);
    }

    // transfers the ERC 20 tokens from _tokenId(this contract) to _to address
    function _transferERC20(
        uint256 _tokenId,
        address _to,
        address _erc20Contract,
        uint256 _value
    ) private {
        require(_to != address(0), "cannot send to zero address");
        address rootOwner = ERC721.ownerOf(_tokenId);
        require(rootOwner == msg.sender, "only owner can transfer");
        removeERC20(_tokenId, _erc20Contract, _value);
        require(
            IERC20(_erc20Contract).transfer(_to, _value),
            "ERC20 transfer failed."
        );
        emit TransferERC20(_tokenId, _to, _erc20Contract, _value);
    }

    // update the mappings for a token when ERC20 tokens gets removed
    function removeERC20(
        uint256 _tokenId,
        address _erc20Contract,
        uint256 _value
    ) private {
        if (_value == 0) {
            return;
        }
        uint256 erc20Balance = erc20Balances[_tokenId][_erc20Contract];
        require(
            erc20Balance >= _value,
            "Not enough token available to transfer."
        );
        uint256 newERC20Balance = erc20Balance - _value;
        erc20Balances[_tokenId][_erc20Contract] = newERC20Balance;
        if (newERC20Balance == 0) {
            uint256 lastContractIndex = erc20Contracts[_tokenId].length - 1;
            address lastContract = erc20Contracts[_tokenId][lastContractIndex];
            if (_erc20Contract != lastContract) {
                uint256 contractIndex = erc20ContractIndex[_tokenId][
                    _erc20Contract
                ];
                erc20Contracts[_tokenId][contractIndex] = lastContract;
                erc20ContractIndex[_tokenId][lastContract] = contractIndex;
            }
            delete erc20ContractIndex[_tokenId][_erc20Contract];
            erc20Contracts[_tokenId].pop();
        }
    }

    // view ERC 20 token balance of a token
    function viewBalance(uint256 _tokenId, address _erc20Address)
        public
        view
        returns (uint256)
    {
        return erc20Balances[_tokenId][_erc20Address];
    }

    function withdraw(
        uint256 _tokenId,
        address _erc20Contract,
        uint256 _amount
    ) external nonReentrant {
        require(NFTowner[_tokenId] == msg.sender, "You can't withdraw");
        require(
            IERC20(_erc20Contract).transfer(msg.sender, _amount),
            "unable to transfer to receiver"
        );

        withdrawnAmount[_tokenId] += _amount;

        //needs approval on frontend
        // transferring NFT to this address
        ERC721.safeTransferFrom(msg.sender, address(this), _tokenId);
    }

    function viewWithdrawnAmount(uint256 _tokenId)
        public
        view
        returns (uint256)
    {
        return withdrawnAmount[_tokenId];
    }

    function Repay(
        uint256 _tokenId,
        address _erc20Contract,
        uint256 _amount
    ) external nonReentrant {
        require(NFTowner[_tokenId] == msg.sender, "You can't withdraw");

        // Send payment to the Pool
        require(
            IERC20(_erc20Contract).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "Unable to tansfer to poolAddress"
        );
        withdrawnAmount[_tokenId] -= _amount;

        if (withdrawnAmount[_tokenId] <= 0) {
            ERC721.safeTransferFrom(address(this), msg.sender, _tokenId);
        }
    }
}
