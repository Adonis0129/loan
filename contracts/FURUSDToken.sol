// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Interfaces/IFURUSDToken.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./abstracts/BaseContract.sol";
import "./Dependencies/CheckContract.sol";

/*
* --- Functionality added specific to the FURUSDToken ---
* 
* 1) Transfer protection: blacklist of addresses that are invalid recipients (i.e. core Liquity contracts) in external 
* transfer() and transferFrom() calls. The purpose is to protect users from losing tokens by mistakenly sending FURUSD directly to a Liquity 
* core contract, when they should rather call the right function. 
*
* 2) sendToPool() and returnFromPool(): functions callable only Liquity core contracts, which move FURUSD tokens between Liquity <-> user.
*/

contract FURUSDToken is BaseContract, ERC20Upgradeable, CheckContract, IFURUSDToken {
    using SafeMath for uint256;
    
    uint256 private _totalSupply;
    // User data for FURUSD token
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;  
    
    // --- Addresses ---
    address public immutable troveManagerAddress;
    address public immutable stabilityPoolAddress;
    address public immutable borrowerOperationsAddress;

    // --- Functions ---

    function initialize(
        address _troveManagerAddress,
        address _stabilityPoolAddress,
        address _borrowerOperationsAddress
    ) 
        public initializer
    {  
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

    function mint(address _account, uint256 _amount) external override {
        _requireCallerIsBorrowerOperations();
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external override {
        _requireCallerIsBOorTroveMorSP();
        _burn(_account, _amount);
    }

    function sendToPool(address _sender,  address _poolAddress, uint256 _amount) external override {
        _requireCallerIsStabilityPool();
        _transfer(_sender, _poolAddress, _amount);
    }

    function returnFromPool(address _poolAddress, address _receiver, uint256 _amount) external override {
        _requireCallerIsTroveMorSP();
        _transfer(_poolAddress, _receiver, _amount);
    }

    // --- External functions ---

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _requireValidRecipient(recipient);
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _requireValidRecipient(recipient);
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external override returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external override returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    // --- Internal operations ---
    // Warning: sanity checks (for sender and recipient) should have been done before calling these internal functions

    function _transfer(address sender, address recipient, uint256 amount) internal {
        assert(sender != address(0));
        assert(recipient != address(0));

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        assert(account != address(0));

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        assert(account != address(0));
        
        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        assert(owner != address(0));
        assert(spender != address(0));

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
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
