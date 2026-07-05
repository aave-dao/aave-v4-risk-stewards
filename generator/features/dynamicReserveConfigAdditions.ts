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
              message:
                'liquidationFee for new key — blank copies the prior key on-chain (recommended; the steward requires it to equal the prior key)',
            }),
          });
        }
      }
    }
    return response;
  },
  build({chain, cfg}) {
    const needsPriorFeeHelper = cfg.some((c) => !c.liquidationFee);
    const mutability = needsPriorFeeHelper ? 'view' : 'pure';

    const liquidationFeeExpr = (c: (typeof cfg)[number]) =>
      c.liquidationFee
        ? translateJsPercentToSol(c.liquidationFee)
        : `_priorLiquidationFee(${translateHubToHubLib(c.hub, chain)}, ${translateSpokeToSpokeLib(
            c.spoke,
            chain,
          )}, ${translateAssetToAssetLibUnderlying(c.asset, chain)})`;

    const fn = [
      `function dynamicReserveConfigAdditions() public ${mutability} override returns (IAaveV4ConfigEngine.DynamicReserveConfigAddition[] memory additions) {
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
                liquidationFee: ${liquidationFeeExpr(c)}
              })
            });`,
              )
              .join('\n')}
          }`,
    ];

    if (needsPriorFeeHelper) {
      fn.push(
        `/// @dev Reads \`liquidationFee\` from the reserve's latest dynamic config key.
          function _priorLiquidationFee(IHub hub, ISpoke spoke, address underlying) private view returns (uint16) {
            uint256 reserveId = spoke.getReserveId(address(hub), hub.getAssetId(underlying));
            return
              spoke.getDynamicReserveConfig(reserveId, spoke.getReserve(reserveId).dynamicConfigKey).liquidationFee;
          }`,
      );
    }

    const response: CodeArtifact = {code: {fn}};
    return response;
  },
};
