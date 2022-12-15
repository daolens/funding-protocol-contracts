// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IGrants {
    function getActive() external view returns (bool);

    function getReviewers() external view returns (address[] memory);

    function incrementApplicant() external;

    function isGrantAdminOrReviewer(address _member) external view returns (bool);

    function payApplicant(address _to,uint256 _amount) external;

    function getPaymentType() external view returns (string memory);

    function getAmount() external view returns (uint256);
}