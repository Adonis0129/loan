// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "../abstracts/BaseContract.sol";
import "../Dependencies/CheckContract.sol";
import "../Interfaces/ILOANToken.sol";
import "../Interfaces/ILockupContractFactory.sol";

contract LOANToken is BaseContract, ERC20Upgradeable, CheckContract, ILOANToken {
    using SafeMath for uint256;

    // --- LOANToken specific data ---

    uint public constant ONE_YEAR_IN_SECONDS = 31536000;  // 60 * 60 * 24 * 365

    // uint for use with SafeMath
    uint internal _1_MILLION = 1e24;    // 1e6 * 1e18 = 1e24

    uint internal deploymentStartTime;
    address public multisigAddress;

    address public communityIssuanceAddress;
    address public loanStakingAddress;

    uint internal lpRewardsEntitlement;

    ILockupContractFactory public lockupContractFactory;

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
        super._mint(_bountyAddress, bountyEntitlement);

        uint depositorsAndFrontEndsEntitlement = _1_MILLION.mul(32); // Allocate 32 million to the algorithmic issuance schedule
        super._mint(_communityIssuanceAddress, depositorsAndFrontEndsEntitlement);

        uint _lpRewardsEntitlement = _1_MILLION.mul(4).div(3);  // Allocate 1.33 million for LP rewards
        lpRewardsEntitlement = _lpRewardsEntitlement;
        super._mint(_lpRewardsAddress, _lpRewardsEntitlement);
        
        // Allocate the remainder to the LOAN Multisig: (100 - 2 - 32 - 1.33) million = 64.66 million
        uint multisigEntitlement = _1_MILLION.mul(100)
            .sub(bountyEntitlement)
            .sub(depositorsAndFrontEndsEntitlement)
            .sub(_lpRewardsEntitlement);

        super._mint(_multisigAddress, multisigEntitlement);
    }

    // --- Events ---

    event CommunityIssuanceAddressSet(address _communityIssuanceAddress);
    event LOANStakingAddressSet(address _loanStakingAddress);
    event LockupContractFactoryAddressSet(address _lockupContractFactoryAddress);

    // --- External functions ---

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        // Restrict the multisig's transfers in first year
        if (_callerIsMultisig() && _isFirstYear()) {
            _requireRecipientIsRegisteredLC(recipient);
        }
        _requireValidRecipient(recipient);
        super._transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        if (_isFirstYear()) { _requireCallerIsNotMultisig(); }
        super._approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        if (_isFirstYear()) { _requireSenderIsNotMultisig(sender); }
        _requireValidRecipient(recipient);
        super.transferFrom(sender, recipient, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public override returns (bool) {
        if (_isFirstYear()) { _requireCallerIsNotMultisig(); }    
        super.increaseAllowance(spender,addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public override returns (bool) {
        if (_isFirstYear()) { _requireCallerIsNotMultisig(); }
        super.decreaseAllowance(spender, subtractedValue);
        return true;
    }

    function getDeploymentStartTime() external view override returns (uint256) {
        return deploymentStartTime;
    }

    function getLpRewardsEntitlement() external view override returns (uint256) {
        return lpRewardsEntitlement;
    }

    function sendToLOANStaking(address _sender, uint256 _amount) external override{
        _requireCallerIsLOANStaking();
        if (_isFirstYear()) { _requireSenderIsNotMultisig(_sender); }  // Prevent the multisig from staking LOAN
        super._transfer(_sender, loanStakingAddress, _amount);
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
