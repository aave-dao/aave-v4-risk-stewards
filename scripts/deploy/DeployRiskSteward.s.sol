// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'solidity-utils/contracts/utils/ScriptUtils.sol';

import {GovernanceV3Ethereum} from 'aave-address-book/GovernanceV3Ethereum.sol';
import {GovernanceV3Avalanche} from 'aave-address-book/GovernanceV3Avalanche.sol';

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
  address internal constant RISK_COUNCIL = 0x47c71dFEB55Ebaa431Ae3fbF99Ea50e0D3d30fA8;

  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskSteward(RISK_COUNCIL, GovernanceV3Ethereum.EXECUTOR_LVL_1);
    vm.stopBroadcast();
  }
}

// make deploy-ledger contract=scripts/deploy/DeployRiskSteward.s.sol:DeployAvalanche chain=avalanche
contract DeployAvalanche is AvalancheScript {
  address internal constant RISK_COUNCIL = 0xCa66149425E7DC8f81276F6D80C4b486B9503D1a;

  function run() external {
    vm.startBroadcast();
    DeployRiskStewards._deployRiskSteward(RISK_COUNCIL, GovernanceV3Avalanche.EXECUTOR_LVL_1);
    vm.stopBroadcast();
  }
}
