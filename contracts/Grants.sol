// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IWorkSpaceRegistry.sol";
import "./interfaces/IGrants.sol";
import "./interfaces/IGrantFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IApplicationRegistry.sol";
import "./ApplicationRegistry.sol";
import "./interfaces/IWorkSpaceRegistry.sol";

// contract GrantsRegistry is Ownable,Pausable,IGrantsRegistry{
//     struct Grant{
//         uint256  workspaceId;
//         string metadataHash;
//         bool active;
//         address creator;
//         uint256 numApplicants;
//         uint256 GrantId;
//         address[] reviewers;
//         uint256 amount;
//         address token;
//     }

//     IWorkspaceRegistry public workspaceReg;

//     mapping(uint256 => mapping(uint256 => Grant)) Grants;
//     mapping(uint256 => uint256) GrantsCount;

//     // **** Modifier ****

//     modifier onlyWorkspaceAdmin(uint256 _workspaceId) {
//         require(workspaceReg.isWorkspaceAdmin(_workspaceId, msg.sender), "Unauthorised: Not an admin");
//         _;
//     }

//     modifier onlyApplicationRegistry() {
//         require(msg.sender == address(applicationReg), "Unauthorised: Not applicationRegistry");
//         _;
//     }

//     // **** Events ****

//     event GrantCreated(uint256 indexed _workspaceId,string _metadataHash,bool _active,address _creator,uint256 _grantId,address[] reviewers,uint256 amount,address token);

//     event GrantUpdated(uint256 indexed _workspaceId, string _metadataHash, bool _active, uint256 _time,uint256 _grantId,address[] reviewers);


//     constructor(IWorkspaceRegistry _workspaceReg){
//         workspaceReg = _workspaceReg;
//     }

//     function createGrant(
//         uint256 _workspaceId,
//         string memory _metadataHash,
//         address[] memory _reviewers,
//         uint256 memory _amount,
//         address memory _token    
//     ) external onlyWorkspaceAdmin(_workspaceId) whenNotPaused {
//         GrantsCount[_workspaceId]++;
//         Grants[_workspaceId][GrantsCount[_workspaceId]] = Grant(_workspaceId,_metadataHash,true,msg.sender,0,GrantsCount[_workspaceId],_reviewers,_amount,_token);


//         emit GrantCreated(_workspaceId, _metadataHash, true,msg.sender,GrantsCount[_workspaceId],_reviewers,_amount,_token);
//     }

//     function updateGrant(string memory _metadataHash,uint256 _workspaceId,uint256 _grantId) external onlyWorkspaceAdmin(_workspaceId) whenNotPaused {
//         require(Grants[_workspaceId][_grantId].numApplicants == 0, "GrantUpdate: Applicants have already started applying");
        
//         Grant storage grant = Grants[_workspaceId][_grantId];
//         grant.metadataHash = _metadataHash;

//         emit GrantUpdated(_workspaceId, _metadataHash, grant.active, block.timestamp,_grantId,grant.reviewers);
//     }

//     function updateGrantAccessibility(
//         uint256 _workspaceId,
//         uint256 _grantId,
//         bool _canAcceptApplication
//     ) external onlyWorkspaceAdmin(_workspaceId) {
//         string memory metadataHash = Grants[_workspaceId][_grantId].metadataHash;
//         Grants[_workspaceId][_grantId].active = _canAcceptApplication;
//         emit GrantUpdated(_workspaceId, metadataHash, _canAcceptApplication, block.timestamp,_grantId);
//     }



//     function pause() external onlyOwner {
//         _pause();
//     }

//     function unpause() external onlyOwner {
//         _unpause();
//     }

//     function active(uint256 _grantId,uint256 _workspaceId) external view override returns (bool){
//         return Grants[_workspaceId][_grantId].active;
//     } 
    
//     function incrementApplicant(uint256 _grantId,uint256 _workspaceId) external override{
//         Grant storage grant = Grants[_workspaceId][_grantId];

//         grant.numApplicants++;
//     }

//     function isGrantAdminOrReviewer(uint256 _grantId,uint256 _workspaceId, address memory _member) external view override returns (bool memory){
//         bool memory isAdminOrReviewer = false;

