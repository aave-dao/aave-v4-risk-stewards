import {NumberInputValues, PercentInputValues} from '../prompts';

/// (hub, asset) selector — covers the hub-asset IR updates.
export interface HubAssetSelector {
  hub: string;
  asset: string;
}

/// (hub, spoke, asset) selector — covers hub-spoke caps + the spoke-side reserve / dynamic update paths.
export interface HubSpokeAssetSelector {
  hub: string;
  spoke: string;
  asset: string;
}

/// Per-asset IR delta. Empty string = KEEP_CURRENT for that field.
export interface HubAssetIrUpdate extends HubAssetSelector {
  optimalUsageRatio: PercentInputValues;
  baseDrawnRate: PercentInputValues;
  rateGrowthBeforeOptimal: PercentInputValues;
  rateGrowthAfterOptimal: PercentInputValues;
}

export interface HubSpokeCapsUpdate extends HubSpokeAssetSelector {
  addCap: NumberInputValues;
  drawCap: NumberInputValues;
}

export interface ReserveConfigUpdate extends HubSpokeAssetSelector {
  collateralRisk: NumberInputValues;
}

export interface DynamicReserveConfigUpdate extends HubSpokeAssetSelector {
  dynamicConfigKey: NumberInputValues;
  collateralFactor: PercentInputValues;
  maxLiquidationBonus: PercentInputValues;
}

/// Addition appends a new key; the steward validates the change against the reserve's latest
/// on-chain key at execution time. `collateralFactor` / `maxLiquidationBonus` are the new target
/// values; `liquidationFee` must stay equal to the prior key, so leaving it empty makes the payload
/// copy it from the latest key on-chain
export interface DynamicReserveConfigAddition extends HubSpokeAssetSelector {
  collateralFactor: PercentInputValues;
  maxLiquidationBonus: PercentInputValues;
  liquidationFee: PercentInputValues;
}

export interface SpokeLiquidationConfigUpdate {
  spoke: string;
  targetHealthFactor: NumberInputValues;
  healthFactorForMaxBonus: NumberInputValues;
  liquidationBonusFactor: PercentInputValues;
}
