// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HubInstance} from 'aave-v4/hub/instances/HubInstance.sol';
import {HubConfigurator} from 'aave-v4/hub/HubConfigurator.sol';
import {AssetInterestRateStrategy} from 'aave-v4/hub/AssetInterestRateStrategy.sol';

/*
 * Scene contracts for hubImmutability.spec.
 *
 * These are pass-through wrappers, not simplifications: every function body on
 * the write path is the real aave-v4 code. They exist only to fix import
 * resolution. The aave-v4 sources import each other as 'src/...', which this
 * repo resolves with a context-scoped remapping that solc only applies to
 * transitively imported files. Listing e.g. hub/Hub.sol directly in a conf's
 * "files" therefore fails with `Source "src/..." not found`. Importing through
 * the 'aave-v4/' package prefix from here works, and the wrappers give the conf
 * a contract name it can name in "files".
 */

contract HubHarness is HubInstance {}

contract HubConfiguratorHarness is HubConfigurator {
  constructor(address authority_) HubConfigurator(authority_) {}
}

contract IRStrategyHarness is AssetInterestRateStrategy {
  constructor(address hub_) AssetInterestRateStrategy(hub_) {}
}
