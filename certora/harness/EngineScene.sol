// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HubEngine} from 'aave-v4/config-engine/libraries/HubEngine.sol';
import {SpokeEngine} from 'aave-v4/config-engine/libraries/SpokeEngine.sol';
import {IAaveV4ConfigEngine} from 'aave-v4/config-engine/interfaces/IAaveV4ConfigEngine.sol';

/*
 * Scene wrapper for the engine-reachability layer (out-of-scope param
 * immutability, post-state half).
 *
 * RiskSteward copies its `calldata` update array into `memory` before handing 
 * it to the external config-engine library . That calldata->memory->
 * external-library hop breaks Certora's pointer analysis.
 *
 * These wrappers call the library straight off `calldata`, so there is no
 * memory copy to confuse the analysis.
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