//         Grant memory grant = Grants[_workspaceId][_grantId];

//         if(grant.creator == _member){
//             isAdminOrReviewer = true;
//         }
//         else{
//             for(uint256 i = 0;i < grant.reviewers.length;i++){
//                 if(grant.reviewers[i] == _member){
//                     isAdminOrReviewer = true;
//                 }
//             }
//         }
//         return isAdminOrReviewer;
//     }

// }

contract Grant is Ownable,Pausable,IGrants{
    
    // enum ApplicationStatus{
    //     UPFRONT,
    //     MILESTONE
    // }

    uint256 workspaceId;
    string metadataHash;
    bool active;
    address creator;
    uint256 numApplicants;
    address[] reviewers;
    uint256 amount;
    address token;
    string paymentType;
    address daolensOwner;
    address applicationReg;
    address workspaceReg;
    address grantFactory;

    struct TransactionInitiated{
        uint256 amountPay;
        address to;
        uint256 time;
        uint256 applicationId;
        bool isMilestone;
        uint256 milestoneId;
    }

    uint256 promisedAmount;
    uint256 amountSpent;
    TransactionInitiated[] pendingPayments;

    modifier onlyWorkspaceAdmin(uint256 _workspaceId) {
        require(IWorkspaceRegistry(workspaceReg).isWorkspaceAdmin(_workspaceId, msg.sender), "Unauthorised: Not an admin");
        _;
    }
    modifier checkBalance(
        IERC20 _erc20Interface,
        address _sender,
        uint256 _amount
    ) {
        require(_erc20Interface.balanceOf(_sender) > _amount, "Insufficient Balance");
        _;
    }

    modifier onlyGrantFactory() {
        require(msg.sender == grantFactory, "Unauthorised: Not being called from GrantFactory");
        _;
    }

    modifier onlyApplicationRegistry() {
        require(msg.sender == applicationReg, "Unauthorised: Not applicationRegistry");
        _;
    }

    modifier onlyDaolensOwner(){
        require(msg.sender == daolensOwner, "Unauthorised: Not DaolensOwner");
        _;
    }

    modifier onlyCreator(){
        require(creator == msg.sender,"UnAuthorized Access");
        _;
    }

    event FundsWithdrawn(address asset, uint256 amount, address recipient, uint256 time);
    event queuedTransaction(address grantAddress,uint256 amount,uint256 time,address to,uint256 applicationId);
    event executeTransaction(address grantAddress,uint256 amount,uint256 time,address to,uint256 applicationId);
    event revertTransaction(address grantAddress,uint256 amount,uint256 time,address to,uint256 applicationId);

    constructor(
        uint256 _workspaceId,
        string memory _metadataHash,
        address _workspaceReg,
        address _applicationReg,
        address _grantFactory,
        address[] memory _reviewers,
        uint256 _amount,
        address _token,
        string memory _paymentType,
        address _daolensOwner
    ){
        workspaceId = _workspaceId;
        active = true;
        metadataHash = _metadataHash;
        applicationReg = _applicationReg;
        workspaceReg = _workspaceReg;
        grantFactory = _grantFactory;
        reviewers = _reviewers;
        amount = _amount;
        token = _token;
        paymentType = _paymentType;
        daolensOwner = _daolensOwner;
    }

    function incrementApplicant() external onlyApplicationRegistry {
        numApplicants += 1;
    }

    function updateGrant(string memory _metadataHash,address[] memory _reviewers) external onlyGrantFactory {
        require(numApplicants == 0, "GrantUpdate: Applicants have already started applying");
        metadataHash = _metadataHash;
        reviewers = _reviewers;
    }

    function updateGrantAccessibility(bool _canAcceptApplication) external onlyGrantFactory {
        active = _canAcceptApplication;
    }

    function isGrantAdminOrReviewer(address _member) external view returns (bool){
        bool isAdminOrReviewer = false;

        if(creator == _member){
            isAdminOrReviewer = true;
        }
        else{
            for(uint256 i = 0;i < reviewers.length;i++){
                if(reviewers[i] == _member){
                    isAdminOrReviewer = true;
                }
            }
        }
        return isAdminOrReviewer;
    }

    function payApplicant(address _to,uint256 _amount,uint256 applicationId, bool isMilestone, uint256 milestoneId) external onlyApplicationRegistry {
        uint256 remainBalance = this.getAmount() - promisedAmount;
        if(remainBalance >= _amount){
            queueTransactions(_to, _amount,applicationId, isMilestone, milestoneId);
            promisedAmount += _amount;
        }
        else revert("InSufficient Balance");
    }

    function getActive() external view returns (bool){
        return active;
    }

    function getReviewers() external view returns (address[] memory){
        return reviewers;
    }

    function getPaymentType() external view override returns (string memory){
        return paymentType;
    }

    function getAmount() external view returns (uint256){
        return IERC20(token).balanceOf(address(this));
    }

    function getMetadataHash() external view returns (string memory){
        return metadataHash;
    }

    function getDetails() external view returns (uint256,string memory,uint256,uint256){
        uint256 balance = IERC20(token).balanceOf(address(this));
        return (numApplicants,metadataHash,balance,amountSpent);
    }

    function getAllDetails() external view returns(string memory,bool,address,uint256,address[] memory,uint256,address,string memory){
        return (metadataHash,active,creator,numApplicants,reviewers,amount,token,paymentType);
    }

    function queueTransactions(address _to,uint256 _amount,uint256 applicationId, bool isMilestone, uint256 milestoneId) internal {
        pendingPayments.push(TransactionInitiated(_amount,_to,block.timestamp + 3 days,applicationId, isMilestone, milestoneId));
        emit queuedTransaction(address(this), _amount,block.timestamp + 3 days, _to,applicationId);
    }

    function executeTransactions() external onlyDaolensOwner {
        uint256 pendingTransactionLen = pendingPayments.length;

        for(uint256 i = 0;i < pendingTransactionLen;i++){
            TransactionInitiated memory transaction = pendingPayments[i];

            if(transaction.time < block.timestamp){
                IERC20(token).transfer(transaction.to, transaction.amountPay);
                promisedAmount -= transaction.amountPay;
                amountSpent += transaction.amountPay;
                if (transaction.isMilestone)
                    IApplicationRegistry(applicationReg).updateMilestoneStateGrant(transaction.applicationId, transaction.milestoneId ,address(this), ApplicationRegistry.MilestoneState.Approved);
                else
                    IApplicationRegistry(applicationReg).updateApplicationStateGrant(transaction.applicationId,address(this), ApplicationRegistry.ApplicationState.Approved);
                emit FundsWithdrawn(token,transaction.amountPay,transaction.to,block.timestamp);
                emit executeTransaction(address(this), transaction.amountPay, block.timestamp, transaction.to,transaction.applicationId);

                pendingPayments[i] = pendingPayments[pendingTransactionLen-1];
                pendingTransactionLen--;
                pendingPayments.pop();
                i--;
            }
        }     
    }

    function revertTransactions(uint256 applicationId) external { 
        if(this.isGrantAdminOrReviewer(msg.sender)){

            for(uint256 i = 0;i < pendingPayments.length;i++){
                if(pendingPayments[i].applicationId == applicationId){
                    IApplicationRegistry(applicationReg).updateApplicationStateGrant(applicationId,address(this), ApplicationRegistry.ApplicationState.Rejected);
                    promisedAmount -= pendingPayments[i].amountPay;
                    
                    emit revertTransaction(address(this),pendingPayments[i].amountPay , block.timestamp, pendingPayments[i].to,applicationId);
                    pendingPayments[i] = pendingPayments[pendingPayments.length-1];
                    pendingPayments.pop();
                    break;
                }

            }
        }
        else revert("Not Authorized : RevertTransaction");
    }

    function getAmountSpent() external override view returns(uint256){
        return amountSpent;
    }

    function getToken() external override view returns(address){
        return token;
    }

    function getPendingTransactioTimeStamp(uint256 _applicationId) external override view returns(uint256){
        for(uint256 i = 0;i < pendingPayments.length;i++){
            if(pendingPayments[i].applicationId == _applicationId){
                return pendingPayments[i].time;
            }
        }
        return 1;
    }
}
 