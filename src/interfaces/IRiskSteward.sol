// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAaveV4ConfigEngine as IEngine} from 'aave-v4/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IHubConfigurator} from 'aave-v4/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'aave-v4/spoke/interfaces/ISpokeConfigurator.sol';

/// @title IRiskSteward
/// @author Aave Labs
/// @notice Manages risk params on Aave v4 Hubs and Spokes within owner-configured bounds.
/// @dev A single steward instance is configured by the owner for Hubs and Spokes,
/// each registered with its own per-param `minDelay` + `maxPercentChange` bound. The risk
/// council is the only address allowed to call the update entrypoints; the owner controls
/// configs, registrations, and restrictions.
interface IRiskSteward {
  /// @notice Thrown when a method gated by `onlyRiskCouncil` is called by another address.
  error InvalidCaller();

  /// @notice Thrown when a single param update is attempted before its `minDelay` elapses.
  error DebounceNotRespected();

  /// @notice Thrown when a param update exceeds the configured `maxPercentChange`.
  error UpdateNotInRange();

  /// @notice Thrown when an update array is empty.
  error NoZeroUpdates();

  /// @notice Thrown when a field outside the steward's scope is set to a non-sentinel value.
  error ParamChangeNotAllowed();

  /// @notice Thrown when a numeric param is being updated to zero.
  error InvalidUpdateToZero();

  /// @notice Thrown when an update targets a hub the owner has not registered.
  error HubNotRegistered();

  /// @notice Thrown when an update targets a spoke the owner has not registered.
  error SpokeNotRegistered();

  /// @notice Thrown when an update targets a hub the owner has restricted.
  error HubIsRestricted();

  /// @notice Thrown when an update targets a spoke the owner has restricted.
  error SpokeIsRestricted();

  /// @notice Thrown when an update targets a (spoke, hub) tuple the owner has restricted.
  error SpokeHubIsRestricted();

  /// @notice Thrown when an update targets a reserve the owner has restricted.
  error ReserveIsRestricted();

  /// @notice Thrown when adding a dynamic reserve config on a reserve that has no prior key.
  error NoExistingDynamicConfig();

  /// @notice Thrown when an update entry carries a `hubConfigurator` / `spokeConfigurator` that
  /// differs from the configurator registered for the targeted hub / spoke.
  error ConfiguratorMismatch();

  /// @notice Thrown when a `RiskParamConfig` field is submitted with an `isChangeRelative` value
  /// that does not match the param's expected mode (e.g. an IR field must be absolute, a cap must
  /// be relative). Enforced at `setHubConfig` / `setSpokeConfig` time.
  error InvalidParamConfig();

  /// @notice Emitted when the owner sets the risk config for a hub.
  /// @param hub The address of the hub.
  /// @param config The new hub config.
  event HubConfigSet(address indexed hub, HubConfig config);

  /// @notice Emitted when the owner sets the risk config for a spoke.
  /// @param spoke The address of the spoke.
  /// @param config The new spoke config.
  event SpokeConfigSet(address indexed spoke, SpokeConfig config);

  /// @notice Emitted when the owner flips the restriction flag for a hub.
  /// @param hub The address of the hub.
  /// @param isRestricted True if the hub is restricted, false otherwise.
  event HubRestrictionUpdated(address indexed hub, bool isRestricted);

  /// @notice Emitted when the owner flips the restriction flag for a spoke.
  /// @param spoke The address of the spoke.
  /// @param isRestricted True if the spoke is restricted, false otherwise.
  event SpokeRestrictionUpdated(address indexed spoke, bool isRestricted);

  /// @notice Emitted when the owner flips the restriction flag for a (spoke, hub) tuple.
  /// @param spoke The address of the spoke.
  /// @param hub The address of the hub.
  /// @param isRestricted True if the tuple is restricted, false otherwise.
  event SpokeHubRestrictionUpdated(address indexed spoke, address indexed hub, bool isRestricted);

  /// @notice Emitted when the owner flips the restriction flag for a (spoke, hub, asset) reserve.
  /// @param spoke The address of the spoke.
  /// @param hub The address of the hub.
  /// @param asset The address of the underlying asset.
  /// @param isRestricted True if the reserve is restricted, false otherwise.
  event ReserveRestrictionUpdated(
    address indexed spoke,
    address indexed hub,
    address indexed asset,
    bool isRestricted
  );

