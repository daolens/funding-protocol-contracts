// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "../ApplicationRegistry.sol";

interface IApplicationRegistry {
    function getApplicationOwner(uint256 _applicationId) external view returns (address);
    function getApplicationWorkspace(uint256 _applicationId) external view returns (uint256);
    function updateApplicationStateGrant(uint256 _applicationId, ApplicationRegistry.ApplicationState _state) external;
    function updateMilestoneStateGrant(uint256 _applicationId, uint256 _milestoneId, ApplicationRegistry.MilestoneState _state) external;
}
