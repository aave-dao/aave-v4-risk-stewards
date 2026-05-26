import {CodeArtifact, FEATURE, FeatureModule} from '../types';
import {DynamicReserveConfigAddition} from './types';
import {
  hubsSelectPrompt,
  spokesSelectPrompt,
  assetsSelectPrompt,
  translateAssetToAssetLibUnderlying,
  translateHubToHubLib,
  translateSpokeToSpokeLib,
} from '../prompts/assetsSelectPrompt';
import {percentPrompt, translateJsPercentToSol} from '../prompts/percentPrompt';

export const dynamicReserveConfigAdditions: FeatureModule<DynamicReserveConfigAddition[]> = {
  value: FEATURE.DYNAMIC_RESERVE_CONFIG_ADDITION,
  description:
    'DynamicReserveConfigAdditions — append a new key (collateralFactor, maxLiquidationBonus, liquidationFee) — bounds: SpokeConfig.dynamicAdd (typically looser)',
  async cli({chain}) {
    console.log(`Fetching information for DynamicReserveConfigAdditions on ${chain}`);
    const spokes = await spokesSelectPrompt({chain, message: 'Spokes'});
    const response: DynamicReserveConfigAddition[] = [];
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
          console.log(`    Collecting addition fields for ${asset}`);
          response.push({
            hub,
            spoke,
            asset,
            collateralFactor: await percentPrompt({
              message: 'collateralFactor for new key (BPS, required)',
              required: true,
            }),
            maxLiquidationBonus: await percentPrompt({
              message: 'maxLiquidationBonus for new key (BPS, required)',
              required: true,
            }),
            liquidationFee: await percentPrompt({
              message: 'liquidationFee for new key — MUST equal prior key (BPS, required)',
              required: true,
            }),
          });
        }
      }
    }
    return response;
  },
  build({chain, cfg}) {
    const response: CodeArtifact = {
      code: {
        fn: [
          `function dynamicReserveConfigAdditions() public pure override returns (IAaveV4ConfigEngine.DynamicReserveConfigAddition[] memory additions) {
            additions = new IAaveV4ConfigEngine.DynamicReserveConfigAddition[](${cfg.length});

            ${cfg
              .map(
                (c, ix) => `additions[${ix}] = IAaveV4ConfigEngine.DynamicReserveConfigAddition({
              spokeConfigurator: ${chain}.SPOKE_CONFIGURATOR,
              spoke: address(${translateSpokeToSpokeLib(c.spoke, chain)}),
              hub: address(${translateHubToHubLib(c.hub, chain)}),
              underlying: ${translateAssetToAssetLibUnderlying(c.asset, chain)},
              dynamicConfig: ISpoke.DynamicReserveConfig({
                collateralFactor: ${translateJsPercentToSol(c.collateralFactor)},
                maxLiquidationBonus: ${translateJsPercentToSol(c.maxLiquidationBonus)},
                liquidationFee: ${translateJsPercentToSol(c.liquidationFee)}
              })
            });`,
              )
              .join('\n')}
          }`,
        ],
      },
    };
    return response;
  },
};
