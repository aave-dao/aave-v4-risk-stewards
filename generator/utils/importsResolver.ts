/**
 * Generated payloads import a varying set of v4 libraries based on which features the author
 * picked. We pull the imports out of the generated body to keep the feature modules from having
 * to track imports independently.
 */

function findMatch(code: string, needle: string) {
  return RegExp(needle, 'g').test(code);
}

function generateAddressBookImports(code: string) {
  const imports: Set<string> = new Set();
  let root = '';
  const baseMatch = code.match(/(?<!I)(AaveV4[A-Za-z]+)(?<!(Assets)|(Hubs)|(Spokes))\b\./);
  if (baseMatch) {
    imports.add(baseMatch[1]);
    root = baseMatch[1];
  }
  const assetsMatch = code.match(/(AaveV4[A-Za-z]+)Assets\./);
  if (assetsMatch) {
    imports.add(assetsMatch[1] + 'Assets');
    root = assetsMatch[1];
  }
  const hubsMatch = code.match(/(AaveV4[A-Za-z]+)Hubs\./);
  if (hubsMatch) {
    imports.add(hubsMatch[1] + 'Hubs');
    root = hubsMatch[1];
  }
  const spokesMatch = code.match(/(AaveV4[A-Za-z]+)Spokes\./);
  if (spokesMatch) {
    imports.add(spokesMatch[1] + 'Spokes');
    root = spokesMatch[1];
  }
  if (imports.size > 0) {
    return `import {${[...imports].join(', ')}} from 'aave-address-book/${root}.sol';\n`;
  }
}

function generateRiskStewardsImport(code: string) {
  const match = code.match(/RiskStewards(\w+?)\b/);
  if (!match) return '';
  const chainName = match[1];
  return `import {RiskStewards${chainName}} from '../../../scripts/networks/RiskStewards${chainName}.s.sol';\n`;
}

/**
 * @dev Returns the input string prefixed with imports
 */
export function prefixWithImports(code: string) {
  let imports = '';

  // address book imports
  const addressBookImports = generateAddressBookImports(code);
  if (addressBookImports) imports += addressBookImports;

  // risk steward network base
  imports += generateRiskStewardsImport(code);

  // v4 config engine
  if (findMatch(code, 'IAaveV4ConfigEngine')) {
    imports += `import {IAaveV4ConfigEngine} from 'aave-v4/config-engine/interfaces/IAaveV4ConfigEngine.sol';\n`;
  }
  if (findMatch(code, 'EngineFlags')) {
    imports += `import {EngineFlags} from 'aave-v4/config-engine/libraries/EngineFlags.sol';\n`;
  }
  if (findMatch(code, 'IAssetInterestRateStrategy')) {
    imports += `import {IAssetInterestRateStrategy} from 'aave-v4/hub/interfaces/IAssetInterestRateStrategy.sol';\n`;
  }
  if (findMatch(code, '\\bIHub\\b')) {
    imports += `import {IHub} from 'aave-v4/hub/interfaces/IHub.sol';\n`;
  }
  if (findMatch(code, 'ISpoke')) {
    imports += `import {ISpoke} from 'aave-v4/spoke/interfaces/ISpoke.sol';\n`;
  }

  return imports + code;
}
