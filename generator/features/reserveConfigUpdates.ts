import {CodeArtifact, FEATURE, FeatureModule} from '../types';
import {ReserveConfigUpdate} from './types';
import {
  hubsSelectPrompt,
  spokesSelectPrompt,
  assetsSelectPrompt,
  translateAssetToAssetLibUnderlying,
  translateHubToHubLib,
  translateSpokeToSpokeLib,
} from '../prompts/assetsSelectPrompt';
import {numberPrompt, translateJsNumberToSol} from '../prompts/numberPrompt';

export const reserveConfigUpdates: FeatureModule<ReserveConfigUpdate[]> = {
  value: FEATURE.RESERVE_CONFIG_UPDATE,
  description: 'ReserveConfigUpdates (collateralRisk)',
  async cli({chain}) {
    console.log(`Fetching information for ReserveConfigUpdates on ${chain}`);
    const spokes = await spokesSelectPrompt({chain, message: 'Spokes'});
    const response: ReserveConfigUpdate[] = [];
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
          console.log(`    Collecting collateralRisk for ${asset}`);
          response.push({
            hub,
            spoke,
            asset,
            collateralRisk: await numberPrompt({message: 'collateralRisk (blank to keep)'}, {}),
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
          `function reserveConfigUpdates() public pure override returns (IAaveV4ConfigEngine.ReserveConfigUpdate[] memory updates) {
            updates = new IAaveV4ConfigEngine.ReserveConfigUpdate[](${cfg.length});

            ${cfg
              .map(
                (c, ix) => `updates[${ix}] = IAaveV4ConfigEngine.ReserveConfigUpdate({
              spokeConfigurator: ${chain}.SPOKE_CONFIGURATOR,
              spoke: address(${translateSpokeToSpokeLib(c.spoke, chain)}),
              hub: address(${translateHubToHubLib(c.hub, chain)}),
              underlying: ${translateAssetToAssetLibUnderlying(c.asset, chain)},
              priceSource: EngineFlags.KEEP_CURRENT_ADDRESS,
              collateralRisk: ${translateJsNumberToSol(c.collateralRisk)},
              paused: EngineFlags.KEEP_CURRENT,
              frozen: EngineFlags.KEEP_CURRENT,
              borrowable: EngineFlags.KEEP_CURRENT,
              receiveSharesEnabled: EngineFlags.KEEP_CURRENT
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
