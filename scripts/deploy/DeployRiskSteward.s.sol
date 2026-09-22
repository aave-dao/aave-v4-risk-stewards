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

/// @title DeployRiskStewards
/// @author Aave Labs
/// @notice Network-agnostic deployment of a `RiskSteward`. The steward is inert until its owner
/// calls `setConfig`, which happens through governance after deployment.
library DeployRiskStewards {
  function _deployRiskSteward(address riskCouncil, address owner) internal returns (address) {
    return address(new RiskSteward(riskCouncil, owner));
  }
}

// make deploy-ledger contract=scripts/deploy/DeployRiskSteward.s.sol:DeployEthereum chain=mainnet
contract DeployEthereum is EthereumScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskSteward(
      AaveV4Ethereum.RISK_COUNCIL,
      GovernanceV3Ethereum.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployRiskSteward.s.sol:DeployAvalanche chain=avalanche
contract DeployAvalanche is AvalancheScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskSteward(
      AaveV4Avalanche.RISK_COUNCIL,
      GovernanceV3Avalanche.EXECUTOR_LVL_1
    );
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployRiskSteward.s.sol:DeployBase chain=base
contract DeployBase is BaseScript {
  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskSteward(AaveV4Base.RISK_COUNCIL, GovernanceV3Base.EXECUTOR_LVL_1);
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployRiskSteward.s.sol:DeployArc chain=arc
contract DeployArc is ArcScript {
  // Arc has no governance deployment, so the V4 Security Council executor owns the steward.
  address internal constant OWNER = MiscArc.V4_SECURITY_COUNCIL_EXECUTOR;

  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskSteward(AaveV4Arc.RISK_COUNCIL, OWNER);
    vm.stopBroadcast();
  }
}
