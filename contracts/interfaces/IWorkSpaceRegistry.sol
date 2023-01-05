// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IWorkspaceRegistry {
    function isWorkspaceAdmin(uint256 _id, address _member) external view returns (bool);
    function increaseApplicationCount(uint256 _workspaceId) external ;
    function increaseGrantCount(uint256 _workspaceId) external;
    function getMetaDataHash(uint256 _workspaceId) external view returns(string memory);
}