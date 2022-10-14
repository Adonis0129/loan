// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface ILOANToken { 
   
    function sendToLOANStaking(address _sender, uint256 _amount) external;

    function getDeploymentStartTime() external view returns (uint256);

    function getLpRewardsEntitlement() external view returns (uint256);

}
