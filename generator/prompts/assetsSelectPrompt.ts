import {checkbox, select} from '@inquirer/prompts';
import {GenericChainPrompt} from './types';
import {getAssets, getHubs, getSpokes} from '../common';
import {ChainIdentifier} from '../types';

/**
 * Multi-select for assets. Returns the unsuffixed names (e.g. ["WETH", "USDC"]).
 */
export async function assetsSelectPrompt({chain, message}: GenericChainPrompt) {
  return checkbox({
    message,
    choices: getAssets(chain).map((asset) => ({name: asset, value: asset})),
  });
}

export async function hubSelectPrompt({chain, message}: GenericChainPrompt): Promise<string> {
  return select({
    message,
    choices: getHubs(chain).map((hub) => ({name: hub, value: hub})),
  });
}

export async function spokeSelectPrompt({chain, message}: GenericChainPrompt): Promise<string> {
  return select({
    message,
    choices: getSpokes(chain).map((spoke) => ({name: spoke, value: spoke})),
  });
}

/// Multi-select variant. Returns an array of one or more hub names.
export async function hubsSelectPrompt({chain, message}: GenericChainPrompt): Promise<string[]> {
  return checkbox({
    message,
    choices: getHubs(chain).map((hub) => ({name: hub, value: hub})),
    required: true,
  });
}

/// Multi-select variant. Returns an array of one or more spoke names.
export async function spokesSelectPrompt({chain, message}: GenericChainPrompt): Promise<string[]> {
  return checkbox({
    message,
    choices: getSpokes(chain).map((spoke) => ({name: spoke, value: spoke})),
    required: true,
  });
}

/// e.g. `AaveV4EthereumAssets.WETH_UNDERLYING`
/// Symbols carrying characters that are illegal in a Solidity identifier (`BTC.b`, `WETH.e` on
/// Avalanche) are declared with those characters dropped, e.g. `BTCb_UNDERLYING`.
export function translateAssetToAssetLibUnderlying(value: string, chain: ChainIdentifier) {
  return `${chain}Assets.${value.replace(/[^\w]/g, '')}_UNDERLYING`;
}

/// e.g. `AaveV4EthereumHubs.CORE_HUB`
export function translateHubToHubLib(value: string, chain: ChainIdentifier) {
  return `${chain}Hubs.${value}`;
}

/// e.g. `AaveV4EthereumSpokes.MAIN_SPOKE`
export function translateSpokeToSpokeLib(value: string, chain: ChainIdentifier) {
  return `${chain}Spokes.${value}`;
}
