// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import 'solidity-utils/contracts/utils/ScriptUtils.sol';

import {AaveV4Ethereum} from 'aave-address-book/AaveV4Ethereum.sol';
import {AaveV4Avalanche} from 'aave-address-book/AaveV4Avalanche.sol';
import {AaveV4Base} from 'aave-address-book/AaveV4Base.sol';
import {AaveV4Arc} from 'aave-address-book/AaveV4Arc.sol';
import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {GovernanceV3Avalanche} from 'aave-address-book/GovernanceV3Avalanche.sol';
import {GovernanceV3Base} from 'aave-address-book/GovernanceV3Base.sol';
import {MiscArc} from 'aave-address-book/MiscArc.sol';

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
contract DeployEthereum is EthereumScript {
  // TODO: set the reduce council before deploying.
  address internal constant REDUCE_COUNCIL = address(0);

  function run() external {
    (, address deployer, ) = vm.readCallers();

    vm.startBroadcast();
    DeployReduceRiskStewardWrappers._deployReduceRiskStewardWrapper(
      deployer,
      REDUCE_COUNCIL,
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      RiskStewardConfigs.defaultConfig(
        AaveV4Ethereum.HUB_CONFIGURATOR,
        AaveV4Ethereum.SPOKE_CONFIGURATOR
      )
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployReduceRiskStewardWrapper.s.sol:DeployAvalanche chain=avalanche
contract DeployAvalanche is AvalancheScript {
  // TODO: set the reduce council before deploying.
  address internal constant REDUCE_COUNCIL = address(0);

  function run() external {
    (, address deployer, ) = vm.readCallers();

    vm.startBroadcast();
    DeployReduceRiskStewardWrappers._deployReduceRiskStewardWrapper(
      deployer,
      REDUCE_COUNCIL,
      GovernanceV3Avalanche.EXECUTOR_LVL_1,
      RiskStewardConfigs.defaultConfig(
        AaveV4Avalanche.HUB_CONFIGURATOR,
        AaveV4Avalanche.SPOKE_CONFIGURATOR
      )
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployReduceRiskStewardWrapper.s.sol:DeployBase chain=base
contract DeployBase is BaseScript {
  // TODO: set the reduce council before deploying.
  address internal constant REDUCE_COUNCIL = address(0);

  function run() external {
    (, address deployer, ) = vm.readCallers();

    vm.startBroadcast();
    DeployReduceRiskStewardWrappers._deployReduceRiskStewardWrapper(
      deployer,
      REDUCE_COUNCIL,
      GovernanceV3Base.EXECUTOR_LVL_1,
      RiskStewardConfigs.baseStocksConfig(
        AaveV4Base.HUB_CONFIGURATOR,
        AaveV4Base.SPOKE_CONFIGURATOR
      )
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployReduceRiskStewardWrapper.s.sol:DeployArc chain=arc
contract DeployArc is ArcScript {
  // TODO: set the reduce council before deploying.
  address internal constant REDUCE_COUNCIL = address(0);
  // Arc has no governance deployment, so the V4 Security Council executor owns the steward.
  address internal constant OWNER = MiscArc.V4_SECURITY_COUNCIL_EXECUTOR;

  function run() external {
    (, address deployer, ) = vm.readCallers();

    vm.startBroadcast();
    DeployReduceRiskStewardWrappers._deployReduceRiskStewardWrapper(
      deployer,
      REDUCE_COUNCIL,
      OWNER,
      RiskStewardConfigs.defaultConfig(AaveV4Arc.HUB_CONFIGURATOR, AaveV4Arc.SPOKE_CONFIGURATOR)
    );
    vm.stopBroadcast();
  }
}
