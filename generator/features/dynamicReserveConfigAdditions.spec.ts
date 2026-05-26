import {expect, describe, it} from 'vitest';
import {MOCK_OPTIONS, dynamicReserveConfigAddition} from './mocks/configs';
import {generateFiles} from '../generator';
import {FEATURE, ChainConfigs} from '../types';
import {dynamicReserveConfigAdditions} from './dynamicReserveConfigAdditions';

describe('feature: dynamicReserveConfigAdditions', () => {
  it('should return reasonable code', () => {
    const output = dynamicReserveConfigAdditions.build({
      options: MOCK_OPTIONS,
      chain: 'AaveV4Ethereum',
      cfg: dynamicReserveConfigAddition,
      cache: {blockNumber: 42},
    });
    expect(output).toMatchSnapshot();
  });

  it('should properly generate files', async () => {
    const chainConfigs: ChainConfigs = {
      AaveV4Ethereum: {
        artifacts: [
          dynamicReserveConfigAdditions.build({
            options: {...MOCK_OPTIONS, chains: ['AaveV4Ethereum']},
            chain: 'AaveV4Ethereum',
            cfg: dynamicReserveConfigAddition,
            cache: {blockNumber: 42},
          }),
        ],
        configs: {[FEATURE.DYNAMIC_RESERVE_CONFIG_ADDITION]: dynamicReserveConfigAddition},
        cache: {blockNumber: 42},
      },
    };
    const files = await generateFiles({...MOCK_OPTIONS, chains: ['AaveV4Ethereum']}, chainConfigs);
    expect(files).toMatchSnapshot();
  });
});