  /// @notice Per-param risk bound used by `_validateParamUpdate`.
  /// @dev minDelay The minimum number of seconds between successive updates of the param.
  /// @dev maxPercentChange The maximum allowed change per update — interpreted as relative BPS
  /// when `isChangeRelative` is true, otherwise as an absolute delta in the param's native units.
  /// @dev isChangeRelative True if `maxPercentChange` is relative BPS-of-current; false for an
  /// absolute delta. The setter enforces the expected mode per field so this value is effectively
  /// immutable per-field by compile-time invariant.
  struct RiskParamConfig {
    uint40 minDelay;
    uint208 maxPercentChange;
    bool isChangeRelative;
  }

  /// @notice Risk bounds for hub-asset interest rate params.
  /// @dev optimalUsageRatio Bound for `InterestRateData.optimalUsageRatio` (absolute, BPS).
  /// @dev baseDrawnRate Bound for `InterestRateData.baseDrawnRate` (absolute, BPS).
  /// @dev rateGrowthBeforeOptimal Bound for `InterestRateData.rateGrowthBeforeOptimal` (absolute, BPS).
  /// @dev rateGrowthAfterOptimal Bound for `InterestRateData.rateGrowthAfterOptimal` (absolute, BPS).
  struct HubRateConfig {
    RiskParamConfig optimalUsageRatio;
    RiskParamConfig baseDrawnRate;
    RiskParamConfig rateGrowthBeforeOptimal;
    RiskParamConfig rateGrowthAfterOptimal;
  }

  /// @notice Risk bounds for per-(hub, spoke, asset) caps.
  /// @dev addCap Bound for `SpokeConfig.addCap` (relative).
  /// @dev drawCap Bound for `SpokeConfig.drawCap` (relative).
  struct HubCapConfig {
    RiskParamConfig addCap;
    RiskParamConfig drawCap;
  }

  /// @notice Owner-set risk config for a hub. Setting `hubConfigurator` to the zero address
  /// removes the hub. The struct also doubles as the registration record.
  /// @dev hubConfigurator The HubConfigurator that owns the hub.
  /// @dev rate Bounds for the four hub-asset IR params.
  /// @dev cap Bounds for the per-spoke addCap / drawCap on this hub.
  struct HubConfig {
    IHubConfigurator hubConfigurator;
    HubRateConfig rate;
    HubCapConfig cap;
  }

  /// @notice Risk bounds for spoke dynamic reserve params (shared across all dynamicConfigKeys).
  /// @dev collateralFactor Bound for `DynamicReserveConfig.collateralFactor` (absolute, BPS).
  /// @dev maxLiquidationBonus Bound for `DynamicReserveConfig.maxLiquidationBonus` (absolute, BPS).
  struct SpokeDynamicConfig {
    RiskParamConfig collateralFactor;
    RiskParamConfig maxLiquidationBonus;
  }

  /// @notice Risk bounds for the spoke-global LiquidationConfig.
  /// @dev targetHealthFactor Bound for `LiquidationConfig.targetHealthFactor` (relative, WAD).
  /// @dev healthFactorForMaxBonus Bound for `LiquidationConfig.healthFactorForMaxBonus` (relative, WAD).
  /// @dev liquidationBonusFactor Bound for `LiquidationConfig.liquidationBonusFactor` (absolute, BPS).
  struct SpokeLiquidationConfig {
    RiskParamConfig targetHealthFactor;
    RiskParamConfig healthFactorForMaxBonus;
    RiskParamConfig liquidationBonusFactor;
  }

  /// @notice Owner-set risk config for a spoke. Setting `spokeConfigurator` to the zero address
  /// removes the spoke. The struct also doubles as the registration record.
  /// @dev spokeConfigurator The SpokeConfigurator that owns the spoke.
  /// @dev collateralRisk Bound for `ReserveConfig.collateralRisk` (relative).
  /// @dev dynamicUpdate Bounds applied by `updateDynamicReserveConfigs` (mutates an existing key
  /// users may be positioned in — typically the stricter of the two).
  /// @dev dynamicAdd Bounds applied by `addDynamicReserveConfigs` (appends a brand-new key with
  /// no users yet — typically looser; allows larger leaps from the latest existing key).
  /// @dev liquidation Bounds for spoke-global liquidation params.
  struct SpokeConfig {
    ISpokeConfigurator spokeConfigurator;
    RiskParamConfig collateralRisk;
    SpokeDynamicConfig dynamicUpdate;
    SpokeDynamicConfig dynamicAdd;
    SpokeLiquidationConfig liquidation;
  }

  /// @notice Per-param debounce timestamps for hub-asset interest-rate updates.
  /// @dev optimalUsageRatio The last update timestamp for `optimalUsageRatio`.
  /// @dev baseDrawnRate The last update timestamp for `baseDrawnRate`.
  /// @dev rateGrowthBeforeOptimal The last update timestamp for `rateGrowthBeforeOptimal`.
  /// @dev rateGrowthAfterOptimal The last update timestamp for `rateGrowthAfterOptimal`.
  struct HubAssetDebounce {
    uint40 optimalUsageRatio;
    uint40 baseDrawnRate;
    uint40 rateGrowthBeforeOptimal;
    uint40 rateGrowthAfterOptimal;
  }

