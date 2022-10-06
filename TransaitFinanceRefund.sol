// SPDX-License-Identifier: MIT
// Transit Finance Refund Contracts

pragma solidity ^0.8.7;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract TransitFinanceRefund {

    struct refund {
        address user;
        address token;
        uint256 amount;
    }

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    address private _owner;
    address private _executor;
    uint256 public claimStartTime;
    bool public claimPause;

    mapping(address => refund) private _refund;
    mapping(address => bool) private _claimed;

    event SetRefunder(address indexed user, address indexed token, uint256 amount);
    event SetClaim(uint256 previousTime, uint256 latestTime, bool previousPause, bool latestPause);
    event Withdraw(address indexed recipient, address indexed token, uint256 amount);
    event Refund(address indexed recipient, address indexed token, uint256 amount, uint256 time);
    event Receipt(address from, uint256 amount);

    constructor(address theExecutor) {
        require(_owner == address(0), "initialized");
        _owner = msg.sender;
        _executor = theExecutor;
        claimPause = true;
    }

    receive() external payable {
        emit Receipt(msg.sender, msg.value);
    }

    function executor() public view returns (address) {
        return _executor;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function refundAsset(address user) public view returns (refund memory asset, bool claimed) {
        asset = _refund[user];
        claimed = _claimed[user];
    }

    function setRefunder(refund[] calldata refunds) public onlyExecutor {
        for (uint i; i < refunds.length; i++) {
            emit SetRefunder(refunds[i].user, refunds[i].token, refunds[i].amount);
            _refund[refunds[i].user] = refunds[i];
        }
    }

    function setClaim(bool pause, uint256 time) public onlyOwner {
        emit SetClaim(claimStartTime, time, claimPause, pause);
        if(time != 0) {
            claimStartTime = time;
        }
        claimPause = pause;
    }

    function claim() public checkClaimAndNonReentrant {
        require(!_claimed[msg.sender], "Refunded");
        refund memory thisRefund = _refund[msg.sender];
        require(thisRefund.amount > 0, "No accessible refund");
        _claimed[msg.sender] = true;
        if (thisRefund.token == address(0)) {
            payable(thisRefund.user).transfer(thisRefund.amount);
        } else {
            bool result = IERC20(thisRefund.token).transfer(thisRefund.user, thisRefund.amount);
            require(result, "Refund failed");
        }
        emit Refund(thisRefund.user, thisRefund.token, thisRefund.amount, block.timestamp);
    }

    function emergencyWithdraw(address[] memory tokens, uint256[] memory amounts, address recipient) external onlyExecutor {
        require(tokens.length == amounts.length, "Invalid data");
        for (uint256 i; i <= tokens.length; i++) {
            if (tokens[i] == address(0)) {
                payable(recipient).transfer(amounts[i]);
            } else {
                IERC20(tokens[i]).transfer(recipient, amounts[i]);
            }
            emit Withdraw(recipient, tokens[i], amounts[i]);
        }
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Caller is not the owner");
        _;
    }

    modifier onlyExecutor() {
        require(executor() == msg.sender, "Caller is not the executor");
        _;
    }

    modifier checkClaimAndNonReentrant() {
        require(block.timestamp >= claimStartTime && claimStartTime != 0, "Coming soon");
        require(!claimPause, "Refund suspended");
        require(_status != _ENTERED, "Reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

}