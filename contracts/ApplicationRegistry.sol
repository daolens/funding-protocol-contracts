// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IApplicationRegistry.sol";
import "./interfaces/IWorkSpaceRegistry.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IGrants.sol";

contract ApplicationRegistry is Ownable,Pausable,IApplicationRegistry {
    IWorkspaceRegistry public workspaceReg;
    IGrants public grantsReg;

    enum ApplicationState {
        Submitted,
        Resubmit,
        Approved,
        Rejected,
        Complete
    }

    enum MilestoneState {
        Submitted,
        Requested,
        Approved
    }

    struct Application {
        uint256 id;
        uint256 workspaceId;
        address grantAddress;
        address owner;
        uint256 milestoneCount;
        uint256 milestonesDone;
        string metadataHash;
        ApplicationState state;
        uint256[] milestonePayment;
    }

    using Counters for Counters.Counter;
    Counters.Counter private applicationCount;


    mapping(uint256 => Application) public applications;
    mapping(address => mapping(address => bool)) private applicantGrant;
    mapping(uint256 => mapping(uint256 => MilestoneState)) public applicationMilestones;


    // **** Events ****

    event ApplicationSubmitted(
        uint256 indexed applicationId,
        address grantAddress,
        address owner,
        string metadataHash,
        uint256 milestoneCount,
        uint256 time
    );

    event ApplicationUpdated(
        uint256 indexed applicationId,
        address owner,
        string metadataHash,
        ApplicationState state,
        uint256 milestoneCount,
        uint256 time
    );

    event MilestoneUpdated(uint256 _id, uint256 _milestoneId, MilestoneState _state, string _metadataHash, uint256 _time,address _grantId,uint256 _workspaceId);
    
    // **** Modifier ****

    modifier onlyGrantAdminOrReviewer() {
        require(
            grantsReg.isGrantAdminOrReviewer(msg.sender),
            "Unauthorised: Neither an admin nor a reviewer"
        );
        _;
    }

    constructor(IWorkspaceRegistry _workspaceReg){
        workspaceReg = _workspaceReg;
    }

    function submitApplication(
        address _grantAddress,
        uint256 _workspaceId,
        string memory _metadataHash,
        uint256 _milestoneCount,
        uint256[] memory _milestonePayments
    ) external {
        require(!applicantGrant[msg.sender][_grantAddress], "ApplicationSubmit: Already applied to grant once");
        require(grantsReg.getActive(), "ApplicationSubmit: Invalid grant");
        
        uint256 id = applicationCount.current();
        applicationCount.increment();
        applications[id] = Application(
            id,
            _workspaceId,
            _grantAddress,
            msg.sender,
            _milestoneCount,
            0,
            _metadataHash,
            ApplicationState.Submitted,
            _milestonePayments
        );
        applicantGrant[msg.sender][_grantAddress] = true;

        emit ApplicationSubmitted(id, _grantAddress, msg.sender, _metadataHash, _milestoneCount, block.timestamp);
        grantsReg.incrementApplicant();
    }

    function updateApplicationMetadata(
        uint256 _applicationId,
        string memory _metadataHash,
        uint256 _milestoneCount
    ) external {
        Application storage application = applications[_applicationId];
        require(application.owner == msg.sender, "ApplicationUpdate: Unauthorised");
        require(
            application.state == ApplicationState.Resubmit || application.state == ApplicationState.Submitted,
            "ApplicationUpdate: Invalid state"
        );

        for (uint256 i = 0; i < application.milestoneCount; i++) {
            applicationMilestones[_applicationId][i] = MilestoneState.Submitted;
        }
        application.milestoneCount = _milestoneCount;
        application.metadataHash = _metadataHash;
        application.state = ApplicationState.Submitted;
        emit ApplicationUpdated(
            _applicationId,
            msg.sender,
            _metadataHash,
            ApplicationState.Submitted,
            _milestoneCount,
            block.timestamp
        );
    }

    function updateApplicationState(
        uint256 _applicationId,
        uint256 _workspaceId,
        ApplicationState _state,
        string memory _reasonMetadataHash,
        address _grantAddress
    ) public onlyGrantAdminOrReviewer {
        Application storage application = applications[_applicationId];
        require(application.workspaceId == _workspaceId, "ApplicationStateUpdate: Invalid workspace");

        if (
            (application.state == ApplicationState.Submitted && _state == ApplicationState.Resubmit) ||
            (application.state == ApplicationState.Submitted && _state == ApplicationState.Approved) ||
            (application.state == ApplicationState.Submitted && _state == ApplicationState.Rejected)
        ) {
            application.state = _state;

            string memory paymentType = IGrants(_grantAddress).getPaymentType();

            if(_state == ApplicationState.Approved && keccak256(abi.encodePacked("UPFRONT")) == keccak256(abi.encodePacked(paymentType))){
                uint256 amount = IGrants(_grantAddress).getAmount();
                IGrants(_grantAddress).payApplicant(application.owner,amount);

            }

        } else {
            revert("ApplicationStateUpdate: Invalid state transition");
        }

        emit ApplicationUpdated(
            _applicationId,
            msg.sender,
            _reasonMetadataHash,
            _state,
            application.milestoneCount,
            block.timestamp
        );
    }

    function requestMilestoneApproval(
        uint256 _applicationId,
        uint256 _milestoneId,
        string memory _reasonMetadataHash,
        uint256 _workspaceId,
        address _grantAddress
    ) external {
        Application memory application = applications[_applicationId];
        require(application.owner == msg.sender, "MilestoneStateUpdate: Unauthorised");
        require(application.state == ApplicationState.Approved, "MilestoneStateUpdate: Invalid application state");
        require(_milestoneId < application.milestoneCount, "MilestoneStateUpdate: Invalid milestone id");
        require(
            applicationMilestones[_applicationId][_milestoneId] == MilestoneState.Submitted,
            "MilestoneStateUpdate: Invalid state transition"
        );
        applicationMilestones[_applicationId][_milestoneId] = MilestoneState.Requested;
        emit MilestoneUpdated(
            _applicationId,
            _milestoneId,
            MilestoneState.Requested,
            _reasonMetadataHash,
            block.timestamp,
            _grantAddress,
            _workspaceId
        );
    }

    function approveMilestone(
        uint256 _applicationId,
        uint256 _milestoneId,
        uint256 _workspaceId,
        address _grantAddress,
        string memory _reasonMetadataHash
    ) external onlyGrantAdminOrReviewer {
        
        Application storage application = applications[_applicationId];
        require(application.workspaceId == _workspaceId, "ApplicationStateUpdate: Invalid workspace");
        require(application.state == ApplicationState.Approved, "MilestoneStateUpdate: Invalid application state");
        require(_milestoneId < application.milestoneCount, "MilestoneStateUpdate: Invalid milestone id");
        MilestoneState currentState = applicationMilestones[_applicationId][_milestoneId];

        if (currentState == MilestoneState.Submitted || currentState == MilestoneState.Requested) {
            applicationMilestones[_applicationId][_milestoneId] = MilestoneState.Approved;

            string memory paymentType = IGrants(_grantAddress).getPaymentType();

            if(keccak256(abi.encodePacked("MILESTONE")) == keccak256(abi.encodePacked(paymentType))){
                uint256 amount = IGrants(_grantAddress).getAmount();
                IGrants(_grantAddress).payApplicant(application.owner,amount);
            }
        } else {
            revert("MilestoneStateUpdate: Invalid state transition");
        }

        application.milestonesDone += 1;

        emit MilestoneUpdated(
            _applicationId,
            _milestoneId,
            MilestoneState.Approved,
            _reasonMetadataHash,
            block.timestamp,
            _grantAddress,
            _workspaceId
        );

    }

    function setGrantReg(IGrants _grantsReg) external onlyOwner {
        grantsReg = _grantsReg;
    }

    function getApplicationOwner(uint256 _applicationId) external view override returns (address) {
        Application memory application = applications[_applicationId];
        return application.owner;
    }

    function getApplicationWorkspace(uint256 _applicationId) external view override returns (uint256) {
        Application memory application = applications[_applicationId];
        return application.workspaceId;
    }

}