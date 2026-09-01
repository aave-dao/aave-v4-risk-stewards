// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HubEngine} from 'aave-v4/config-engine/libraries/HubEngine.sol';
import {SpokeEngine} from 'aave-v4/config-engine/libraries/SpokeEngine.sol';
import {IAaveV4ConfigEngine} from 'aave-v4/config-engine/interfaces/IAaveV4ConfigEngine.sol';

/*
 * Scene wrapper for the engine-reachability layer (out-of-scope param
 * immutability, post-state half).
 *
 * Why enter the engine here instead of through RiskSteward: RiskSteward copies
 * its `calldata` update array into `memory` before handing it to the external
 * config-engine library (RiskSteward.sol:161-182). That calldata->memory->
 * external-library hop defeats Certora's pointer analysis ("Pointer analysis
 * for optimization failed in contract RiskSteward"), so every engine and
 * configurator call is havoc'd and the Hub is never entered -- which made the
 * P2b/P2c storage-snapshot rules vacuously pass (assertion_not_tautological).
 *
 * These wrappers call the library straight off `calldata`, so there is no
 * memory copy to confuse the analysis. Each forbidden configurator setter is
 * then summarized with a ghost-flag detector in the spec, and we prove the
 * engine only reaches that setter when the field is non-sentinel. Combined with
 * RevertConditions.spec (steward forwards only KEEP_CURRENT for forbidden fields), the
 * forbidden setter is never invoked, hence the field is immutable.
 */
contract EngineHarness {
  function runAssetIRs(IAaveV4ConfigEngine.AssetConfigUpdate[] calldata updates) external {
    HubEngine.executeHubAssetConfigUpdates(updates);
  }

  function runSpokeCaps(IAaveV4ConfigEngine.SpokeConfigUpdate[] calldata updates) external {
    HubEngine.executeHubSpokeConfigUpdates(updates);
  }

  function runReserveConfigs(IAaveV4ConfigEngine.ReserveConfigUpdate[] calldata updates) external {
    SpokeEngine.executeSpokeReserveConfigUpdates(updates);
  }

  function runDynamicReserveConfigs(
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] calldata updates
  ) external {
    SpokeEngine.executeSpokeDynamicReserveConfigUpdates(updates);
  }
}
