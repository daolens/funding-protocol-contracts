// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IWorkSpaceRegistry.sol";
import "./interfaces/IGrants.sol";
import "./interfaces/IGrantFactory.sol";

contract WorkspaceRegistry is Ownable,Pausable,IWorkspaceRegistry{

    using Counters for Counters.Counter;
    Counters.Counter private workspaceCount;

    constructor(){

    }   

    struct Safe {
        string _address;
        uint256 chainId;
    }

    struct WorkSpace {
        uint256 id;
        address owner;
        string metadataHash;
        Safe safe;
        uint256 applicationCount;
        uint256 grantCount;
        uint256 totalFunds;
        uint256 totalAmountSpentGrant;
    }
    struct Grant {
        uint256 numApplicants;
        string metadataHash;
        uint256 balance;
        address grantAddress;
        uint256 amountSpent;
    }

    mapping(uint256 => WorkSpace) public WorkSpaces;
    
    mapping(uint256 => mapping(address => bytes32)) public memberRoles;

    WorkSpace[] workSpacesArr;
    // **** Events ****

    event WorkspaceCreated(uint256 indexed id, address indexed owner, string metadataHash, uint256 time,string safeAddress,uint256 safeChainId);

    event WorkspaceUpdated(uint256 indexed id, address indexed owner, string metadataHash, uint256 time);

    event WorkspaceSafeUpdated(
        uint256 indexed id,
        string safeAddress,
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
        string memory _safeAddress,
        uint256 _safeChainId
    ) external whenNotPaused returns(uint256) {
        uint256 id = workspaceCount.current();
        workspaceCount.increment();
        
        WorkSpaces[id] = WorkSpace(id,msg.sender,_metadataHash,Safe(_safeAddress, _safeChainId),0,0,0,0);
        workSpacesArr.push(WorkSpaces[id]);

        _setRole(id,msg.sender,0,true);
        emit WorkspaceCreated(id, msg.sender, _metadataHash, block.timestamp, _safeAddress,_safeChainId);
        return id;
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
        onlyWorkspaceAdmin(_id){
        WorkSpace storage workspace = WorkSpaces[_id];
        workspace.metadataHash = _metadataHash;
        for(uint256 i = 0;i < workSpacesArr.length;i++){
            if(workSpacesArr[i].id == _id){
                workSpacesArr[i].metadataHash = _metadataHash;
            }
        }
        emit WorkspaceUpdated(workspace.id, workspace.owner, workspace.metadataHash, block.timestamp);
    }

    function updateWorkspaceSafe(
        uint256 _id,
        string memory _safeAddress,
        uint256 _safeChainId
    ) external whenNotPaused onlyWorkspaceAdmin(_id) {
        WorkSpace storage workspace = WorkSpaces[_id];
        workspace.safe = Safe(_safeAddress, _safeChainId);

        emit WorkspaceSafeUpdated(_id, _safeAddress, _safeChainId, block.timestamp);
    }

    function isWorkspaceAdmin(uint256 _id, address _address) external view override returns (bool) {
        return _checkRole(_id, _address, 0);
    }

    function fetchWorkSpaces(address _grantFactory) external view returns (WorkSpace[] memory,uint256[][] memory,uint256[][] memory, address[][] memory) {
        uint256[][] memory balances = new uint256[][](workSpacesArr.length);
        uint256[][] memory balanceSpends = new uint256[][](workSpacesArr.length);
        address[][] memory tokenAddress = new address[][](workSpacesArr.length);

        for(uint256 i = 0;i < workSpacesArr.length;i++){
            address[] memory grantAddress = IGrantFactory(_grantFactory).getWorkSpaceGrantMap(workSpacesArr[i].id);

            uint256[] memory grantBalances = new uint256[](grantAddress.length);
            uint256[] memory grantBalanceSpends = new uint256[](grantAddress.length);
            address[] memory grantTokenAddress = new address[](grantAddress.length);

            for(uint256 j = 0;j < grantAddress.length;j++){
                grantBalances[j] = IGrants(grantAddress[j]).getAmount();
                grantBalanceSpends[j] = IGrants(grantAddress[j]).getAmountSpent();
                grantTokenAddress[j] = IGrants(grantAddress[j]).getToken();
            }
            balances[i] = grantBalances;
            balanceSpends[i] = grantBalanceSpends;
            tokenAddress[i] = grantTokenAddress;
        }
        return (workSpacesArr,balances,balanceSpends, tokenAddress);
    }

    function fetchWorkSpaceDetails(uint256 _id,address _grantFactory) external view returns (WorkSpace memory,Grant[] memory) {

        address[] memory _grantAddress = IGrantFactory(_grantFactory).getWorkSpaceGrantMap(_id);
        uint256 len = _grantAddress.length;
        Grant[] memory grantsDetails = new Grant[](len);

        for(uint256 i = 0;i < _grantAddress.length;i++){
            (uint256 numApplicants,string memory metadataHash,uint256 balance,uint256 amountSpent) = IGrants(_grantAddress[i]).getDetails();
            grantsDetails[i] = Grant(numApplicants,metadataHash,balance,_grantAddress[i],amountSpent);
        }
        return (WorkSpaces[_id],grantsDetails);
    }

    function increaseApplicationCount(uint256 _workspaceId) external override {
        WorkSpaces[_workspaceId].applicationCount++;
        for(uint256 i = 0;i < workSpacesArr.length;i++){
            if(workSpacesArr[i].id == _workspaceId){
                workSpacesArr[i] = WorkSpaces[_workspaceId];
                break;
            }
        }
    }

    function increaseGrantCount(uint256 _workspaceId) external override {
        WorkSpaces[_workspaceId].grantCount++;
        for(uint256 i = 0;i < workSpacesArr.length;i++){
            if(workSpacesArr[i].id == _workspaceId){
                workSpacesArr[i] = WorkSpaces[_workspaceId];
                break;
            }
        }
    }

    function getMetaDataHash(uint256 _workspaceId) external view override returns(string memory){
        return WorkSpaces[_workspaceId].metadataHash;
    }

}