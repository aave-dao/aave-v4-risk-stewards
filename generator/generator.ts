import fs from 'fs';
import path from 'path';
import {execSync} from 'child_process';
import prettier from 'prettier';
import {confirm} from '@inquirer/prompts';
import {generateContractName, generateFolderName} from './common';
import {proposalTemplate} from './templates/proposal.template';
import {ChainConfigs, ChainIdentifier, Files, Options} from './types';

// Only TS is formatted in-process; Solidity is formatted via the `prettier` CLI in a subprocess
// after the file is written. The `.prettierrc` declares `prettier-plugin-solidity` in its
// `plugins` list, and tsx's runtime resolver pulls in the package's broken `dist/standalone.js`
// bundle which crashes at load time. We resolve the matching `*.ts` override block from
// `.prettierrc` ourselves and drop the `plugins` entry; the CLI binary handles Solidity
// formatting separately and loads the regular `dist/index.js` correctly.
const rawCfg = JSON.parse(fs.readFileSync('.prettierrc', 'utf8'));
const tsOverride = (rawCfg.overrides ?? []).find((o: {files: string}) =>
  String(o.files).includes('ts'),
);
const prettierTsCfg = {...(tsOverride?.options ?? {}), parser: 'typescript' as const};

/**
 * Generates the file contents for the per-chain payloads and the config snapshot.
 */
export async function generateFiles(options: Options, chainConfigs: ChainConfigs): Promise<Files> {
  const jsonConfig = await prettier.format(
    `import {ConfigFile} from '../../../generator/types';
    export const config: ConfigFile = ${JSON.stringify({
      rootOptions: options,
      chainOptions: (Object.keys(chainConfigs) as ChainIdentifier[]).reduce((acc, chain) => {
        acc[chain] = {
          configs: chainConfigs[chain]!.configs,
          cache: chainConfigs[chain]!.cache,
        };
        return acc;
      }, {} as ChainConfigs),
    })}`,
    prettierTsCfg,
  );

  function createPayload(opt: Options, chain: ChainIdentifier) {
    const contractName = generateContractName(opt, chain);
    return {
      chain,
      payload: proposalTemplate(opt, chainConfigs[chain]!, chain),
      contractName,
    };
  }

  return {
    jsonConfig,
    payloads: options.chains.map((chain) => createPayload(options, chain)),
  };
}

async function askBeforeWrite(options: Options, filePath: string, content: string) {
  if (!options.force && fs.existsSync(filePath)) {
    const currentContent = fs.readFileSync(filePath, {encoding: 'utf8'});
    if (currentContent === content) return;
    const force = await confirm({
      message: `A file already exists at ${filePath} do you want to overwrite`,
      default: false,
    });
    if (!force) return;
  }
  fs.writeFileSync(filePath, content);
}

export async function writeFiles(options: Options, {jsonConfig, payloads}: Files) {
  const baseName = generateFolderName(options);
  const baseFolder = path.join(process.cwd(), 'src/updates/', baseName);

  if (fs.existsSync(baseFolder)) {
    if (!options.force) {
      const force = await confirm({
        message: 'A proposal already exists at that location, do you want to continue?',
        default: false,
      });
      if (!force) return;
    }
  } else {
    fs.mkdirSync(baseFolder, {recursive: true});
  }

  await askBeforeWrite(options, path.join(baseFolder, 'config.ts'), jsonConfig);

  const solidityPaths: string[] = [];
  for (const {payload, contractName} of payloads) {
    const filePath = path.join(baseFolder, `${contractName}.sol`);
    await askBeforeWrite(options, filePath, payload);
    solidityPaths.push(filePath);
  }

  if (solidityPaths.length > 0) {
    execSync(
      `pnpm exec prettier --write ${solidityPaths.map((p) => JSON.stringify(p)).join(' ')}`,
      {
        stdio: 'inherit',
      },
    );
  }
}
