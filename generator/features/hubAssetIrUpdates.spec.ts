import {expect, describe, it} from 'vitest';
import {MOCK_OPTIONS, hubAssetIrUpdate} from './mocks/configs';
import {generateFiles} from '../generator';
import {FEATURE, ChainConfigs} from '../types';
import {hubAssetIrUpdates} from './hubAssetIrUpdates';

describe('feature: hubAssetIrUpdates', () => {
  it('should return reasonable code', () => {
    const output = hubAssetIrUpdates.build({
      options: MOCK_OPTIONS,
      chain: 'AaveV4Ethereum',
      cfg: hubAssetIrUpdate,
      cache: {blockNumber: 42},
    });
    expect(output).toMatchSnapshot();
  });

  it('should properly generate files', async () => {
    const chainConfigs: ChainConfigs = {
      AaveV4Ethereum: {
        artifacts: [
          hubAssetIrUpdates.build({
            options: {...MOCK_OPTIONS, chains: ['AaveV4Ethereum']},
            chain: 'AaveV4Ethereum',
            cfg: hubAssetIrUpdate,
            cache: {blockNumber: 42},
          }),
        ],
        configs: {[FEATURE.HUB_ASSET_IR_UPDATE]: hubAssetIrUpdate},
        cache: {blockNumber: 42},
      },
    };
    const files = await generateFiles({...MOCK_OPTIONS, chains: ['AaveV4Ethereum']}, chainConfigs);
    expect(files).toMatchSnapshot();
  });
});
