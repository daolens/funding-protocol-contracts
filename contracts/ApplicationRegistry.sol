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
        Complete,
        RejectPending,
        ApprovePending
    }

    enum MilestoneState {
        Submitted,
        Requested,
        Approved,
        ApprovePending
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
        uint256 totalFunds;
    }

    struct RejectAppPend{
        uint256 applicationId;
        uint256 time;
    }   

    struct MilestoneStateApp{
        MilestoneState state;
        string reviewersHash;
        string applicantHash;
    }
    RejectAppPend[] rejectAppPending;

    using Counters for Counters.Counter;
    Counters.Counter private applicationCount;


    mapping(uint256 => Application) public applications;
    mapping(address => mapping(address => bool)) private applicantGrant;
    mapping(uint256 => mapping(uint256 => MilestoneStateApp)) public applicationMilestones;
    mapping(address => Application[]) creatorApplicationMap;
    mapping(uint256 => string) applicationsReasons;
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

    event ApplicationRejectStatusReverted(uint256 _applicationId,address _grantAddress,uint256 _time,ApplicationState _state);
    // **** Modifier ****

    modifier onlyGrantAdminOrReviewer(address _grantAddress) {
        require(
            IGrants(_grantAddress).isGrantAdminOrReviewer(msg.sender),
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
        uint256[] memory _milestonePayments,
        uint256 _totalAmount
    ) external returns(uint256) {
        require(!applicantGrant[msg.sender][_grantAddress], "ApplicationSubmit: Already applied to grant once");
        require(IGrants(_grantAddress).getActive(), "ApplicationSubmit: Invalid grant");
        
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
            _milestonePayments,
            _totalAmount
        );
        creatorApplicationMap[msg.sender].push(applications[id]);
        workspaceReg.increaseApplicationCount(_workspaceId);
        applicantGrant[msg.sender][_grantAddress] = true;

        emit ApplicationSubmitted(id, _grantAddress, msg.sender, _metadataHash, _milestoneCount, block.timestamp);
        IGrants(_grantAddress).incrementApplicant();
        return id;
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
            applicationMilestones[_applicationId][i].state = MilestoneState.Submitted;
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
    ) public onlyGrantAdminOrReviewer(_grantAddress) {
        Application storage application = applications[_applicationId];
        require(application.workspaceId == _workspaceId, "ApplicationStateUpdate: Invalid workspace");

        if (
            (application.state == ApplicationState.Submitted && _state == ApplicationState.Resubmit) ||
            (application.state == ApplicationState.Submitted && _state == ApplicationState.Approved) ||
            (application.state == ApplicationState.Submitted && _state == ApplicationState.Rejected)
        ) {
            if(_state != ApplicationState.Rejected){
                application.state = _state;
                string memory paymentType = IGrants(_grantAddress).getPaymentType();

                if(_state == ApplicationState.Approved && keccak256(abi.encodePacked("UPFRONT")) == keccak256(abi.encodePacked(paymentType))){
                    application.state = ApplicationState.ApprovePending;
                    IGrants(_grantAddress).payApplicant(application.owner,application.totalFunds,_applicationId, false, 0);
                }
            }
            else {
                application.state = ApplicationState.RejectPending;
                rejectAppPending.push(RejectAppPend(_applicationId,block.timestamp + 3 days));
            }
            applicationsReasons[_applicationId] = _reasonMetadataHash;
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
            applicationMilestones[_applicationId][_milestoneId].state == MilestoneState.Submitted,
            "MilestoneStateUpdate: Invalid state transition"
        );
        applicationMilestones[_applicationId][_milestoneId].state = MilestoneState.Requested;
        applicationMilestones[_applicationId][_milestoneId].applicantHash = _reasonMetadataHash;

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
    ) external onlyGrantAdminOrReviewer(_grantAddress) {
        
        Application storage application = applications[_applicationId];
        require(application.workspaceId == _workspaceId, "ApplicationStateUpdate: Invalid workspace");
        require(application.state == ApplicationState.Approved, "MilestoneStateUpdate: Invalid application state");
        require(_milestoneId < application.milestoneCount, "MilestoneStateUpdate: Invalid milestone id");
        MilestoneState currentState = applicationMilestones[_applicationId][_milestoneId].state;

        if (currentState == MilestoneState.Submitted || currentState == MilestoneState.Requested) {
            applicationMilestones[_applicationId][_milestoneId].state = MilestoneState.ApprovePending;
            applicationMilestones[_applicationId][_milestoneId].applicantHash = _reasonMetadataHash;
            string memory paymentType = IGrants(_grantAddress).getPaymentType();

            if(keccak256(abi.encodePacked("MILESTONE")) == keccak256(abi.encodePacked(paymentType))){
                IGrants(_grantAddress).payApplicant(application.owner,application.milestonePayment[_milestoneId],_applicationId, true, _milestoneId);
            }
        } else {
            revert("MilestoneStateUpdate: Invalid state transition");
        }

        application.milestonesDone += 1;

        emit MilestoneUpdated(
            _applicationId,
            _milestoneId,
            MilestoneState.ApprovePending,
            _reasonMetadataHash,
            block.timestamp,
            _grantAddress,
            _workspaceId
        );

    }

    // function setGrantReg(IGrants _grantsReg) external onlyOwner {
    //     grantsReg = _grantsReg;
    // }

    function getApplicationOwner(uint256 _applicationId) external view override returns (address) {
        Application memory application = applications[_applicationId];
        return application.owner;
    }

    function getApplicationWorkspace(uint256 _applicationId) external view override returns (uint256) {
        Application memory application = applications[_applicationId];
        return application.workspaceId;
    }

    function getGrantApplications(address _grantAddress,uint256 _noOfApplications) external view returns (Application[] memory) {
        Application[] memory grantApplications = new Application[](_noOfApplications);
        uint256 ct = 0;
        for(uint256 i = 0;i < applicationCount.current();i++){
            Application memory application = applications[i];
            if(application.grantAddress == _grantAddress){
                grantApplications[ct] = application;
                ct++;
            }
        }
        return grantApplications;
    }

    function updateApplicationStateGrant(uint256 _applicationId,address _grantAddress, ApplicationState _state) external override onlyGrantAdminOrReviewer(_grantAddress)  {
        applications[_applicationId].state = _state;
    }

    function updateMilestoneStateGrant(uint256 _applicationId, uint256 _milestoneId, address _grantAddress, MilestoneState _state) external override onlyGrantAdminOrReviewer(_grantAddress)  {
        applicationMilestones[_applicationId][_milestoneId].state = _state;
    }

    function revertTransactions(uint256 _applicationId,address _grantAddress) external onlyGrantAdminOrReviewer(_grantAddress) {
        for(uint256 i = 0;i < rejectAppPending.length;i++){
            if(rejectAppPending[i].applicationId == _applicationId && applications[_applicationId].state == ApplicationState.RejectPending){
                applications[_applicationId].state = ApplicationState.Resubmit;
                rejectAppPending[i] = rejectAppPending[rejectAppPending.length - 1];
                rejectAppPending.pop();
                emit ApplicationRejectStatusReverted(_applicationId,_grantAddress,block.timestamp,applications[_applicationId].state);
                break;
            }
        }
    }

    function executeTransactions() external onlyOwner {
        uint256 rejectAppPendingLength = rejectAppPending.length;
        for(uint256 i = 0;i < rejectAppPendingLength;i++){
            if(rejectAppPending[i].time < block.timestamp){
                applications[i].state = ApplicationState.Rejected;
                rejectAppPending[i] = rejectAppPending[rejectAppPendingLength - 1];
                rejectAppPendingLength--;
                rejectAppPending.pop();
                i--;
            }
        }
    }

    function _getPendingTransactionTimeStamp(uint256 _applicationId) internal view returns(uint256){
        for(uint256 i = 0;i < rejectAppPending.length;i++){
            if(rejectAppPending[i].applicationId == _applicationId){
                return rejectAppPending[i].time;
            }
        }
        return 1;
    }

    function getApplicationDetail(uint256 _applicationId) external view returns (Application memory,address[] memory,uint256,string memory,MilestoneStateApp[] memory,string memory) {
        Application memory application = applications[_applicationId];
        address[] memory reviewers = IGrants(application.grantAddress).getReviewers();
        string memory paymentType = IGrants(application.grantAddress).getPaymentType();
        uint256  reviewersTimeStamp;
        if (application.state == ApplicationState.ApprovePending) reviewersTimeStamp = IGrants(application.grantAddress).getPendingTransactioTimeStamp(_applicationId);
        else if (application.state == ApplicationState.RejectPending) reviewersTimeStamp = _getPendingTransactionTimeStamp(_applicationId);
        MilestoneStateApp[] memory milestoneStates = new MilestoneStateApp[](applications[_applicationId].milestonePayment.length);

        for(uint256 i = 0;i < applications[_applicationId].milestonePayment.length;i++){
            milestoneStates[i] = applicationMilestones[_applicationId][i];
        }
        string memory metadataHash = applicationsReasons[_applicationId];
        return (application,reviewers,reviewersTimeStamp,paymentType,milestoneStates,metadataHash);
    }

    function fetchMyApplications() external view returns(Application[] memory,string[] memory,string[] memory){
        string[] memory grantMetaDataHash = new string[](creatorApplicationMap[msg.sender].length);
        string[] memory workspaceDataHash = new string[](creatorApplicationMap[msg.sender].length);
        Application[] memory _applications = new Application[](creatorApplicationMap[msg.sender].length);

        for(uint256 i = 0;i < creatorApplicationMap[msg.sender].length;i++){
            string memory workspaceHash = workspaceReg.getMetaDataHash(creatorApplicationMap[msg.sender][i].workspaceId);
            workspaceDataHash[i] = workspaceHash;
            string memory grantHash = IGrants(creatorApplicationMap[msg.sender][i].grantAddress).getMetadataHash();
            grantMetaDataHash[i] = grantHash;
            _applications[i] = applications[creatorApplicationMap[msg.sender][i].id];
        }  
        return (_applications,grantMetaDataHash,workspaceDataHash);
    }
    
}