  /// @notice Per-param debounce timestamps for hub-spoke cap updates.
  /// @dev addCap The last update timestamp for `addCap`.
  /// @dev drawCap The last update timestamp for `drawCap`.
  struct HubSpokeAssetDebounce {
    uint40 addCap;
    uint40 drawCap;
  }

  /// @notice Per-param debounce timestamps for spoke reserve updates.
  /// @dev collateralRisk The last update timestamp for `collateralRisk`.
  struct SpokeReserveDebounce {
    uint40 collateralRisk;
  }

  /// @notice Per-param debounce timestamps for spoke dynamic reserve updates at a given key.
  /// @dev collateralFactor The last update timestamp for `collateralFactor`.
  /// @dev maxLiquidationBonus The last update timestamp for `maxLiquidationBonus`.
  struct SpokeDynamicDebounce {
    uint40 collateralFactor;
    uint40 maxLiquidationBonus;
  }

  /// @notice Per-param debounce timestamps for the spoke-global liquidation config.
  /// @dev targetHealthFactor The last update timestamp for `targetHealthFactor`.
  /// @dev healthFactorForMaxBonus The last update timestamp for `healthFactorForMaxBonus`.
  /// @dev liquidationBonusFactor The last update timestamp for `liquidationBonusFactor`.
  struct SpokeLiquidationDebounce {
    uint40 targetHealthFactor;
    uint40 healthFactorForMaxBonus;
    uint40 liquidationBonusFactor;
  }

  /// @notice Internal input bundle for `_validateParamUpdate`.
  /// @dev currentValue The on-chain current value of the param.
  /// @dev newValue The proposed new value (may equal `KEEP_CURRENT` to skip).
  /// @dev lastUpdated The timestamp the steward last bumped this timelock entry.
  /// @dev riskConfig The bound governing this param.
  struct ParamUpdateValidationInput {
    uint256 currentValue;
    uint256 newValue;
    uint40 lastUpdated;
    RiskParamConfig riskConfig;
  }

  /// @notice Updates the IR data on hub assets via `HubEngine.executeHubAssetConfigUpdates`.
  /// @dev `irStrategy`, `feeReceiver`, `reinvestmentController`, and `liquidityFee` MUST carry
  /// their KEEP_CURRENT sentinels — the steward refuses to change them.
  /// @param updates The asset config updates.
  function updateHubAssetIRs(IEngine.AssetConfigUpdate[] calldata updates) external;

  /// @notice Updates the per-spoke add/draw caps on hubs via `HubEngine.executeHubSpokeConfigUpdates`.
  /// @dev `riskPremiumThreshold`, `active`, and `halted` MUST carry KEEP_CURRENT.
  /// @param updates The spoke config updates.
  function updateHubSpokeCaps(IEngine.SpokeConfigUpdate[] calldata updates) external;

  /// @notice Updates `collateralRisk` on spoke reserves via `SpokeEngine.executeSpokeReserveConfigUpdates`.
  /// @dev `priceSource`, `paused`, `frozen`, `borrowable`, and `receiveSharesEnabled` MUST carry KEEP_CURRENT.
  /// @param updates The reserve config updates.
  function updateReserveConfigs(IEngine.ReserveConfigUpdate[] calldata updates) external;

  /// @notice Updates a specific dynamicConfigKey's `collateralFactor` / `maxLiquidationBonus`.
  /// @dev `liquidationFee` MUST carry KEEP_CURRENT.
  /// @param updates The dynamic reserve config updates.
  function updateDynamicReserveConfigs(
    IEngine.DynamicReserveConfigUpdate[] calldata updates
  ) external;

  /// @notice Appends a new dynamic reserve config (new key). Values are validated against the
  /// most recent existing key for the reserve. `liquidationFee` MUST equal the previous-key value.
  /// @param additions The dynamic reserve config additions.
  function addDynamicReserveConfigs(
    IEngine.DynamicReserveConfigAddition[] calldata additions
  ) external;

  /// @notice Updates the spoke-global LiquidationConfig via `SpokeEngine.executeSpokeLiquidationConfigUpdates`.
  /// @param updates The liquidation config updates.
  function updateSpokeLiquidationConfigs(
    IEngine.LiquidationConfigUpdate[] calldata updates
  ) external;

