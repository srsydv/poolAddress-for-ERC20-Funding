// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../CollectionMethods.sol";

library LibCollection {
    function deployCollectionAddress(
        address _collectionOwner,
        address _piNFT,
        string memory _name,
        string memory _symbol
    ) external returns (address) {
        CollectionMethods tokenAddress = new CollectionMethods(
            _collectionOwner,
            _piNFT,
            _name,
            _symbol
        );

        return address(tokenAddress);
    }
}
