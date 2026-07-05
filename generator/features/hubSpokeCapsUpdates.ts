import {CodeArtifact, FEATURE, FeatureModule} from '../types';
import {HubSpokeCapsUpdate} from './types';
import {
  hubsSelectPrompt,
  spokesSelectPrompt,
  assetsSelectPrompt,
  translateAssetToAssetLibUnderlying,
  translateHubToHubLib,
  translateSpokeToSpokeLib,
} from '../prompts/assetsSelectPrompt';
import {numberPrompt, translateJsNumberToSol} from '../prompts/numberPrompt';

async function fetchCaps() {
  return {
    addCap: await numberPrompt({message: 'addCap (raw units, blank to keep)'}, {}),
    drawCap: await numberPrompt({message: 'drawCap (raw units, blank to keep)'}, {}),
  };
}

export const hubSpokeCapsUpdates: FeatureModule<HubSpokeCapsUpdate[]> = {
  value: FEATURE.HUB_SPOKE_CAPS_UPDATE,
  description: 'HubSpokeCapsUpdates (addCap, drawCap)',
  async cli({chain}) {
    console.log(`Fetching information for HubSpokeCapsUpdates on ${chain}`);
    const hubs = await hubsSelectPrompt({chain, message: 'Hubs'});
    const response: HubSpokeCapsUpdate[] = [];
    for (const hub of hubs) {
      console.log(`Hub: ${hub}`);
      const spokes = await spokesSelectPrompt({
        chain,
        message: `Spokes registered to ${hub}`,
      });
      for (const spoke of spokes) {
        console.log(`  Spoke: ${spoke}`);
        const assets = await assetsSelectPrompt({
          chain,
          message: `Assets on (${hub}, ${spoke})`,
        });
        for (const asset of assets) {
          console.log(`    Collecting cap fields for ${asset}`);
          response.push({hub, spoke, asset, ...(await fetchCaps())});
        }
      }
    }
    return response;
  },
  build({chain, cfg}) {
    const response: CodeArtifact = {
      code: {
        fn: [
          `function hubSpokeCapsUpdates() public pure override returns (IAaveV4ConfigEngine.SpokeConfigUpdate[] memory updates) {
            updates = new IAaveV4ConfigEngine.SpokeConfigUpdate[](${cfg.length});

            ${cfg
              .map(
                (c, ix) => `updates[${ix}] = IAaveV4ConfigEngine.SpokeConfigUpdate({
              hubConfigurator: ${chain}.HUB_CONFIGURATOR,
              hub: address(${translateHubToHubLib(c.hub, chain)}),
              underlying: ${translateAssetToAssetLibUnderlying(c.asset, chain)},
              spoke: address(${translateSpokeToSpokeLib(c.spoke, chain)}),
              addCap: ${translateJsNumberToSol(c.addCap)},
              drawCap: ${translateJsNumberToSol(c.drawCap)},
              riskPremiumThreshold: EngineFlags.KEEP_CURRENT,
              active: EngineFlags.KEEP_CURRENT,
              halted: EngineFlags.KEEP_CURRENT
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
