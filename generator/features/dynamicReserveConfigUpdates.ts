import {confirm} from '@inquirer/prompts';

import {CodeArtifact, FEATURE, FeatureModule} from '../types';
import {DynamicReserveConfigUpdate} from './types';
import {
  hubsSelectPrompt,
  spokesSelectPrompt,
  assetsSelectPrompt,
  translateAssetToAssetLibUnderlying,
  translateHubToHubLib,
  translateSpokeToSpokeLib,
} from '../prompts/assetsSelectPrompt';
import {numberPrompt, translateJsNumberToSol} from '../prompts/numberPrompt';
import {percentPrompt, translateJsPercentToSol} from '../prompts/percentPrompt';

export const dynamicReserveConfigUpdates: FeatureModule<DynamicReserveConfigUpdate[]> = {
  value: FEATURE.DYNAMIC_RESERVE_CONFIG_UPDATE,
  description:
    'DynamicReserveConfigUpdates (collateralFactor, maxLiquidationBonus) — bounds: SpokeConfig.dynamicUpdate (typically stricter)',
  async cli({chain}) {
    console.log(`Fetching information for DynamicReserveConfigUpdates on ${chain}`);
    const spokes = await spokesSelectPrompt({chain, message: 'Spokes'});
    const response: DynamicReserveConfigUpdate[] = [];
    for (const spoke of spokes) {
      console.log(`Spoke: ${spoke}`);
      const hubs = await hubsSelectPrompt({chain, message: `Hubs for ${spoke}`});
      for (const hub of hubs) {
        console.log(`  Hub: ${hub}`);
        const assets = await assetsSelectPrompt({
          chain,
          message: `Assets on (${spoke}, ${hub})`,
        });
        for (const asset of assets) {
          console.log(`    Collecting dynamic fields for ${asset}`);
          let addMore = true;
          while (addMore) {
            response.push({
              hub,
              spoke,
              asset,
              dynamicConfigKey: await numberPrompt(
                {message: `dynamicConfigKey for ${asset} (e.g. 0)`, required: true},
                {}
              ),
              collateralFactor: await percentPrompt({
                message: 'collateralFactor (BPS, blank to keep)',
              }),
              maxLiquidationBonus: await percentPrompt({
                message: 'maxLiquidationBonus (BPS, blank to keep)',
              }),
            });
            addMore = await confirm({
              message: `Add another dynamicConfigKey for ${asset}?`,
              default: false,
            });
          }
        }
      }
    }
    return response;
  },
  build({chain, cfg}) {
    const response: CodeArtifact = {
      code: {
        fn: [
          `function dynamicReserveConfigUpdates() public pure override returns (IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] memory updates) {
            updates = new IAaveV4ConfigEngine.DynamicReserveConfigUpdate[](${cfg.length});

            ${cfg
              .map(
                (c, ix) => `updates[${ix}] = IAaveV4ConfigEngine.DynamicReserveConfigUpdate({
              spokeConfigurator: ${chain}.SPOKE_CONFIGURATOR,
              spoke: address(${translateSpokeToSpokeLib(c.spoke, chain)}),
              hub: address(${translateHubToHubLib(c.hub, chain)}),
              underlying: ${translateAssetToAssetLibUnderlying(c.asset, chain)},
              dynamicConfigKey: ${translateJsNumberToSol(c.dynamicConfigKey)},
              collateralFactor: ${translateJsPercentToSol(c.collateralFactor)},
              maxLiquidationBonus: ${translateJsPercentToSol(c.maxLiquidationBonus)},
              liquidationFee: EngineFlags.KEEP_CURRENT
            });`
              )
              .join('\n')}
          }`,
        ],
      },
    };
    return response;
  },
};
