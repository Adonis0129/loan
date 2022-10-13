// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
    
interface ILockupContractFactory {
    

    function setLOANTokenAddress(address _loanTokenAddress) external;

    function deployLockupContract(address _beneficiary, uint _unlockTime) external;

    function isRegisteredLockup(address _addr) external view returns (bool);
}
