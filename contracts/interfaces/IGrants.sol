// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IGrants {
    function getActive() external view returns (bool);

    function getReviewers() external view returns (address[] memory);

    function incrementApplicant() external;

    function isGrantAdminOrReviewer(address _member) external view returns (bool);

    function payApplicant(address _to,uint256 _amount,uint256 applicationId) external;

    function getPaymentType() external view returns (string memory);

    function getAmount() external view returns (uint256);

    function updateGrant(string memory _metadataHash,address[] memory _reviewers) external;
        
    function updateGrantAccessibility(bool _canAcceptApplication) external;

    function getMetadataHash() external view returns (string memory);

    function getDetails() external view returns (uint256,string memory,uint256,uint256);

    function getAmountSpent() external view returns(uint256);

    function getPendingTransactioTimeStamp(uint256 _applicationId) external view returns(uint256);

}