pragma solidity ^0.7.3;

contract Timer {
    uint256 private currentTime;

    constructor() public {
        currentTime = now;
    }

    function setCurrentTime(uint256 time) external {
        currentTime = time;
    }

    function getCurrentTime() public view returns (uint256) {
        return currentTime;
    }
}
