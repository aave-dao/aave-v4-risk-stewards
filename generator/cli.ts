import 'dotenv/config';
import path from 'path';
import {Command, Option} from 'commander';
import {input, checkbox} from '@inquirer/prompts';
import {createPublicClient, http} from 'viem';
import {mainnet} from 'viem/chains';
import {getBlockNumber} from 'viem/actions';

import {CHAIN_TO_CHAIN_ID, getDate, pascalCase} from './common';
import {
  CHAINS,
  ChainCache,
  ChainConfigs,
  ChainIdentifier,
  ConfigFile,
  FEATURE,
  Options,
} from './types';
import {hubAssetIrUpdates} from './features/hubAssetIrUpdates';
import {hubSpokeCapsUpdates} from './features/hubSpokeCapsUpdates';
import {reserveConfigUpdates} from './features/reserveConfigUpdates';
import {dynamicReserveConfigUpdates} from './features/dynamicReserveConfigUpdates';
import {dynamicReserveConfigAdditions} from './features/dynamicReserveConfigAdditions';
import {spokeLiquidationConfigUpdates} from './features/spokeLiquidationConfigUpdates';
import {generateFiles, writeFiles} from './generator';

const program = new Command();

program
  .name('proposal-generator')
  .description('CLI to generate Aave v4 RiskSteward payloads')
  .version('1.0.0')
  .addOption(new Option('-f, --force', 'force creation (might overwrite existing files)'))
  .addOption(new Option('-c, --chains <chains...>').choices([...CHAINS]))
  .addOption(new Option('-t, --title <string>', 'payload title'))
  .addOption(new Option('-a, --author <string>', 'author'))
  .addOption(new Option('-d, --discussion <string>', 'forum link'))
  .addOption(new Option('--configFile <string>', 'path to config file'))
  .allowExcessArguments(false)
  .parse(process.argv);

let options = program.opts<Options>();
let chainConfigs: ChainConfigs = {};

const FEATURE_MODULES_V4 = [
  hubAssetIrUpdates,
  hubSpokeCapsUpdates,
  reserveConfigUpdates,
  dynamicReserveConfigUpdates,
  dynamicReserveConfigAdditions,
  spokeLiquidationConfigUpdates,
];

const CHAIN_BY_ID = {[mainnet.id]: mainnet} as const;

async function generateDeterministicChainCache(chain: ChainIdentifier): Promise<ChainCache> {
  const viemChain = CHAIN_BY_ID[CHAIN_TO_CHAIN_ID[chain] as keyof typeof CHAIN_BY_ID];
  const client = createPublicClient({chain: viemChain, transport: http()});
  return {blockNumber: Number(await getBlockNumber(client))};
}

async function fetchChainOptions(chain: ChainIdentifier) {
  chainConfigs[chain] = {
    configs: {},
    artifacts: [],
    cache: await generateDeterministicChainCache(chain),
  };

  const features = await checkbox({
    message: `What do you want to do on ${chain}?`,
    choices: FEATURE_MODULES_V4.map((m) => ({value: m.value, name: m.description})),
  });
  for (const feature of features) {
    const module = FEATURE_MODULES_V4.find((m) => m.value === feature)!;
    const cfg = await module.cli({options, chain, cache: chainConfigs[chain]!.cache});
    (chainConfigs[chain]!.configs as Record<FEATURE, unknown>)[feature] = cfg;
    chainConfigs[chain]!.artifacts.push(
      module.build({options, chain, cache: chainConfigs[chain]!.cache, cfg: cfg as any}),
    );
  }
}

if (options.configFile) {
  const {config: cfgFile}: {config: ConfigFile} = await import(
    path.join(process.cwd(), options.configFile)
  );
  options = {...options, ...cfgFile.rootOptions};
  chainConfigs = cfgFile.chainOptions as any;
  for (const chain of options.chains) {
    if (chainConfigs[chain]) {
      chainConfigs[chain]!.artifacts = [];
      for (const feature of Object.keys(chainConfigs[chain]!.configs) as FEATURE[]) {
        const module = FEATURE_MODULES_V4.find((m) => m.value === feature)!;
        chainConfigs[chain]!.artifacts.push(
          module.build({
            options,
            chain,
            cache: chainConfigs[chain]!.cache,
            cfg: (chainConfigs[chain]!.configs as any)[feature],
          }),
        );
      }
    } else {
      await fetchChainOptions(chain);
    }
  }
} else {
  options.chains = await checkbox({
    message: 'Chains this payload targets',
    choices: CHAINS.map((v) => ({name: v, value: v})),
    required: true,
  });

  if (!options.title) {
    options.title = await input({
      message: 'Short title of your steward update — used as the contract name (no author or date)',
      validate(input) {
        if (input.length == 0) return "Your title can't be empty";
        if (input.trim().length > 80) return 'Your title is too long';
        return true;
      },
    });
  }
  options.shortName = pascalCase(options.title);
  options.date = getDate();

  if (!options.author) {
    options.author = await input({
      message: 'Author of your payload',
      validate(input) {
        if (input.length == 0) return "Your author can't be empty";
        return true;
      },
    });
  }

  if (!options.discussion) {
    options.discussion = await input({message: 'Link to forum discussion'});
  }

  for (const chain of options.chains) {
    await fetchChainOptions(chain);
  }
}

try {
  const files = await generateFiles(options, chainConfigs);
  await writeFiles(options, files);
} catch (e) {
  console.log(JSON.stringify({options, chainConfigs}, null, 2));
  throw e;
}
