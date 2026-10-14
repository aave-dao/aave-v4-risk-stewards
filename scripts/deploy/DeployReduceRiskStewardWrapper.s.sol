// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import 'solidity-utils/contracts/utils/ScriptUtils.sol';

import {IHubConfigurator} from 'aave-v4/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'aave-v4/spoke/interfaces/ISpokeConfigurator.sol';

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
// Specific to the Sentora market: the Sentora Emergency Risk Role is the reduce council, the V4
// Security Council owns the steward, and the configurators are the Sentora market's.
contract DeployEthereum is EthereumScript {
  address internal constant REDUCE_COUNCIL = 0x37409c868BA42B91ff7E7b64D5BC020897444fAf;
  IHubConfigurator internal constant HUB_CONFIGURATOR = IHubConfigurator(
    0xa0eD3ECC19ab04BD0e6417023824cC4930d77b70
  );
  ISpokeConfigurator internal constant SPOKE_CONFIGURATOR = ISpokeConfigurator(
    0x93bd198d4F64798157233142769159329b3cBbce
  );

  function run() external {
    (, address deployer, ) = vm.readCallers();

    vm.startBroadcast();
    DeployReduceRiskStewardWrappers._deployReduceRiskStewardWrapper(
      deployer,
      REDUCE_COUNCIL,
      MiscEthereum.V4_SECURITY_COUNCIL,
      RiskStewardConfigs.sentoraConfig(HUB_CONFIGURATOR, SPOKE_CONFIGURATOR)
    );
    vm.stopBroadcast();
  }
}
