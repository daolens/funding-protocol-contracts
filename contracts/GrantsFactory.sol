// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Grants.sol";
import "./interfaces/IApplicationReviewRegistry.sol";
import "./interfaces/IGrants.sol";
import "./interfaces/IGrantFactory.sol";

contract GrantFactory is Ownable,Pausable,IGrantFactory {
    IApplicationReviewRegistry public applicationReviewReg;

    IApplicationRegistry public applicationReg;

    IWorkspaceRegistry public workspaceReg;

    mapping(uint256 => address[]) workspaceGrantMap;

    event GrantCreated(
        address grantAddress,
        uint256 workspaceId,
        string metadataHash,
        address[] reviewers,
        uint256 time
    );

    event GrantUpdatedFromFactory(
        address indexed grantAddress,
        uint256 indexed workspaceId,
        string metadataHash,
        bool active,
        uint256 time,
        address[] reviewers
    );

    modifier onlyWorkspaceAdmin(uint256 _workspaceId) {
        require(workspaceReg.isWorkspaceAdmin(_workspaceId, msg.sender), "Unauthorised: Not an admin");
        _;
    }

    modifier onlyApplicationRegistry() {
        require(msg.sender == address(applicationReg), "Unauthorised: Not applicationRegistry");
        _;
    }

    constructor(IWorkspaceRegistry _workspaceReg){
        workspaceReg = _workspaceReg;
    }

    function createGrant(
        uint256 _workspaceId,
        string memory _metadataHash,
        address _workspaceReg,
        address _applicationReg,
        address[] memory _reviewers,
        uint256 _amount,
        address _token,
        string memory _paymentType
    ) external whenNotPaused onlyWorkspaceAdmin(_workspaceId) returns (address) {
        
        address _grantAddress = address(new Grant(_workspaceId,_metadataHash,_workspaceReg,_applicationReg,address(this),_reviewers,_amount,_token,_paymentType,0x7D04A724BCd6c0DBAf976BE9e9b89758c300E45A));

        workspaceGrantMap[_workspaceId].push(_grantAddress);

        workspaceReg.increaseGrantCount(_workspaceId);
        emit GrantCreated(
            _grantAddress,
            _workspaceId,
            _metadataHash,
            _reviewers,
            block.timestamp
        );
        return _grantAddress;
    }

    function updateGrant(
        address grantAddress,
        uint256 _workspaceId,
        IWorkspaceRegistry _workspaceReg,
        string memory _metadataHash,
        address[] memory _reviewers
    ) external onlyWorkspaceAdmin(_workspaceId) {
        IGrants(grantAddress).updateGrant(_metadataHash,_reviewers);
        bool active = IGrants(grantAddress).getActive();
        emit GrantUpdatedFromFactory(grantAddress, _workspaceId, _metadataHash, active, block.timestamp,_reviewers);
    }

    function updateGrantAccessibility(
        address grantAddress,
        uint256 _workspaceId,
        IWorkspaceRegistry _workspaceReg,
        bool _canAcceptApplication
    ) external {
        require(_workspaceReg.isWorkspaceAdmin(_workspaceId, msg.sender), "GrantUpdate: Unauthorised");
        IGrants(grantAddress).updateGrantAccessibility(_canAcceptApplication);
        string memory metadataHash = IGrants(grantAddress).getMetadataHash();
        address[] memory reviewers = IGrants(grantAddress).getReviewers();
        emit GrantUpdatedFromFactory(grantAddress, _workspaceId, metadataHash, _canAcceptApplication, block.timestamp,reviewers);
    }

    function setApplicationReviewReg(IApplicationReviewRegistry _applicationReviewReg) external onlyOwner {
        applicationReviewReg = _applicationReviewReg;
    }

    function setApplicationReg(IApplicationRegistry _applicationReg) external onlyOwner {
        applicationReg = _applicationReg;
    }

           
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getWorkSpaceGrantMap(uint256 _workspaceId) external view returns (address[] memory){
        return workspaceGrantMap[_workspaceId];
    }
}
