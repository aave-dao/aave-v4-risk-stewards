import {CodeArtifact, FEATURE, FeatureModule} from '../types';
import {HubAssetIrUpdate} from './types';
import {
  hubsSelectPrompt,
  assetsSelectPrompt,
  translateAssetToAssetLibUnderlying,
  translateHubToHubLib,
} from '../prompts/assetsSelectPrompt';
import {percentPrompt, translateJsPercentToSol} from '../prompts/percentPrompt';

async function fetchIrFields() {
  return {
    optimalUsageRatio: await percentPrompt({message: 'optimalUsageRatio (BPS, blank to keep)'}),
    baseDrawnRate: await percentPrompt({message: 'baseDrawnRate (BPS, blank to keep)'}),
    rateGrowthBeforeOptimal: await percentPrompt({
      message: 'rateGrowthBeforeOptimal (BPS, blank to keep)',
    }),
    rateGrowthAfterOptimal: await percentPrompt({
      message: 'rateGrowthAfterOptimal (BPS, blank to keep)',
    }),
  };
}

export const hubAssetIrUpdates: FeatureModule<HubAssetIrUpdate[]> = {
  value: FEATURE.HUB_ASSET_IR_UPDATE,
  description: 'HubAssetIRUpdates (optimalUsageRatio, baseDrawnRate, rateGrowthBeforeOptimal, rateGrowthAfterOptimal)',
  async cli({chain}) {
    console.log(`Fetching information for HubAssetIRUpdates on ${chain}`);
    const hubs = await hubsSelectPrompt({chain, message: 'Hubs'});
    const response: HubAssetIrUpdate[] = [];
    for (const hub of hubs) {
      console.log(`Hub: ${hub}`);
      const assets = await assetsSelectPrompt({chain, message: `Assets on ${hub}`});
      for (const asset of assets) {
        console.log(`  Collecting IR fields for ${asset}`);
        response.push({hub, asset, ...(await fetchIrFields())});
      }
    }
    return response;
  },
  build({chain, cfg}) {
    const response: CodeArtifact = {
      code: {
        fn: [
          `function hubAssetIrUpdates() public pure override returns (IAaveV4ConfigEngine.AssetConfigUpdate[] memory updates) {
            updates = new IAaveV4ConfigEngine.AssetConfigUpdate[](${cfg.length});

            ${cfg
              .map(
                (c, ix) => `updates[${ix}] = IAaveV4ConfigEngine.AssetConfigUpdate({
              hubConfigurator: ${chain}.HUB_CONFIGURATOR,
              hub: address(${translateHubToHubLib(c.hub, chain)}),
              underlying: ${translateAssetToAssetLibUnderlying(c.asset, chain)},
              liquidityFee: EngineFlags.KEEP_CURRENT,
              feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
              irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
              irData: IAssetInterestRateStrategy.InterestRateData({
                optimalUsageRatio: ${translateJsPercentToSol(c.optimalUsageRatio, 'KEEP_CURRENT_UINT16')},
                baseDrawnRate: ${translateJsPercentToSol(c.baseDrawnRate, 'KEEP_CURRENT_UINT32')},
                rateGrowthBeforeOptimal: ${translateJsPercentToSol(c.rateGrowthBeforeOptimal, 'KEEP_CURRENT_UINT32')},
                rateGrowthAfterOptimal: ${translateJsPercentToSol(c.rateGrowthAfterOptimal, 'KEEP_CURRENT_UINT32')}
              }),
              reinvestmentController: EngineFlags.KEEP_CURRENT_ADDRESS
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
