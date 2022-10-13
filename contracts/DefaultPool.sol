// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./abstracts/BaseContract.sol";
import './Interfaces/IDefaultPool.sol';
import "./Dependencies/CheckContract.sol";

/*
 * The Default Pool holds the FURFI and FURUSD debt (but not FURUSD tokens) from liquidations that have been redistributed
 * to active troves but not yet "applied", i.e. not yet recorded on a recipient active trove's struct.
 *
 * When a trove makes an operation that applies its pending FURFI and FURUSD debt, its pending FURFI and FURUSD debt is moved
 * from the Default Pool to the Active Pool.
 */
contract DefaultPool is BaseContract, CheckContract, IDefaultPool {

    using SafeMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    string constant public NAME = "DefaultPool";

    address public troveManagerAddress;
    address public activePoolAddress;
    uint256 internal FURFI;  // deposited FURFI tracker
    uint256 internal FURUSDDebt;  // debt
    address public furFiAddress;

    // --- Events ---
    event DefaultPoolFURUSDDebtUpdated(uint _LUSDDebt);
    event DefaultPoolFURFIBalanceUpdated(uint _FURFI);
    event FURFISent(address _to, uint _amount);

    function initialize() public initializer {
        __BaseContract_init();
    }

    // --- Dependency setters ---

    function setAddresses(
        address _troveManagerAddress,
        address _activePoolAddress,
        address _furFiAddress
    )
        external
        onlyOwner
    {
        checkContract(_troveManagerAddress);
        checkContract(_activePoolAddress);
        checkContract(_furFiAddress);

        troveManagerAddress = _troveManagerAddress;
        activePoolAddress = _activePoolAddress;
        furFiAddress = _furFiAddress;
    }

    // --- Getters for public variables. Required by IPool interface ---

    /*
    * Returns the FURFI state variable.
    *
    * Not necessarily equal to the the contract's raw FURFI balance - ether can be forcibly sent to contracts.
    */
    function getFURFI() external view override returns (uint) {
        return FURFI;
    }

    function getFURUSDDebt() external view override returns (uint) {
        return FURUSDDebt;
    }

    // --- Pool functionality ---

    function sendFURFIToActivePool(uint _amount) external override {
        _requireCallerIsTroveManager();
        address activePool = activePoolAddress; // cache to save an SLOAD
        FURFI = FURFI.sub(_amount);
        emit DefaultPoolFURFIBalanceUpdated(FURFI);
        emit FURFISent(activePool, _amount);

        IERC20Upgradeable FurFiToken = IERC20Upgradeable(furFiAddress);
        FurFiToken.safeTransfer(activePool, _amount);
    }

    //called by only ActivePool after send FURFI
    function receiveFURFI(uint _amount) external override {
        _requireCallerIsActivePool();
        FURFI = FURFI.add(_amount);
        emit DefaultPoolFURFIBalanceUpdated(FURFI);
    }

    function increaseFURUSDDebt(uint _amount) external override {
        _requireCallerIsTroveManager();
        FURUSDDebt = FURUSDDebt.add(_amount);
        emit DefaultPoolFURUSDDebtUpdated(FURUSDDebt);
    }

    function decreaseFURUSDDebt(uint _amount) external override {
        _requireCallerIsTroveManager();
        FURUSDDebt = FURUSDDebt.sub(_amount);
        emit DefaultPoolFURUSDDebtUpdated(FURUSDDebt);
    }

    // --- 'require' functions ---

    function _requireCallerIsActivePool() internal view {
        require(msg.sender == activePoolAddress, "DefaultPool: Caller is not the ActivePool");
    }

    function _requireCallerIsTroveManager() internal view {
        require(msg.sender == troveManagerAddress, "DefaultPool: Caller is not the TroveManager");
    }

}
