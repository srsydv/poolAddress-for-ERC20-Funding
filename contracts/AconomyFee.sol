pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";

contract AconomyFee is Ownable {
    uint16 public _AconomyFee;

    event SetAconomyFee(uint16 newFee, uint16 oldFee);

    function protocolFee() public view virtual returns (uint16) {
        return _AconomyFee;
    }

    function getAconomyOwnerAddress() public view virtual returns (address) {
        return owner();
    }

    // Set Aconomy Fee in percent
    function setProtocolFee(uint16 newFee) public virtual onlyOwner {
        
        if (newFee == _AconomyFee) return;

        uint16 oldFee = _AconomyFee;
        _AconomyFee = newFee;
        emit SetAconomyFee(newFee, oldFee);
    }
}
