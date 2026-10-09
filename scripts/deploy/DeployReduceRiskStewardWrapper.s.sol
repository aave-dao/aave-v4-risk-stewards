// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import 'solidity-utils/contracts/utils/ScriptUtils.sol';

import {AaveV4Ethereum} from 'aave-address-book/AaveV4Ethereum.sol';
import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';

import {RiskSteward} from 'src/RiskSteward.sol';
import {ReduceRiskStewardWrapper} from 'src/ReduceRiskStewardWrapper.sol';
import {IRiskSteward} from 'src/interfaces/IRiskSteward.sol';
import {RiskStewardConfigs} from 'scripts/deploy/RiskStewardConfigs.sol';

/// @title DeployReduceRiskStewardWrappers
/// @author Aave Labs
/// @notice Network-agnostic deployment of a `ReduceRiskStewardWrapper` and its dedicated
/// `RiskSteward`. The steward's council is immutable, so it is deployed against the wrapper's
/// predicted address, and the wrapper constructor reverts if the prediction is wrong. The steward
/// is deployed owned by the deployer, which sets its config then starts the ownership transfer to
/// the final owner.
library DeployReduceRiskStewardWrappers {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  function _deployReduceRiskStewardWrapper(
    address deployer,
    address reduceCouncil,
    address owner,
    IRiskSteward.Config memory config
  ) internal returns (address, address) {
    address predictedWrapper = vm.computeCreateAddress(deployer, vm.getNonce(deployer) + 1);
    RiskSteward riskSteward = new RiskSteward(predictedWrapper, deployer);
    ReduceRiskStewardWrapper wrapper = new ReduceRiskStewardWrapper(
      address(riskSteward),
      reduceCouncil
    );
    riskSteward.setConfig(config);
    riskSteward.transferOwnership(owner);
    return (address(riskSteward), address(wrapper));
  }
}

// make deploy-ledger contract=scripts/deploy/DeployReduceRiskStewardWrapper.s.sol:DeployEthereum chain=mainnet
// Specific to the Sentora market: the Sentora Risk Manager is the reduce council, the V4 Security
// Council owns the steward, and the steward uses the default config until Sentora bounds are set.
contract DeployEthereum is EthereumScript {
  address internal constant REDUCE_COUNCIL = 0x37409c868BA42B91ff7E7b64D5BC020897444fAf;

  function run() external {
    (, address deployer, ) = vm.readCallers();

    vm.startBroadcast();
    DeployReduceRiskStewardWrappers._deployReduceRiskStewardWrapper(
      deployer,
      REDUCE_COUNCIL,
      MiscEthereum.V4_SECURITY_COUNCIL,
      RiskStewardConfigs.defaultConfig(
        AaveV4Ethereum.HUB_CONFIGURATOR,
        AaveV4Ethereum.SPOKE_CONFIGURATOR
      )
    );
    vm.stopBroadcast();
  }
}
