import {Options} from '../../types';
import {
  HubAssetIrUpdate,
  HubSpokeCapsUpdate,
  ReserveConfigUpdate,
  DynamicReserveConfigUpdate,
  DynamicReserveConfigAddition,
  SpokeLiquidationConfigUpdate,
} from '../types';

export const MOCK_OPTIONS: Options = {
  chains: ['AaveV4Ethereum'],
  title: 'test',
  shortName: 'Test',
  date: '20260525',
  author: 'test',
  discussion: 'test',
};

/// Multi-tuple mocks — every feature exercises at least two distinct primary keys (hubs / spokes)
/// so the `build()` output emits an `xxxUpdate[N]` with mixed tuples, which is what the new CLI
/// flow generates after the multi-select refactor.
export const hubAssetIrUpdate: HubAssetIrUpdate[] = [
  {
    hub: 'CORE_HUB',
    asset: 'WETH',
    optimalUsageRatio: '',
    baseDrawnRate: '1',
    rateGrowthBeforeOptimal: '',
    rateGrowthAfterOptimal: '',
  },
  {
    hub: 'PLUS_HUB',
    asset: 'USDC',
    optimalUsageRatio: '90',
    baseDrawnRate: '',
    rateGrowthBeforeOptimal: '',
    rateGrowthAfterOptimal: '',
  },
];

export const hubSpokeCapsUpdate: HubSpokeCapsUpdate[] = [
  {
    hub: 'CORE_HUB',
    spoke: 'MAIN_SPOKE',
    asset: 'WETH',
    addCap: '20000',
    drawCap: '1700',
  },
  {
    hub: 'PLUS_HUB',
    spoke: 'MAIN_SPOKE',
    asset: 'USDC',
    addCap: '5000000',
    drawCap: '4500000',
  },
];

export const reserveConfigUpdate: ReserveConfigUpdate[] = [
  {
    hub: 'CORE_HUB',
    spoke: 'MAIN_SPOKE',
    asset: 'WETH',
    collateralRisk: '1500',
  },
  {
    hub: 'CORE_HUB',
    spoke: 'LIDO_ESPOKE',
    asset: 'wstETH',
    collateralRisk: '1800',
  },
];

export const dynamicReserveConfigUpdate: DynamicReserveConfigUpdate[] = [
  {
    hub: 'CORE_HUB',
    spoke: 'MAIN_SPOKE',
    asset: 'WETH',
    dynamicConfigKey: '0',
    collateralFactor: '80',
    maxLiquidationBonus: '',
  },
  {
    // Same (spoke, hub, asset) — different key. Exercises the inner-most "Add another key?" loop.
    hub: 'CORE_HUB',
    spoke: 'MAIN_SPOKE',
    asset: 'WETH',
    dynamicConfigKey: '1',
    collateralFactor: '82',
    maxLiquidationBonus: '6',
  },
  {
    hub: 'CORE_HUB',
    spoke: 'LIDO_ESPOKE',
    asset: 'wstETH',
    dynamicConfigKey: '0',
    collateralFactor: '78',
    maxLiquidationBonus: '',
  },
];

export const dynamicReserveConfigAddition: DynamicReserveConfigAddition[] = [
  {
    hub: 'CORE_HUB',
    spoke: 'MAIN_SPOKE',
    asset: 'WETH',
    collateralFactor: '82',
    maxLiquidationBonus: '5',
    liquidationFee: '',
  },
  {
    hub: 'CORE_HUB',
    spoke: 'LIDO_ESPOKE',
    asset: 'wstETH',
    collateralFactor: '80',
    maxLiquidationBonus: '6',
    liquidationFee: '10',
  },
];

export const spokeLiquidationConfigUpdate: SpokeLiquidationConfigUpdate[] = [
  {
    spoke: 'MAIN_SPOKE',
    targetHealthFactor: '1050000000000000000',
    healthFactorForMaxBonus: '',
    liquidationBonusFactor: '',
  },
  {
    spoke: 'LIDO_ESPOKE',
    targetHealthFactor: '',
    healthFactorForMaxBonus: '1010000000000000000',
    liquidationBonusFactor: '5',
  },
];
