// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IWorkspaceRegistry {
    function isWorkspaceAdmin(uint256 _id, address _member) external view returns (bool);
}