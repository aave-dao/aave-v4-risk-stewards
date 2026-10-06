// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAaveV4ConfigEngine as IEngine} from 'aave-v4/config-engine/interfaces/IAaveV4ConfigEngine.sol';

import {IRiskSteward} from 'src/interfaces/IRiskSteward.sol';

/// @title IReduceRiskStewardWrapper
/// @author Aave Labs
/// @notice Reduce-only front for a dedicated `RiskSteward`: lets its council lower hub-spoke
/// add/draw caps and collateral factors, never raise them.
/// @dev The wrapper must be the `RISK_COUNCIL` of the wrapped steward. Every reduction is
/// checked against the value currently set in the market, then forwarded to the steward, which
/// still enforces its own bounds, debounces, and restrictions.
interface IReduceRiskStewardWrapper {
  /// @notice Thrown when a method gated by `onlyRiskCouncil` is called by another address.
  error InvalidCaller();

  /// @notice Thrown when a value is not strictly lower than the one currently set in the market.
  error UpdateNotReducing();

  /// @notice Thrown when a field the wrapper does not govern is changed.
  error ParamChangeNotAllowed();

  /// @notice Lowers per-spoke add/draw caps on hubs through `RiskSteward.updateHubSpokeCaps`.
  /// @dev Each cap must be KEEP_CURRENT or strictly lower than the hub's current value.
  /// @param updates The spoke config updates.
  function reduceHubSpokeCaps(IEngine.SpokeConfigUpdate[] calldata updates) external;

  /// @notice Appends a dynamic reserve config with a lower collateral factor through
  /// `RiskSteward.addDynamicReserveConfigs`.
  /// @dev `collateralFactor` must be strictly lower than the reserve's latest key, and
  /// `maxLiquidationBonus` must equal it.
  /// @param additions The dynamic reserve config additions.
  function addReducedDynamicReserveConfigs(
    IEngine.DynamicReserveConfigAddition[] calldata additions
  ) external;

  /// @notice Returns the wrapped risk steward.
  function RISK_STEWARD() external view returns (IRiskSteward);

  /// @notice Returns the council address that may call the reduce entrypoints.
  function RISK_COUNCIL() external view returns (address);
}
