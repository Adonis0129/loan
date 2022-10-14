// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Interfaces/IFURUSDToken.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./abstracts/BaseContract.sol";
import "./Dependencies/CheckContract.sol";


contract FURUSDToken is BaseContract, CheckContract, ERC20Upgradeable {
    using SafeMath for uint256;
    
    // --- Addresses ---
    address public troveManagerAddress;
    address public stabilityPoolAddress;
    address public borrowerOperationsAddress;

    // --- Functions ---

    function initialize(
        address _troveManagerAddress,
        address _stabilityPoolAddress,
        address _borrowerOperationsAddress
    ) 
        public initializer
    {  
        __BaseContract_init();
        __ERC20_init("FURUSD", "$FURUSD");

        checkContract(_troveManagerAddress);
        checkContract(_stabilityPoolAddress);
        checkContract(_borrowerOperationsAddress);

        troveManagerAddress = _troveManagerAddress;
        stabilityPoolAddress = _stabilityPoolAddress;
        borrowerOperationsAddress = _borrowerOperationsAddress;        
        
    }

    // --- Events ---
    event FURUSDTokenBalanceUpdated(address _user, uint _amount);

    // --- Functions for intra-Liquity calls ---

    function mint(address _account, uint256 _amount) external {
        _requireCallerIsBorrowerOperations();
        super._mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external  {
        _requireCallerIsBOorTroveMorSP();
        super._burn(_account, _amount);
    }

    function sendToPool(address _sender,  address _poolAddress, uint256 _amount) external {
        _requireCallerIsStabilityPool();
        super._transfer(_sender, _poolAddress, _amount);
    }

    function returnFromPool(address _poolAddress, address _receiver, uint256 _amount) external {
        _requireCallerIsTroveMorSP();
        super._transfer(_poolAddress, _receiver, _amount);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _requireValidRecipient(recipient);
        super._transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _requireValidRecipient(recipient);
        _transfer(sender, recipient, amount);
        super._approve(sender, msg.sender, amount);
        return true;
    }

    // --- 'require' functions ---

    function _requireValidRecipient(address _recipient) internal view {
        require(
            _recipient != address(0) && 
            _recipient != address(this),
            "FURUSD: Cannot transfer tokens directly to the FURUSD token contract or the zero address"
        );
        require(
            _recipient != stabilityPoolAddress && 
            _recipient != troveManagerAddress && 
            _recipient != borrowerOperationsAddress, 
            "FURUSD: Cannot transfer tokens directly to the StabilityPool, TroveManager or BorrowerOps"
        );
    }

    function _requireCallerIsBorrowerOperations() internal view {
        require(msg.sender == borrowerOperationsAddress, "FURUSDToken: Caller is not BorrowerOperations");
    }

    function _requireCallerIsBOorTroveMorSP() internal view {
        require(
            msg.sender == borrowerOperationsAddress ||
            msg.sender == troveManagerAddress ||
            msg.sender == stabilityPoolAddress,
            "FURUSD: Caller is neither BorrowerOperations nor TroveManager nor StabilityPool"
        );
    }

    function _requireCallerIsStabilityPool() internal view {
        require(msg.sender == stabilityPoolAddress, "FURUSD: Caller is not the StabilityPool");
    }

    function _requireCallerIsTroveMorSP() internal view {
        require(
            msg.sender == troveManagerAddress || msg.sender == stabilityPoolAddress,
            "FURUSD: Caller is neither TroveManager nor StabilityPool");
    }

}
