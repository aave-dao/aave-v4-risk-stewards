// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Certora scene aggregator for the P3b/P3c full-scene proofs.
//
// Listed as a top-level `files` entry so the four write-path contracts are
// compiled (transitively) from the root project via the global `aave-v4/`
// remapping. This reproduces the same compilation context that already lets
// RiskSteward.sol resolve the aave-v4 `src/...` bare imports, avoiding the
// separate-compilation-unit remapping failure.

import {HubInstance} from 'aave-v4/hub/instances/HubInstance.sol';
import {SpokeInstance} from 'aave-v4/spoke/instances/SpokeInstance.sol';
import {HubConfigurator} from 'aave-v4/hub/HubConfigurator.sol';
import {SpokeConfigurator} from 'aave-v4/spoke/SpokeConfigurator.sol';
import {AssetInterestRateStrategy} from 'aave-v4/hub/AssetInterestRateStrategy.sol';

// Thin wrappers so the four write-path contracts become first-class scene
// contracts (a bare `import` only pulls the type, not a scene entry). All real
// logic is inherited; the constructors just forward the parents' args.
contract HubHarness is HubInstance {}

contract SpokeHarness is SpokeInstance {
  constructor(address oracle_, uint16 maxUserReservesLimit_)
    SpokeInstance(oracle_, maxUserReservesLimit_) {}

  /// @dev Same slot `Spoke.addDynamicReserveConfig` reads and bumps, and the same one
  /// `RiskSteward._validateAddDynamicReserveConfigs` anchors against. Exposed as a bare
  /// uint32 so specs need not receive the whole `ISpoke.Reserve` struct, which embeds the
  /// `ReserveFlags` user-defined value type.
  function latestDynamicConfigKey(uint256 reserveId) external view returns (uint32) {
    return _reserves[reserveId].dynamicConfigKey;
  }
}

contract HubConfiguratorHarness is HubConfigurator {
  constructor(address authority_) HubConfigurator(authority_) {}
}

contract SpokeConfiguratorHarness is SpokeConfigurator {
  constructor(address authority_) SpokeConfigurator(authority_) {}
}

// Read-back target for the updateHubAssetIRs fidelity rules: the interest-rate
// data lives in the strategy, not in the Hub. `_interestRateData` is internal,
// so the rules read it through the real `getInterestRateData` getter.
contract AssetInterestRateStrategyHarness is AssetInterestRateStrategy {
  constructor(address hub_) AssetInterestRateStrategy(hub_) {}
}

// Name-matches the file so Certora's file->contract resolution is satisfied.
contract Scene {}
