import * as addressBook from '@aave-dao/aave-address-book';
import {Chain} from 'viem';
import {avalanche, mainnet} from 'viem/chains';
import {ChainIdentifier, Options} from './types';

export const AVAILABLE_CHAINS = ['Ethereum', 'Avalanche'] as const;

export function getChainSuffix(chain: ChainIdentifier) {
  return chain.replace('AaveV4', '');
}

export function getChainName(chain: ChainIdentifier) {
  return getChainSuffix(chain);
}

export function getChainAlias(chain: ChainIdentifier) {
  const suffix = getChainSuffix(chain);
  return suffix === 'Ethereum' ? 'mainnet' : suffix.toLowerCase();
}

/// Address book helpers — the TS address-book nests hubs/spokes/assets under the chain library
/// (e.g. `AaveV4Ethereum.HUBS`, `…SPOKES`, `…ASSETS`). The matching Solidity libraries are
/// `AaveV4EthereumHubs`, `AaveV4EthereumSpokes`, `AaveV4EthereumAssets` — used by the build()
/// step when emitting Solidity. The select prompts only need to enumerate keys whose Solidity
/// constants are real spokes / hubs / underlyings (excluding helper keys like *_ORACLE).

export function getHubs(chain: ChainIdentifier): string[] {
  const lib = (addressBook as any)[chain];
  return Object.keys(lib?.HUBS ?? {});
}

export function getSpokes(chain: ChainIdentifier): string[] {
  const lib = (addressBook as any)[chain];
  return Object.keys(lib?.SPOKES ?? {}).filter((k) => !/_ORACLE$/.test(k));
}

export function getAssets(chain: ChainIdentifier): string[] {
  const lib = (addressBook as any)[chain];
  return Object.keys(lib?.ASSETS ?? {});
}

export function getDate() {
  const date = new Date();
  const years = date.getFullYear();
  const months = date.getMonth() + 1;
  const day = date.getDate();
  return `${years}${months <= 9 ? '0' : ''}${months}${day <= 9 ? '0' : ''}${day}`;
}

export function generateFolderName(options: Options) {
  return `${options.date}_${options.chains.length === 1 ? options.chains[0] : 'Multi'}_${
    options.shortName
  }`;
}

export function generateContractName(options: Options, chain?: ChainIdentifier) {
  let name = chain ? `${chain}_` : '';
  name += `${options.shortName}`;
  name += `_${options.date}`;
  return name;
}

export function pascalCase(str: string) {
  return str
    .replace(/[\W]/g, ' ')
    .replace(/(\w)(\w*)/g, function (_g0, g1, g2) {
      return g1.toUpperCase() + g2;
    })
    .replace(/ /g, '');
}

/// Every chain in `CHAINS` must have an entry here — the viem chain carries the default RPC url
/// the generator reads the block number from. A missing entry makes `http()` throw
/// `UrlRequiredError` before the first prompt.
export const CHAIN_TO_VIEM_CHAIN: Record<ChainIdentifier, Chain> = {
  AaveV4Ethereum: mainnet,
  AaveV4Avalanche: avalanche,
};

export function flagAsRequired(message: string, required?: boolean) {
  return required ? `${message}*` : message;
}
