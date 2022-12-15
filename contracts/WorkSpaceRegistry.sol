// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IWorkSpaceRegistry.sol";


contract WorkspaceRegistry is Ownable,Pausable,IWorkspaceRegistry{

    using Counters for Counters.Counter;
    Counters.Counter private workspaceCount;

    constructor(){

    }   

    struct Safe {
        bytes32 _address;
        uint256 chainId;
    }

    struct WorkSpace {
        uint256 id;
        address owner;
        string metadataHash;
        Safe safe;
    }

    mapping(uint256 => WorkSpace) public WorkSpaces;

    mapping(uint256 => mapping(address => bytes32)) public memberRoles;

    // **** Events ****

    event WorkspaceCreated(uint256 indexed id, address indexed owner, string metadataHash, uint256 time,bytes32 safeAddress,uint256 safeChainId);

    event WorkspaceUpdated(uint256 indexed id, address indexed owner, string metadataHash, uint256 time);

    event WorkspaceSafeUpdated(
        uint256 indexed id,
        bytes32 safeAddress,
        uint256 safeChainId,
        uint256 time
    );

    // **** Modifier ****

    modifier onlyWorkspaceAdmin(uint256 _workspaceId) {
        require(_checkRole(_workspaceId, msg.sender, 0), "Unauthorised: Not an admin");
        _;
    }

    function createWorkspace(
        string memory _metadataHash,
        bytes32 _safeAddress,
        uint256 _safeChainId
    ) external whenNotPaused {
        uint256 id = workspaceCount.current();
        workspaceCount.increment();
        WorkSpaces[id] = WorkSpace(id,msg.sender,_metadataHash,Safe(_safeAddress, _safeChainId));
        _setRole(id,msg.sender,0,true);
        emit WorkspaceCreated(id, msg.sender, _metadataHash, block.timestamp, _safeAddress,_safeChainId);
    }

    function _setRole(
        uint256 _workspaceId,
        address _address,
        uint8 _role,
        bool _enabled
    ) internal {
        WorkSpace memory workspace = WorkSpaces[_workspaceId];

        if (_address == workspace.owner && _enabled == false && msg.sender != workspace.owner) {
            revert("WorkspaceOwner: Cannot disable owner admin role");
        }
        if (_enabled) {
            memberRoles[_workspaceId][_address] |= bytes32(1 << _role);
        } else {
            memberRoles[_workspaceId][_address] &= ~bytes32(1 << _role);
        }
    }

    function _checkRole(
        uint256 _workspaceId,
        address _address,
        uint8 _role
    ) internal view returns (bool) {
        return (uint256(memberRoles[_workspaceId][_address]) >> _role) & 1 != 0;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function updateWorkspaceMetadata(uint96 _id, string memory _metadataHash)
        external
        whenNotPaused
        onlyWorkspaceAdmin(_id)
    {
        WorkSpace storage workspace = WorkSpaces[_id];
        workspace.metadataHash = _metadataHash;
        emit WorkspaceUpdated(workspace.id, workspace.owner, workspace.metadataHash, block.timestamp);
    }

    function updateWorkspaceSafe(
        uint256 _id,
        bytes32 _safeAddress,
        uint256 _safeChainId
    ) external whenNotPaused onlyWorkspaceAdmin(_id) {
        WorkSpace storage workspace = WorkSpaces[_id];
        workspace.safe = Safe(_safeAddress, _safeChainId);
        emit WorkspaceSafeUpdated(_id, _safeAddress, _safeChainId, block.timestamp);
    }

    function isWorkspaceAdmin(uint256 _id, address _address) external view override returns (bool) {
        return _checkRole(_id, _address, 0);
    }
}