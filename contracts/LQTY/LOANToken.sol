// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "../abstracts/BaseContract.sol";
import "../Dependencies/CheckContract.sol";
import "../Interfaces/ILOANToken.sol";
import "../Interfaces/ILockupContractFactory.sol";

/*
*  --- Functionality added specific to the LOANToken ---
* 
* 1) Transfer protection: blacklist of addresses that are invalid recipients (i.e. core Liquity contracts) in external 
* transfer() and transferFrom() calls. The purpose is to protect users from losing tokens by mistakenly sending LOAN directly to a Liquity
* core contract, when they should rather call the right function.
*
* 2) sendToLOANStaking(): callable only by Liquity core contracts, which move LOAN tokens from user -> LOANStaking contract.
*
* 3) Supply hard-capped at 100 million
*
* 4) CommunityIssuance and LockupContractFactory addresses are set at deployment
*
* 5) The bug bounties / hackathons allocation of 2 million tokens is minted at deployment to an EOA

* 6) 32 million tokens are minted at deployment to the CommunityIssuance contract
*
* 7) The LP rewards allocation of (1 + 1/3) million tokens is minted at deployent to a Staking contract
*
* 8) (64 + 2/3) million tokens are minted at deployment to the Liquity multisig
*
* 9) Until one year from deployment:
* -Liquity multisig may only transfer() tokens to LockupContracts that have been deployed via & registered in the 
*  LockupContractFactory 
* -approve(), increaseAllowance(), decreaseAllowance() revert when called by the multisig
* -transferFrom() reverts when the multisig is the sender
* -sendToLOANStaking() reverts when the multisig is the sender, blocking the multisig from staking its LOAN.
* 
* After one year has passed since deployment of the LOANToken, the restrictions on multisig operations are lifted
* and the multisig has the same rights as any other address.
*/

contract LOANToken is BaseContract, ERC20Upgradeable, CheckContract, ILOANToken {
    using SafeMath for uint256;

    uint private _totalSupply;
    // User data for LOAN token
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    // --- LOANToken specific data ---

    uint public constant ONE_YEAR_IN_SECONDS = 31536000;  // 60 * 60 * 24 * 365

    // uint for use with SafeMath
    uint internal _1_MILLION = 1e24;    // 1e6 * 1e18 = 1e24

    uint internal immutable deploymentStartTime;
    address public immutable multisigAddress;

    address public immutable communityIssuanceAddress;
    address public immutable loanStakingAddress;

    uint internal immutable lpRewardsEntitlement;

    ILockupContractFactory public immutable lockupContractFactory;

    function initialize(
        address _communityIssuanceAddress, 
        address _loanStakingAddress,
        address _lockupFactoryAddress,
        address _bountyAddress,
        address _lpRewardsAddress,
        address _multisigAddress
    ) 
        public initializer 
    {
        __BaseContract_init();
        __ERC20_init("LOAN", "$LOAN");

        checkContract(_communityIssuanceAddress);
        checkContract(_loanStakingAddress);
        checkContract(_lockupFactoryAddress);

        multisigAddress = _multisigAddress;
        deploymentStartTime  = block.timestamp;
        
        communityIssuanceAddress = _communityIssuanceAddress;
        loanStakingAddress = _loanStakingAddress;
        lockupContractFactory = ILockupContractFactory(_lockupFactoryAddress);
     
        // --- Initial LOAN allocations ---
     
        uint bountyEntitlement = _1_MILLION.mul(2); // Allocate 2 million for bounties/hackathons
        _mint(_bountyAddress, bountyEntitlement);

        uint depositorsAndFrontEndsEntitlement = _1_MILLION.mul(32); // Allocate 32 million to the algorithmic issuance schedule
        _mint(_communityIssuanceAddress, depositorsAndFrontEndsEntitlement);

        uint _lpRewardsEntitlement = _1_MILLION.mul(4).div(3);  // Allocate 1.33 million for LP rewards
        lpRewardsEntitlement = _lpRewardsEntitlement;
        _mint(_lpRewardsAddress, _lpRewardsEntitlement);
        
        // Allocate the remainder to the LOAN Multisig: (100 - 2 - 32 - 1.33) million = 64.66 million
        uint multisigEntitlement = _1_MILLION.mul(100)
            .sub(bountyEntitlement)
            .sub(depositorsAndFrontEndsEntitlement)
            .sub(_lpRewardsEntitlement);

        _mint(_multisigAddress, multisigEntitlement);
    }

    // --- Events ---

    event CommunityIssuanceAddressSet(address _communityIssuanceAddress);
    event LOANStakingAddressSet(address _loanStakingAddress);
    event LockupContractFactoryAddressSet(address _lockupContractFactoryAddress);

    // --- External functions ---

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        // Restrict the multisig's transfers in first year
        if (_callerIsMultisig() && _isFirstYear()) {
            _requireRecipientIsRegisteredLC(recipient);
        }

        _requireValidRecipient(recipient);

        // Otherwise, standard transfer functionality
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        if (_isFirstYear()) { _requireCallerIsNotMultisig(); }

        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if (_isFirstYear()) { _requireSenderIsNotMultisig(sender); }
        
        _requireValidRecipient(recipient);

        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external override returns (bool) {
        if (_isFirstYear()) { _requireCallerIsNotMultisig(); }
        
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external override returns (bool) {
        if (_isFirstYear()) { _requireCallerIsNotMultisig(); }
        
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function getDeploymentStartTime() external view override returns (uint256) {
        return deploymentStartTime;
    }

    function getLpRewardsEntitlement() external view override returns (uint256) {
        return lpRewardsEntitlement;
    }

    function sendToLOANStaking(address _sender, uint256 _amount) external override {
        _requireCallerIsLOANStaking();
        if (_isFirstYear()) { _requireSenderIsNotMultisig(_sender); }  // Prevent the multisig from staking LOAN
        _transfer(_sender, loanStakingAddress, _amount);
    }

    // --- Internal operations ---

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    // --- Helper functions ---

    function _callerIsMultisig() internal view returns (bool) {
        return (msg.sender == multisigAddress);
    }

    function _isFirstYear() internal view returns (bool) {
        return (block.timestamp.sub(deploymentStartTime) < ONE_YEAR_IN_SECONDS);
    }

    // --- 'require' functions ---
    
    function _requireValidRecipient(address _recipient) internal view {
        require(
            _recipient != address(0) && 
            _recipient != address(this),
            "LOAN: Cannot transfer tokens directly to the LOAN token contract or the zero address"
        );
        require(
            _recipient != communityIssuanceAddress &&
            _recipient != loanStakingAddress,
            "LOAN: Cannot transfer tokens directly to the community issuance or staking contract"
        );
    }

    function _requireRecipientIsRegisteredLC(address _recipient) internal view {
        require(lockupContractFactory.isRegisteredLockup(_recipient), 
        "LOANToken: recipient must be a LockupContract registered in the Factory");
    }

    function _requireSenderIsNotMultisig(address _sender) internal view {
        require(_sender != multisigAddress, "LOANToken: sender must not be the multisig");
    }

    function _requireCallerIsNotMultisig() internal view {
        require(!_callerIsMultisig(), "LOANToken: caller must not be the multisig");
    }

    function _requireCallerIsLOANStaking() internal view {
         require(msg.sender == loanStakingAddress, "LOANToken: caller must be the LOANStaking contract");
    }

}
