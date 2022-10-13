// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../abstracts/BaseContract.sol";
import "../Dependencies/CheckContract.sol";
import "../Interfaces/ILockupContractFactory.sol";
import "./LockupContract.sol";

/*
* The LockupContractFactory deploys LockupContracts - its main purpose is to keep a registry of valid deployed 
* LockupContracts. 
* 
* This registry is checked by LOANToken when the Liquity deployer attempts to transfer LOAN tokens. During the first year 
* since system deployment, the Liquity deployer is only allowed to transfer LOAN to valid LockupContracts that have been 
* deployed by and recorded in the LockupContractFactory. This ensures the deployer's LOAN can't be traded or staked in the
* first year, and can only be sent to a verified LockupContract which unlocks at least one year after system deployment.
*
* LockupContracts can of course be deployed directly, but only those deployed through and recorded in the LockupContractFactory 
* will be considered "valid" by LOANToken. This is a convenient way to verify that the target address is a genuine 
* LockupContract.
*/

contract LockupContractFactory is BaseContract, ILockupContractFactory, CheckContract {
    using SafeMath for uint;

    // --- Data ---
    string constant public NAME = "LockupContractFactory";

    uint constant public SECONDS_IN_ONE_YEAR = 31536000;

    address public loanTokenAddress;
    
    mapping (address => address) public lockupContractToDeployer;

    // --- Events ---

    event LOANTokenAddressSet(address _loanTokenAddress);
    event LockupContractDeployedThroughFactory(address _lockupContractAddress, address _beneficiary, uint _unlockTime, address _deployer);

    function initialize() public initializer {
        __BaseContract_init();
    }

    // --- Functions ---

    function setLOANTokenAddress(address _loanTokenAddress) external override onlyOwner {
        checkContract(_loanTokenAddress);

        loanTokenAddress = _loanTokenAddress;
        emit LOANTokenAddressSet(_loanTokenAddress);
    }

    function deployLockupContract(address _beneficiary, uint _unlockTime) external override {
        address loanTokenAddressCached = loanTokenAddress;
        _requireLOANAddressIsSet(loanTokenAddressCached);
        LockupContract lockupContract = new LockupContract(
                                                        loanTokenAddressCached,
                                                        _beneficiary, 
                                                        _unlockTime);

        lockupContractToDeployer[address(lockupContract)] = msg.sender;
        emit LockupContractDeployedThroughFactory(address(lockupContract), _beneficiary, _unlockTime, msg.sender);
    }

    function isRegisteredLockup(address _contractAddress) public view override returns (bool) {
        return lockupContractToDeployer[_contractAddress] != address(0);
    }

    // --- 'require'  functions ---
    function _requireLOANAddressIsSet(address _loanTokenAddress) internal pure {
        require(_loanTokenAddress != address(0), "LCF: LOAN Address is not set");
    }
}
