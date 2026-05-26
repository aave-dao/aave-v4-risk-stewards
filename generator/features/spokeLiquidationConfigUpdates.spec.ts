import {expect, describe, it} from 'vitest';
import {MOCK_OPTIONS, spokeLiquidationConfigUpdate} from './mocks/configs';
import {generateFiles} from '../generator';
import {FEATURE, ChainConfigs} from '../types';
import {spokeLiquidationConfigUpdates} from './spokeLiquidationConfigUpdates';

describe('feature: spokeLiquidationConfigUpdates', () => {
  it('should return reasonable code', () => {
    const output = spokeLiquidationConfigUpdates.build({
      options: MOCK_OPTIONS,
      chain: 'AaveV4Ethereum',
      cfg: spokeLiquidationConfigUpdate,
      cache: {blockNumber: 42},
    });
    expect(output).toMatchSnapshot();
  });

  it('should properly generate files', async () => {
    const chainConfigs: ChainConfigs = {
      AaveV4Ethereum: {
        artifacts: [
          spokeLiquidationConfigUpdates.build({
            options: {...MOCK_OPTIONS, chains: ['AaveV4Ethereum']},
            chain: 'AaveV4Ethereum',
            cfg: spokeLiquidationConfigUpdate,
            cache: {blockNumber: 42},
          }),
        ],
        configs: {[FEATURE.SPOKE_LIQUIDATION_CONFIG_UPDATE]: spokeLiquidationConfigUpdate},
        cache: {blockNumber: 42},
      },
    };
    const files = await generateFiles({...MOCK_OPTIONS, chains: ['AaveV4Ethereum']}, chainConfigs);
    expect(files).toMatchSnapshot();
  });
});
