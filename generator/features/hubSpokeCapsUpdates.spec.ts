import {expect, describe, it} from 'vitest';
import {MOCK_OPTIONS, hubSpokeCapsUpdate} from './mocks/configs';
import {generateFiles} from '../generator';
import {FEATURE, ChainConfigs} from '../types';
import {hubSpokeCapsUpdates} from './hubSpokeCapsUpdates';

describe('feature: hubSpokeCapsUpdates', () => {
  it('should return reasonable code', () => {
    const output = hubSpokeCapsUpdates.build({
      options: MOCK_OPTIONS,
      chain: 'AaveV4Ethereum',
      cfg: hubSpokeCapsUpdate,
      cache: {blockNumber: 42},
    });
    expect(output).toMatchSnapshot();
  });

  it('should properly generate files', async () => {
    const chainConfigs: ChainConfigs = {
      AaveV4Ethereum: {
        artifacts: [
          hubSpokeCapsUpdates.build({
            options: {...MOCK_OPTIONS, chains: ['AaveV4Ethereum']},
            chain: 'AaveV4Ethereum',
            cfg: hubSpokeCapsUpdate,
            cache: {blockNumber: 42},
          }),
        ],
        configs: {[FEATURE.HUB_SPOKE_CAPS_UPDATE]: hubSpokeCapsUpdate},
        cache: {blockNumber: 42},
      },
    };
    const files = await generateFiles({...MOCK_OPTIONS, chains: ['AaveV4Ethereum']}, chainConfigs);
    expect(files).toMatchSnapshot();
  });
});
