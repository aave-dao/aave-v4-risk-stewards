// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
import {IRiskSteward} from 'src/interfaces/IRiskSteward.sol';
import {RiskStewardConfigs} from 'scripts/deploy/RiskStewardConfigs.sol';

/// @title DeployRiskStewards
/// @author Aave Labs
/// @notice Network-agnostic deployment of a `RiskSteward`. The steward is deployed owned by the
/// deployer, which sets its config then starts the ownership transfer to the final owner.
/// `Ownable2Step` leaves the final owner as pending owner until it calls `acceptOwnership`.
library DeployRiskStewards {
  function _deployRiskSteward(
    address deployer,
    address riskCouncil,
    address owner,
    IRiskSteward.Config memory config
  ) internal returns (address) {
    RiskSteward riskSteward = new RiskSteward(riskCouncil, deployer);
    riskSteward.setConfig(config);
    riskSteward.transferOwnership(owner);
    return address(riskSteward);
  }
}

// make deploy-ledger contract=scripts/deploy/DeployRiskSteward.s.sol:DeployEthereum chain=mainnet
contract DeployEthereum is EthereumScript {
  function run() external {
    (, address deployer, ) = vm.readCallers();

    vm.startBroadcast();
    DeployRiskStewards._deployRiskSteward(
      deployer,
      AaveV4Ethereum.RISK_COUNCIL,
      GovernanceV3Ethereum.EXECUTOR_LVL_1,
      RiskStewardConfigs.defaultConfig(
        AaveV4Ethereum.HUB_CONFIGURATOR,
        AaveV4Ethereum.SPOKE_CONFIGURATOR
      )
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployRiskSteward.s.sol:DeployAvalanche chain=avalanche
contract DeployAvalanche is AvalancheScript {
  function run() external {
    (, address deployer, ) = vm.readCallers();

    vm.startBroadcast();
    DeployRiskStewards._deployRiskSteward(
      deployer,
      AaveV4Avalanche.RISK_COUNCIL,
      GovernanceV3Avalanche.EXECUTOR_LVL_1,
      RiskStewardConfigs.defaultConfig(
        AaveV4Avalanche.HUB_CONFIGURATOR,
        AaveV4Avalanche.SPOKE_CONFIGURATOR
      )
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployRiskSteward.s.sol:DeployBase chain=base
contract DeployBase is BaseScript {
  function run() external {
    (, address deployer, ) = vm.readCallers();

    vm.startBroadcast();
    DeployRiskStewards._deployRiskSteward(
      deployer,
      AaveV4Base.RISK_COUNCIL,
      GovernanceV3Base.EXECUTOR_LVL_1,
      RiskStewardConfigs.baseStocksConfig(
        AaveV4Base.HUB_CONFIGURATOR,
        AaveV4Base.SPOKE_CONFIGURATOR
      )
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployRiskSteward.s.sol:DeployArc chain=arc
contract DeployArc is ArcScript {
  // Arc has no governance deployment, so the V4 Security Council executor owns the steward.
  address internal constant OWNER = MiscArc.V4_SECURITY_COUNCIL_EXECUTOR;

  function run() external {
    (, address deployer, ) = vm.readCallers();

    vm.startBroadcast();
    DeployRiskStewards._deployRiskSteward(
      deployer,
      AaveV4Arc.RISK_COUNCIL,
      OWNER,
      RiskStewardConfigs.defaultConfig(AaveV4Arc.HUB_CONFIGURATOR, AaveV4Arc.SPOKE_CONFIGURATOR)
    );
    vm.stopBroadcast();
  }
}
