import {
  generateContractName,
  getChainAlias,
  getChainSuffix,
  generateFolderName,
} from '../common';
import {Options, ChainConfig, ChainIdentifier} from '../types';
import {prefixWithImports} from '../utils/importsResolver';
import {prefixWithPragma} from '../utils/constants';

export const proposalTemplate = (
  options: Options,
  chainConfig: ChainConfig,
  chain: ChainIdentifier
) => {
  const {title, author, discussion} = options;
  const chainSuffix = getChainSuffix(chain);
  const folderName = generateFolderName(options);
  const contractName = generateContractName(options, chain);

  const functions = chainConfig.artifacts
    .map((artifact) => artifact.code?.fn)
    .flat()
    .filter((f) => f !== undefined)
    .join('\n');

  const contract = `/**
 * @title ${title || 'TODO'}
 * @author ${author || 'TODO'}
 * - discussion: ${discussion || 'TODO'}
 * - deploy-command: make run-script contract=src/updates/${folderName}/${contractName}.sol:${contractName} network=${getChainAlias(
   chain
 )} broadcast=false generate_diff=true skip_timelock=false
 */
contract ${contractName} is RiskStewards${chainSuffix} {
  function name() public pure override returns (string memory) {
    return '${contractName}';
  }

  ${functions}
}`;

  return prefixWithPragma(prefixWithImports(contract));
};
