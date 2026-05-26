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

/// Addition appends a new key; the steward reads the latest existing key on-chain to validate
/// the change, so the author only supplies the new value (or empty to copy from the prior key).
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
