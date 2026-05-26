import {describe, it, expect, afterAll} from 'vitest';
import {execSync} from 'child_process';
import fs from 'fs';
import path from 'path';

import {getHubs, getSpokes, getAssets, generateFolderName} from './common';
import {generateFiles, writeFiles} from './generator';
import {hubAssetIrUpdates} from './features/hubAssetIrUpdates';
import {hubSpokeCapsUpdates} from './features/hubSpokeCapsUpdates';
import {reserveConfigUpdates} from './features/reserveConfigUpdates';
import {dynamicReserveConfigUpdates} from './features/dynamicReserveConfigUpdates';
import {dynamicReserveConfigAdditions} from './features/dynamicReserveConfigAdditions';
import {spokeLiquidationConfigUpdates} from './features/spokeLiquidationConfigUpdates';
import {ChainConfigs, ChainIdentifier, FEATURE, Options} from './types';
import {translateHubToHubLib, translateSpokeToSpokeLib, translateAssetToAssetLibUnderlying} from './prompts/assetsSelectPrompt';

const CHAIN: ChainIdentifier = 'AaveV4Ethereum';

const OPTIONS: Options = {
  force: true,
  chains: [CHAIN],
  title: 'e2e test',
  shortName: 'E2eTest',
  author: 'tester',
  discussion: 'none',
  date: '20260525',
};

const E2E_FOLDER = path.join(process.cwd(), 'src/updates/', generateFolderName(OPTIONS));

