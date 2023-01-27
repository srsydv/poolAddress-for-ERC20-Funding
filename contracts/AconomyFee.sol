pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";

contract AconomyFee is Ownable {
    uint16 public _AconomyFee;
    address public AconomyOwnerAddress;

    event SetAconomyFee(uint16 newFee, uint16 oldFee);

    function protocolFee() public view virtual returns (uint16) {
        return _AconomyFee;
    }

    function getAconomyOwnerAddress() public view virtual returns (address) {
        return AconomyOwnerAddress;
    }

    // Set Aconomy Fee in percent
    function setProtocolFee(uint16 newFee) public virtual onlyOwner {
        AconomyOwnerAddress = msg.sender;
        // Skip if the fee is the same
        if (newFee == _AconomyFee) return;

        uint16 oldFee = _AconomyFee;
        _AconomyFee = newFee;
        emit SetAconomyFee(newFee, oldFee);
    }
}

// 0xb45596fCDdf2323A3c50333AF74B7e1077838D88
// 0xd9145CCE52D386f254917e481eB44e9943F39138
