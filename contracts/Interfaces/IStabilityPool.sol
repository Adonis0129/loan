// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IStabilityPool {

    /*
     * Initial checks:
     * - Frontend is registered or zero address
     * - Sender is not a registered frontend
     * - _amount is not zero
     * ---
     * - Triggers a LOAN issuance, based on time passed since the last issuance. The LOAN issuance is shared between *all* depositors and front ends
     * - Tags the deposit with the provided front end tag param, if it's a new deposit
     * - Sends depositor's accumulated gains (LOAN, FURFI) to depositor
     * - Sends the tagged front end's accumulated LOAN gains to the tagged front end
     * - Increases deposit and tagged front end's stake, and takes new snapshots for each.
     */
    function provideToSP(uint _amount, address _frontEndTag) external;

    /*
     * Initial checks:
     * - _amount is zero or there are no under collateralized troves left in the system
     * - User has a non zero deposit
     * ---
     * - Triggers a LOAN issuance, based on time passed since the last issuance. The LOAN issuance is shared between *all* depositors and front ends
     * - Removes the deposit's front end tag if it is a full withdrawal
     * - Sends all depositor's accumulated gains (LOAN, FURFI) to depositor
     * - Sends the tagged front end's accumulated LOAN gains to the tagged front end
     * - Decreases deposit and tagged front end's stake, and takes new snapshots for each.
     *
     * If _amount > userDeposit, the user withdraws all of their compounded deposit.
     */
    function withdrawFromSP(uint _amount) external;

    /*
     * Initial checks:
     * - User has a non zero deposit
     * - User has an open trove
     * - User has some FURFI gain
     * ---
     * - Triggers a LOAN issuance, based on time passed since the last issuance. The LOAN issuance is shared between *all* depositors and front ends
     * - Sends all depositor's LOAN gain to  depositor
     * - Sends all tagged front end's LOAN gain to the tagged front end
     * - Transfers the depositor's entire FURFI gain from the Stability Pool to the caller's trove
     * - Leaves their compounded deposit in the Stability Pool
     * - Updates snapshots for deposit and tagged front end stake
     */
    function withdrawFURFIGainToTrove(address _upperHint, address _lowerHint) external;

    /*
     * Initial checks:
     * - Frontend (sender) not already registered
     * - User (sender) has no deposit
     * - _kickbackRate is in the range [0, 100%]
     * ---
     * Front end makes a one-time selection of kickback rate upon registering
     */
    function registerFrontEnd(uint _kickbackRate) external;

    /*
     * Initial checks:
     * - Caller is TroveManager
     * ---
     * Cancels out the specified debt against the FURUSD contained in the Stability Pool (as far as possible)
     * and transfers the Trove's FURFI collateral from ActivePool to StabilityPool.
     * Only called by liquidation functions in the TroveManager.
     */
    function offset(uint _debt, uint _coll) external;

    /*
     * Returns the total amount of FURFI held by the pool, accounted in an internal variable instead of `balance`,
     * to exclude edge cases like FURFI received from a self-destruct.
     */
    function getFURFI() external view returns (uint);

    /*
     * Returns FURUSD held in the pool. Changes when users deposit/withdraw, and when Trove debt is offset.
     */
    function getTotalFURUSDDeposits() external view returns (uint);

    /*
     * Calculates the FURFI gain earned by the deposit since its last snapshots were taken.
     */
    function getDepositorFURFIGain(address _depositor) external view returns (uint);

    /*
     * Calculate the LOAN gain earned by a deposit since its last snapshots were taken.
     * If not tagged with a front end, the depositor gets a 100% cut of what their deposit earned.
     * Otherwise, their cut of the deposit's earnings is equal to the kickbackRate, set by the front end through
     * which they made their deposit.
     */
    function getDepositorLOANGain(address _depositor) external view returns (uint);

    /*
     * Return the LOAN gain earned by the front end.
     */
    function getFrontEndLOANGain(address _frontEnd) external view returns (uint);

    /*
     * Return the user's compounded deposit.
     */
    function getCompoundedFURUSDDeposit(address _depositor) external view returns (uint);

    /*
     * Return the front end's compounded stake.
     *
     * The front end's compounded stake is equal to the sum of its depositors' compounded deposits.
     */
    function getCompoundedFrontEndStake(address _frontEnd) external view returns (uint);

}
