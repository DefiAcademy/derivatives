// SPDX-License-Identifier: MIT

pragma solidity ^0.7.3;

contract Timer {
    uint256 private currentTime;

    constructor() {
        currentTime = 0;
    }

    function setTime(uint256 _newTime) public {
        currentTime = _newTime;
    }

    function getTime() public view returns (uint256) {
        return currentTime;
    }
}