describe('generator e2e', () => {
  afterAll(() => {
    if (fs.existsSync(E2E_FOLDER)) fs.rmSync(E2E_FOLDER, {recursive: true, force: true});
  });

  /// These three tests directly exercise the address-book lookup helpers — the same code path the
  /// interactive `select` prompts depend on. If the upstream `@aave-dao/aave-address-book` ever
  /// changes its export shape (or we mis-read it), the select prompts would fail at runtime with
  /// "No selectable choices. All choices are disabled." — these tests catch that statically.
  describe('address-book lookups', () => {
    it('getHubs returns the three Ethereum hubs', () => {
      const hubs = getHubs(CHAIN);
      expect(hubs).toContain('CORE_HUB');
      expect(hubs).toContain('PLUS_HUB');
      expect(hubs).toContain('PRIME_HUB');
    });

    it('getSpokes returns spokes ending in _SPOKE and _ESPOKE, with no _ORACLE entries', () => {
      const spokes = getSpokes(CHAIN);
      expect(spokes.length).toBeGreaterThan(0);
      expect(spokes).toContain('MAIN_SPOKE');
      expect(spokes).toContain('LIDO_ESPOKE');
      expect(spokes.every((s) => !/_ORACLE$/.test(s))).toBe(true);
    });

    it('getAssets returns the canonical underlyings (WETH, USDC, USDT)', () => {
      const assets = getAssets(CHAIN);
      expect(assets).toContain('WETH');
      expect(assets).toContain('USDC');
      expect(assets).toContain('USDT');
    });
  });

  /// Spot-check the JS→Sol translation helpers — each emits a Solidity identifier the on-disk
  /// address-book library actually declares.
  describe('JS→Solidity translation', () => {
    it('translateHubToHubLib emits AaveV4EthereumHubs.<HUB>', () => {
      expect(translateHubToHubLib('CORE_HUB', CHAIN)).toBe('AaveV4EthereumHubs.CORE_HUB');
    });

    it('translateSpokeToSpokeLib emits AaveV4EthereumSpokes.<SPOKE>', () => {
      expect(translateSpokeToSpokeLib('MAIN_SPOKE', CHAIN)).toBe(
        'AaveV4EthereumSpokes.MAIN_SPOKE'
      );
    });

    it('translateAssetToAssetLibUnderlying appends _UNDERLYING', () => {
      expect(translateAssetToAssetLibUnderlying('WETH', CHAIN)).toBe(
        'AaveV4EthereumAssets.WETH_UNDERLYING'
      );
    });
  });

  /// The headline test: feed all six feature modules through generateFiles + writeFiles, then
  /// invoke `forge build` to confirm the generated Solidity is structurally correct (right
  /// imports, right struct shapes, right sentinel constants). Catches anything that snapshot
  /// tests miss because they're text-equality rather than semantic.
  it('full pipeline: all six features → generated payload compiles via forge', async () => {
    const hub = 'CORE_HUB';
    const hub2 = 'PLUS_HUB';
    const spoke = 'MAIN_SPOKE';
    const spoke2 = 'LIDO_ESPOKE';
    const asset = 'WETH';
    const asset2 = 'wstETH';

    const ctx = {options: OPTIONS, chain: CHAIN, cache: {blockNumber: 42}};

    // Every feature carries at least two distinct tuples so the multi-select CLI walk gets
    // exercised end-to-end: cross-hub IR updates, cross-(hub,spoke) caps, cross-spoke reserve/
    // dynamic config, multi-key dynamic update on the same (spoke, hub, asset), and multi-spoke
    // liquidation config.
    const featureConfigs = {
      [FEATURE.HUB_ASSET_IR_UPDATE]: [
        {
          hub,
          asset,
          optimalUsageRatio: '',
          baseDrawnRate: '1',
          rateGrowthBeforeOptimal: '',
          rateGrowthAfterOptimal: '',
        },
        {
          hub: hub2,
          asset: 'USDC',
          optimalUsageRatio: '90',
          baseDrawnRate: '',
          rateGrowthBeforeOptimal: '',
          rateGrowthAfterOptimal: '',
        },
      ],
      [FEATURE.HUB_SPOKE_CAPS_UPDATE]: [
        {hub, spoke, asset, addCap: '20000', drawCap: '1700'},
        {hub: hub2, spoke, asset: 'USDC', addCap: '5000000', drawCap: '4500000'},
      ],
      [FEATURE.RESERVE_CONFIG_UPDATE]: [
        {hub, spoke, asset, collateralRisk: '1500'},
        {hub, spoke: spoke2, asset: asset2, collateralRisk: '1800'},
      ],
      [FEATURE.DYNAMIC_RESERVE_CONFIG_UPDATE]: [
        {
          hub,
          spoke,
          asset,
          dynamicConfigKey: '0',
          collateralFactor: '80',
          maxLiquidationBonus: '',
        },
        // Same (spoke, hub, asset) — different key → exercises the inner do-while loop.
        {
          hub,
          spoke,
          asset,
          dynamicConfigKey: '1',
          collateralFactor: '82',
          maxLiquidationBonus: '6',
        },
        // Different (spoke, asset).
        {
          hub,
          spoke: spoke2,
          asset: asset2,
          dynamicConfigKey: '0',
          collateralFactor: '78',
          maxLiquidationBonus: '',
        },
      ],
      [FEATURE.DYNAMIC_RESERVE_CONFIG_ADDITION]: [
        {
          hub,
          spoke,
          asset,
          collateralFactor: '82',
          maxLiquidationBonus: '5',
          liquidationFee: '10',
        },
        {
          hub,
          spoke: spoke2,
          asset: asset2,
          collateralFactor: '80',
          maxLiquidationBonus: '6',
          liquidationFee: '10',
        },
      ],
      [FEATURE.SPOKE_LIQUIDATION_CONFIG_UPDATE]: [
        {
          spoke,
          targetHealthFactor: '1050000000000000000',
          healthFactorForMaxBonus: '',
          liquidationBonusFactor: '',
        },
        {
          spoke: spoke2,
          targetHealthFactor: '',
          healthFactorForMaxBonus: '1010000000000000000',
          liquidationBonusFactor: '5',
        },
      ],
    };

    const chainConfigs: ChainConfigs = {
      [CHAIN]: {
        artifacts: [
          hubAssetIrUpdates.build({...ctx, cfg: featureConfigs[FEATURE.HUB_ASSET_IR_UPDATE]}),
          hubSpokeCapsUpdates.build({...ctx, cfg: featureConfigs[FEATURE.HUB_SPOKE_CAPS_UPDATE]}),
          reserveConfigUpdates.build({...ctx, cfg: featureConfigs[FEATURE.RESERVE_CONFIG_UPDATE]}),
          dynamicReserveConfigUpdates.build({
            ...ctx,
            cfg: featureConfigs[FEATURE.DYNAMIC_RESERVE_CONFIG_UPDATE],
          }),
          dynamicReserveConfigAdditions.build({
            ...ctx,
            cfg: featureConfigs[FEATURE.DYNAMIC_RESERVE_CONFIG_ADDITION],
          }),
          spokeLiquidationConfigUpdates.build({
            ...ctx,
            cfg: featureConfigs[FEATURE.SPOKE_LIQUIDATION_CONFIG_UPDATE],
          }),
        ],
        configs: featureConfigs,
        cache: {blockNumber: 42},
      },
    };

    const files = await generateFiles(OPTIONS, chainConfigs);
    await writeFiles(OPTIONS, files);

    // The generated file path mirrors writeFiles' folder layout.
    const payloadFile = path.join(
      E2E_FOLDER,
      `${OPTIONS.chains[0]}_${OPTIONS.shortName}_${OPTIONS.date}.sol`
    );
    expect(fs.existsSync(payloadFile)).toBe(true);

    // Body sanity — every feature contributed its function and the v4 sentinels are used.
    const body = fs.readFileSync(payloadFile, 'utf8');
    expect(body).toContain('function hubAssetIrUpdates()');
    expect(body).toContain('function hubSpokeCapsUpdates()');
    expect(body).toContain('function reserveConfigUpdates()');
    expect(body).toContain('function dynamicReserveConfigUpdates()');
    expect(body).toContain('function dynamicReserveConfigAdditions()');
    expect(body).toContain('function spokeLiquidationConfigUpdates()');
    expect(body).toContain('AaveV4EthereumHubs.CORE_HUB');
    expect(body).toContain('AaveV4EthereumSpokes.MAIN_SPOKE');
    expect(body).toContain('AaveV4EthereumAssets.WETH_UNDERLYING');
    expect(body).toContain('EngineFlags.KEEP_CURRENT_UINT16');
    expect(body).toContain('EngineFlags.KEEP_CURRENT_UINT32');

    // Multi-tuple sanity — both hubs/spokes/assets show up in the same payload.
    expect(body).toContain('AaveV4EthereumHubs.PLUS_HUB');
    expect(body).toContain('AaveV4EthereumSpokes.LIDO_ESPOKE');
    expect(body).toContain('AaveV4EthereumAssets.wstETH_UNDERLYING');
    expect(body).toContain('AaveV4EthereumAssets.USDC_UNDERLYING');
    // Array sizes match the feature config lengths.
    expect(body).toContain('new IAaveV4ConfigEngine.AssetConfigUpdate[](2)');
    expect(body).toContain('new IAaveV4ConfigEngine.SpokeConfigUpdate[](2)');
    expect(body).toContain('new IAaveV4ConfigEngine.ReserveConfigUpdate[](2)');
    expect(body).toContain('new IAaveV4ConfigEngine.DynamicReserveConfigUpdate[](3)');
    expect(body).toContain('new IAaveV4ConfigEngine.DynamicReserveConfigAddition[](2)');
    expect(body).toContain('new IAaveV4ConfigEngine.LiquidationConfigUpdate[](2)');

    // The semantic check — forge needs to be on PATH for this to fire; if it isn't, we still
    // have the textual assertions above. CI runs forge already (steward unit tests depend on it)
    // so this is reliable in practice.
    expect(() =>
      execSync('forge build', {
        cwd: process.cwd(),
        stdio: 'pipe',
      })
    ).not.toThrow();
  }, 180_000);
});
