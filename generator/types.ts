import {
  HubAssetIrUpdate,
  HubSpokeCapsUpdate,
  ReserveConfigUpdate,
  DynamicReserveConfigUpdate,
  DynamicReserveConfigAddition,
  SpokeLiquidationConfigUpdate,
} from './features/types';

export const V4_CHAINS = ['AaveV4Ethereum', 'AaveV4Avalanche'] as const;

export const CHAINS = [...V4_CHAINS] as const;

export type ChainIdentifier = (typeof CHAINS)[number];

export interface Options {
  force?: boolean;
  chains: ChainIdentifier[];
  title: string;
  shortName: string;
  author: string;
  discussion: string;
  configFile?: string;
  date: string;
}

export type ChainConfigs = Partial<Record<ChainIdentifier, ChainConfig>>;

export type CodeArtifact = {
  code?: {
    constants?: string[];
    fn?: string[];
    execute?: string[];
  };
};

export enum FEATURE {
  HUB_ASSET_IR_UPDATE = 'HUB_ASSET_IR_UPDATE',
  HUB_SPOKE_CAPS_UPDATE = 'HUB_SPOKE_CAPS_UPDATE',
  RESERVE_CONFIG_UPDATE = 'RESERVE_CONFIG_UPDATE',
  DYNAMIC_RESERVE_CONFIG_UPDATE = 'DYNAMIC_RESERVE_CONFIG_UPDATE',
  DYNAMIC_RESERVE_CONFIG_ADDITION = 'DYNAMIC_RESERVE_CONFIG_ADDITION',
  SPOKE_LIQUIDATION_CONFIG_UPDATE = 'SPOKE_LIQUIDATION_CONFIG_UPDATE',
}

export interface FeatureModule<T extends {} = {}> {
  description: string;
  value: FEATURE;
  cli: (args: {options: Options; chain: ChainIdentifier; cache: ChainCache}) => Promise<T>;
  build: (args: {
    options: Options;
    chain: ChainIdentifier;
    cache: ChainCache;
    cfg: T;
  }) => CodeArtifact;
}

export const ENGINE_FLAGS = {
  KEEP_CURRENT: 'KEEP_CURRENT',
  KEEP_CURRENT_ADDRESS: 'KEEP_CURRENT_ADDRESS',
  KEEP_CURRENT_UINT16: 'KEEP_CURRENT_UINT16',
  KEEP_CURRENT_UINT32: 'KEEP_CURRENT_UINT32',
  KEEP_CURRENT_UINT64: 'KEEP_CURRENT_UINT64',
} as const;

export type ConfigFile = {
  rootOptions: Options;
  chainOptions: Partial<Record<ChainIdentifier, Omit<ChainConfig, 'artifacts'>>>;
};

export type ChainCache = {blockNumber: number};

export interface ChainConfig {
  artifacts: CodeArtifact[];
  configs: {
    [FEATURE.HUB_ASSET_IR_UPDATE]?: HubAssetIrUpdate[];
    [FEATURE.HUB_SPOKE_CAPS_UPDATE]?: HubSpokeCapsUpdate[];
    [FEATURE.RESERVE_CONFIG_UPDATE]?: ReserveConfigUpdate[];
    [FEATURE.DYNAMIC_RESERVE_CONFIG_UPDATE]?: DynamicReserveConfigUpdate[];
    [FEATURE.DYNAMIC_RESERVE_CONFIG_ADDITION]?: DynamicReserveConfigAddition[];
    [FEATURE.SPOKE_LIQUIDATION_CONFIG_UPDATE]?: SpokeLiquidationConfigUpdate[];
  };
  cache: ChainCache;
}

export type Files = {
  jsonConfig: string;
  payloads: {chain: ChainIdentifier; payload: string; contractName: string}[];
};