  /// @notice Owner: register or update the risk config for a hub.
  /// @dev Setting all-zero (in particular `hubConfigurator == address(0)`) unregisters the hub.
  /// @param hub The address of the hub.
  /// @param config The new hub config.
  function setHubConfig(address hub, HubConfig calldata config) external;

  /// @notice Owner: register or update the risk config for a spoke.
  /// @param spoke The address of the spoke.
  /// @param config The new spoke config.
  function setSpokeConfig(address spoke, SpokeConfig calldata config) external;

  /// @notice Owner: remove a hub's config entirely. Equivalent to `setHubConfig(hub, zero)`.
  /// @param hub The address of the hub.
  function removeHubConfig(address hub) external;

  /// @notice Owner: remove a spoke's config entirely. Equivalent to `setSpokeConfig(spoke, zero)`.
  /// @param spoke The address of the spoke.
  function removeSpokeConfig(address spoke) external;

  /// @notice Owner: mark a hub as restricted (or unrestrict).
  /// @param hub The address of the hub.
  /// @param isRestricted True to restrict, false to unrestrict.
  function setHubRestricted(address hub, bool isRestricted) external;

  /// @notice Owner: mark a spoke as restricted (or unrestrict).
  /// @param spoke The address of the spoke.
  /// @param isRestricted True to restrict, false to unrestrict.
  function setSpokeRestricted(address spoke, bool isRestricted) external;

  /// @notice Owner: mark a (spoke, hub) tuple as restricted (or unrestrict).
  /// @param spoke The address of the spoke.
  /// @param hub The address of the hub.
  /// @param isRestricted True to restrict, false to unrestrict.
  function setSpokeHubRestricted(address spoke, address hub, bool isRestricted) external;

  /// @notice Owner: mark a (spoke, hub, asset) reserve as restricted (or unrestrict).
  /// @param spoke The address of the spoke.
  /// @param hub The address of the hub.
  /// @param asset The address of the underlying asset.
  /// @param isRestricted True to restrict, false to unrestrict.
  function setReserveRestricted(
    address spoke,
    address hub,
    address asset,
    bool isRestricted
  ) external;

  /// @notice Returns the registered hub config.
  function getHubConfig(address hub) external view returns (HubConfig memory);

  /// @notice Returns the registered spoke config.
  function getSpokeConfig(address spoke) external view returns (SpokeConfig memory);

  /// @notice Returns the per-param debounce timestamps for the IR updates on `(hub, asset)`.
  /// @param hub The address of the hub.
  /// @param asset The address of the underlying asset.
  function getHubAssetDebounce(
    address hub,
    address asset
  ) external view returns (HubAssetDebounce memory);

  /// @notice Returns the per-param debounce timestamps for the cap updates on `(hub, spoke, asset)`.
  /// @param hub The address of the hub.
  /// @param spoke The address of the spoke.
  /// @param asset The address of the underlying asset.
  function getHubSpokeAssetDebounce(
    address hub,
    address spoke,
    address asset
  ) external view returns (HubSpokeAssetDebounce memory);

  /// @notice Returns the per-param debounce timestamps for reserve updates on `(spoke, hub, asset)`.
  /// @param spoke The address of the spoke.
  /// @param hub The address of the hub.
  /// @param asset The address of the underlying asset.
  function getSpokeReserveDebounce(
    address spoke,
    address hub,
    address asset
  ) external view returns (SpokeReserveDebounce memory);

  /// @notice Returns the per-param debounce timestamps for dynamic reserve updates at a given key.
  /// @param spoke The address of the spoke.
  /// @param hub The address of the hub.
  /// @param asset The address of the underlying asset.
  /// @param dynamicConfigKey The dynamic config key.
  function getSpokeDynamicDebounce(
    address spoke,
    address hub,
    address asset,
    uint32 dynamicConfigKey
  ) external view returns (SpokeDynamicDebounce memory);

  /// @notice Returns the per-param debounce timestamps for the spoke-global liquidation config.
  function getSpokeLiquidationDebounce(
    address spoke
  ) external view returns (SpokeLiquidationDebounce memory);

  /// @notice Returns whether a hub is restricted.
  function isHubRestricted(address hub) external view returns (bool);

  /// @notice Returns whether a spoke is restricted.
  function isSpokeRestricted(address spoke) external view returns (bool);

  /// @notice Returns whether a (spoke, hub) tuple is restricted.
  function isSpokeHubRestricted(address spoke, address hub) external view returns (bool);

  /// @notice Returns whether a (spoke, hub, asset) reserve is restricted.
  function isReserveRestricted(
    address spoke,
    address hub,
    address asset
  ) external view returns (bool);

  /// @notice Returns the council address that may call the update entrypoints.
  function RISK_COUNCIL() external view returns (address);
}
