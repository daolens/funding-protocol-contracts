// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @title Interface of the grantFactory contract
interface IGrantFactory {
    function getWorkSpaceGrantMap(uint256 _workspaceId) external view returns (address[] memory);

}
