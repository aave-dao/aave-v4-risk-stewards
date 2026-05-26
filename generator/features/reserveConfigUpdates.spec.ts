import {expect, describe, it} from 'vitest';
import {MOCK_OPTIONS, reserveConfigUpdate} from './mocks/configs';
import {generateFiles} from '../generator';
import {FEATURE, ChainConfigs} from '../types';
import {reserveConfigUpdates} from './reserveConfigUpdates';

describe('feature: reserveConfigUpdates', () => {
  it('should return reasonable code', () => {
    const output = reserveConfigUpdates.build({
      options: MOCK_OPTIONS,
      chain: 'AaveV4Ethereum',
      cfg: reserveConfigUpdate,
      cache: {blockNumber: 42},
    });
    expect(output).toMatchSnapshot();
  });

  it('should properly generate files', async () => {
    const chainConfigs: ChainConfigs = {
      AaveV4Ethereum: {
        artifacts: [
          reserveConfigUpdates.build({
            options: {...MOCK_OPTIONS, chains: ['AaveV4Ethereum']},
            chain: 'AaveV4Ethereum',
            cfg: reserveConfigUpdate,
            cache: {blockNumber: 42},
          }),
        ],
        configs: {[FEATURE.RESERVE_CONFIG_UPDATE]: reserveConfigUpdate},
        cache: {blockNumber: 42},
      },
    };
    const files = await generateFiles({...MOCK_OPTIONS, chains: ['AaveV4Ethereum']}, chainConfigs);
    expect(files).toMatchSnapshot();
  });
});
