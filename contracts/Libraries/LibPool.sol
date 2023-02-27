// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "../FundingPool.sol";

library LibPool {
    function deployPoolAddress(address _poolOwner, address _poolRegistry)
        external
        returns (address)
    {
        FundingPool tokenAddress = new FundingPool(_poolOwner, _poolRegistry);

        return address(tokenAddress);
    }
}
