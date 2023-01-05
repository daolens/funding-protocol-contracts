// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IApplicationRegistry {
    function getApplicationOwner(uint256 _applicationId) external view returns (address);
    function getApplicationWorkspace(uint256 _applicationId) external view returns (uint256);
    function updateApplicationStateGrant(uint256 _applicationId,address _grantAddress) external;
    function updateApplicationStateToApproveGrant(uint256 _applicationId,address _grantAddress) external;
}
