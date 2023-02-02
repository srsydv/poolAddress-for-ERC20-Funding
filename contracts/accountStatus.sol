// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "./interfaces/IaccountStatus.sol";
import "./poolAddress.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract accountStatus is IaccountStatus {
    using EnumerableSet for EnumerableSet.UintSet;

    mapping(address => EnumerableSet.UintSet) private _currentBads;
    mapping(address => EnumerableSet.UintSet) private _currentDefaults;
    mapping(address => EnumerableSet.UintSet) private _bads;
    mapping(address => EnumerableSet.UintSet) private _defaults;

    event StatusAdded(
        address indexed account,
        StatusMark indexed sttsMark,
        uint256 loanId
    );
    event StatusRemoved(
        address indexed account,
        StatusMark indexed sttsMark,
        uint256 loanId
    );

    function updateStatus(
        address _account,
        uint256 _loanId,
        address _poolAddress
    ) public returns (StatusMark) {
        return _updateStatus(_account, _loanId, _poolAddress);
    }

    function _updateStatus(
        address _account,
        uint256 _loanId,
        address _poolAddress
    ) internal returns (StatusMark status_) {
        status_ = StatusMark.Good;

        if (poolAddress(_poolAddress).isLoanDefaulted(_loanId)) {
            status_ = StatusMark.Default;
            _removeStatus(_account, _loanId, StatusMark.Bad);
        } else if (poolAddress(_poolAddress).isPaymentLate(_loanId)) {
            status_ = StatusMark.Bad;
        }
        if (status_ != StatusMark.Good) {
            _addStatus(_account, _loanId, status_);
        }
    }

    function _addStatus(
        address _account,
        uint256 _loanId,
        StatusMark _status
    ) internal {
        if (_status == StatusMark.Bad) {
            _bads[_account].add(_loanId);
            _currentBads[_account].add(_loanId);
        } else if (_status == StatusMark.Default) {
            _defaults[_account].add(_loanId);
            _currentDefaults[_account].add(_loanId);
        }

        emit StatusAdded(_account, _status, _loanId);
    }

    function _addStatus1(
        address _account,
        uint256 _loanId,
        StatusMark Good
    ) public {
        if (Good == StatusMark.Bad) {
            _bads[_account].add(_loanId);
            _currentBads[_account].add(_loanId);
        } else if (Good == StatusMark.Default) {
            _defaults[_account].add(_loanId);
            _currentDefaults[_account].add(_loanId);
        }

        emit StatusAdded(_account, Good, _loanId);
    }

    function _removeStatus(
        address _account,
        uint256 _loanId,
        StatusMark _status
    ) internal {
        if (_status == StatusMark.Bad) {
            _currentBads[_account].remove(_loanId);
        } else if (_status == StatusMark.Default) {
            _currentDefaults[_account].remove(_loanId);
        }

        emit StatusRemoved(_account, _status, _loanId);
    }
}
