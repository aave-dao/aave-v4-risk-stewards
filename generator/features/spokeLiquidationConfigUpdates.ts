import {CodeArtifact, FEATURE, FeatureModule} from '../types';
import {SpokeLiquidationConfigUpdate} from './types';
import {spokesSelectPrompt, translateSpokeToSpokeLib} from '../prompts/assetsSelectPrompt';
import {numberPrompt, translateJsNumberToSol} from '../prompts/numberPrompt';
import {percentPrompt, translateJsPercentToSol} from '../prompts/percentPrompt';

export const spokeLiquidationConfigUpdates: FeatureModule<SpokeLiquidationConfigUpdate[]> = {
  value: FEATURE.SPOKE_LIQUIDATION_CONFIG_UPDATE,
  description:
    'SpokeLiquidationConfigUpdates (targetHealthFactor, healthFactorForMaxBonus, liquidationBonusFactor)',
  async cli({chain}) {
    console.log(`Fetching information for SpokeLiquidationConfigUpdates on ${chain}`);
    const spokes = await spokesSelectPrompt({chain, message: 'Spokes'});
    const response: SpokeLiquidationConfigUpdate[] = [];
    for (const spoke of spokes) {
      console.log(`Spoke: ${spoke}`);
      response.push({
        spoke,
        targetHealthFactor: await numberPrompt(
          {message: `targetHealthFactor for ${spoke} (WAD, blank to keep)`},
          {},
        ),
        healthFactorForMaxBonus: await numberPrompt(
          {message: `healthFactorForMaxBonus for ${spoke} (WAD, blank to keep)`},
          {},
        ),
        liquidationBonusFactor: await percentPrompt({
          message: `liquidationBonusFactor for ${spoke} (BPS, blank to keep)`,
        }),
      });
    }
    return response;
  },
  build({chain, cfg}) {
    const response: CodeArtifact = {
      code: {
        fn: [
          `function spokeLiquidationConfigUpdates() public pure override returns (IAaveV4ConfigEngine.LiquidationConfigUpdate[] memory updates) {
            updates = new IAaveV4ConfigEngine.LiquidationConfigUpdate[](${cfg.length});

            ${cfg
              .map(
                (c, ix) => `updates[${ix}] = IAaveV4ConfigEngine.LiquidationConfigUpdate({
              spokeConfigurator: ${chain}.SPOKE_CONFIGURATOR,
              spoke: address(${translateSpokeToSpokeLib(c.spoke, chain)}),
              targetHealthFactor: ${translateJsNumberToSol(c.targetHealthFactor)},
              healthFactorForMaxBonus: ${translateJsNumberToSol(c.healthFactorForMaxBonus)},
              liquidationBonusFactor: ${translateJsPercentToSol(c.liquidationBonusFactor)}
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
