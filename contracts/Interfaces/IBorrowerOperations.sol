// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Common interface for the Trove Manager.
interface IBorrowerOperations {

    function openTrove(uint _maxFee, uint _FurFiAmount, uint _FURUSDAmount, address _upperHint, address _lowerHint) external;

    function addColl(uint _collDeposital, address _upperHint, address _lowerHint) external;

    function moveFURFIGainToTrove(address _user, uint _collDeposital, address _upperHint, address _lowerHint) external;

    function withdrawColl(uint _amount, address _upperHint, address _lowerHint) external;

    function withdrawFURUSD(uint _maxFee, uint _amount, address _upperHint, address _lowerHint) external;

    function repayFURUSD(uint _amount, address _upperHint, address _lowerHint) external;

    function closeTrove() external;

    function adjustTrove(uint _maxFee, uint _collDeposital, uint _collWithdrawal, uint _debtChange, bool isDebtIncrease, address _upperHint, address _lowerHint) external;

    function claimCollateral() external;

    function getCompositeDebt(uint _debt) external pure returns (uint);
}
