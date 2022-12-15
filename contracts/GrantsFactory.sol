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
        IWorkspaceRegistry _workspaceReg,
        IApplicationRegistry _applicationReg,
        address[] memory _reviewers,
        uint256 _amount,
        address _token,
        string memory _paymentType
    ) external whenNotPaused onlyWorkspaceAdmin(_workspaceId) returns (address) {
        
        address _grantAddress = address(new Grant(_workspaceId,_metadataHash,_workspaceReg,_applicationReg,this,_reviewers,_amount,_token,_paymentType));

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
        string memory _metadataHash
    ) external onlyWorkspaceAdmin(_workspaceId) {
        IGrants(grantAddress).updateGrant(_metadataHash);
        bool active = IGrants(grantAddress).getActive();
        address[] memory reviewers = IGrants(grantAddress).getReviewers();
        emit GrantUpdatedFromFactory(grantAddress, _workspaceId, _metadataHash, active, block.timestamp,reviewers);
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
}
