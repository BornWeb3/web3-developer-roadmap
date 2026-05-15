// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IDistributor {
    function deposit() external payable;
}

contract GriefingReceiver {
    event Trapped(address indexed distributor, uint256 amount);

    function trap(address distributor) external payable {
        require(msg.value > 0, "ZERO_VALUE");

        IDistributor(distributor).deposit{value: msg.value}();
        emit Trapped(distributor, msg.value);
    }

    receive() external payable {
        revert("GRIEFING");
    }

    fallback() external payable {
        revert("GRIEFING");
    }
}
