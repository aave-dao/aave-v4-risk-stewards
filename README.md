# Aave V4 Generalized Risk Stewards (AGRS-V4)

A single `RiskSteward` contract lets risk service providers push hardly-constrained risk parameter updates across every hub and spoke of the v4 hub/spoke deployment, reducing governance overhead.

<br>

## Specification

The `RiskSteward` is a smart contract to which the Aave Governance grants the relevant `AccessManager` roles on the `HubConfigurator` and `SpokeConfigurator`. Specifically, the steward needs:

- `Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE` — required to call all `HubConfigurator` entrypoints used by the steward (`updateInterestRateData`, `updateSpokeCaps` / `updateSpokeAddCap` / `updateSpokeDrawCap`).
- `Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE` — required to call all `SpokeConfigurator` entrypoints used by the steward (`updateCollateralRisk`, `updateDynamicReserveConfig`, `addDynamicReserveConfig`, `updateLiquidationConfig` and its per-field setters).

A single steward instance manages **many** hubs and **many** spokes of the v4 Hub/Spoke deployment. The owner registers each Hub and Spoke individually with its own `RiskParamConfig` bounds (`minDelay` + `maxPercentChange` + `isChangeRelative` per param; the setter enforces the expected mode per field). Registering a hub is achieved by calling `setHubConfig(hub, HubConfig)`; same for spokes via `setSpokeConfig`. Removing a registration is `setHubConfig(hub, zero)` (sugar: `removeHubConfig(hub)`).

<br/>

The following risk params can be changed by the v4 `RiskSteward`:

**Hub-asset interest rate** (per `(hub, asset)`)

- optimalUsageRatio
- baseDrawnRate
- rateGrowthBeforeOptimal
- rateGrowthAfterOptimal

**Hub-spoke caps** (per `(hub, spoke, asset)`)

- addCap
- drawCap

**Spoke reserve config** (per `(spoke, hub, asset)`)

- collateralRisk

**Spoke dynamic reserve config** (per `(spoke, hub, asset, dynamicConfigKey)`)

- collateralFactor
- maxLiquidationBonus

Both updating an existing dynamic config key (`updateDynamicReserveConfigs`) and appending a new one (`addDynamicReserveConfigs`) are supported. The two modes are governed by **independent** `SpokeDynamicConfig` bounds — `SpokeConfig.dynamicUpdate` (typically stricter, mutates a tier users may be positioned in) and `SpokeConfig.dynamicAdd` (typically looser, appends a brand-new tier).

**Spoke-global liquidation config** (per `spoke`)

- targetHealthFactor
- healthFactorForMaxBonus
- liquidationBonusFactor

Refused fields the steward will not change (`ParamChangeNotAllowed`): `liquidityFee`, `riskPremiumThreshold`, `liquidationFee`, every bool toggle (`active`/`halted`/`paused`/`frozen`/`borrowable`/`receiveSharesEnabled`), `priceSource`, `irStrategy` address swap, `feeReceiver`, `reinvestmentController`, all listings, all halts/deactivations/resets, position-manager and access-manager admin. The full per-field matrix lives in [docs/ConfigurableParams.md](./docs/ConfigurableParams.md).

#### Min Delay:

For each risk param, `minDelay` can be configured, which is the minimum amount of delay (denominated in seconds) required before pushing another update for the risk param. Please note that this is specific for a risk param and includes both in upwards and downwards direction. Ex. after increasing `collateralFactor` by 0.5%, we must wait by `minDelay` before either increasing it again or decreasing it. Debounce is keyed per `(scope, param)`. For dynamic reserve configs the debounce is **per-reserve** (`(spoke, hub, asset)`), shared across all `dynamicConfigKey`s and across both `addDynamicReserveConfigs` and `updateDynamicReserveConfigs` — so an addition and a subsequent update (on any key) of the same reserve are rate-limited together.

#### Max Percent Change:

For each risk param, `maxPercentChange` is the maximum percent change allowed (both upwards and downwards) for the risk param using the RiskStewards.

- Hub-spoke caps (addCap, drawCap), spoke collateralRisk, spoke-global targetHealthFactor and healthFactorForMaxBonus: `maxPercentChange` is **relative** and is denominated in BPS. (Ex. `50_00` for ±50% relative change).
  For example, with a spoke's current addCap at 1_000_000 and `maxPercentChange` configured at `50_00`, the max addCap the steward can set is 1_500_000 and the minimum 500_000.

- Hub-asset IR params (optimalUsageRatio, baseDrawnRate, rateGrowthBeforeOptimal, rateGrowthAfterOptimal): `maxPercentChange` is in **absolute** values, denominated in BPS. (Ex. `1_00` for ±1% change in optimalUsageRatio).
  For example, for a current optimalUsageRatio of an asset configured at 90_00 (90%) and `maxPercentChange` configured at `1_00`, the max optimalUsageRatio that can be configured is 91_00 (91%) and the minimum 89_00 (89%).

- Spoke dynamic params (collateralFactor, maxLiquidationBonus): `maxPercentChange` is in **absolute** values, denominated in BPS — read from `SpokeConfig.dynamicUpdate` for `updateDynamicReserveConfigs` and `SpokeConfig.dynamicAdd` for `addDynamicReserveConfigs`. For additions the change is validated against the values of the **latest existing** dynamicConfigKey on that reserve (read via `ISpoke.getReserve(reserveId).dynamicConfigKey`), and the new entry's `liquidationFee` must equal the latest existing key's `liquidationFee` (otherwise `ParamChangeNotAllowed`).

- Spoke-global liquidationBonusFactor: `maxPercentChange` is in **absolute** values, denominated in BPS.

After the activation proposal, these params can only be changed by the governance by calling the `setHubConfig` / `setSpokeConfig` methods.

_Note: The Risk Stewards will not allow setting the following params to 0 no matter if the `maxPercentChange` has been configured to 100%: `addCap`, `drawCap`, `collateralFactor`, `maxLiquidationBonus`, `targetHealthFactor`, `healthFactorForMaxBonus`, `liquidationBonusFactor` — setting any of these to 0 effectively halts the asset or removes a safety property and should be a governance action. The Risk Stewards will however allow setting the IR params and `collateralRisk` to 0, since `0` is a normal configuration on v4 (e.g. WETH/CORE_HUB currently has `baseDrawnRate = 0`, and WETH/MAIN_SPOKE has `collateralRisk = 0`)._

_Note: For params using **relative** change mode (caps, collateralRisk, targetHealthFactor, healthFactorForMaxBonus), once the on-chain value reaches 0 the steward can no longer change it. The bound is `maxDiff = current * maxPercentChange / 100_00`, which is 0 when `current = 0`, so every non-zero target fails the range check with `UpdateNotInRange`. Moving a relative-mode param off 0 requires governance via the configurator directly._

#### Batch validation semantics (storage-anchored):

Every council entry-point takes an array. Both the debounce check and the `maxPercentChange` range check for each array entry are evaluated against **on-chain storage state**, not against the post-state of earlier entries in the same array. Two consequences:

- **Range**: each entry must independently land within ±`maxPercentChange` of the pre-tx on-chain value. The council cannot chain multiple smaller-than-bound entries to walk further than `maxPercentChange` in a single tx. The engine then applies the array in order, so the last entry wins on-chain — intermediate entries are redundant from the final-state perspective but still bounded.
- **Debounce**: every entry sees the same pre-tx `lastUpdated`, so a multi-entry batch passes or fails the `minDelay` check uniformly. After the call, the timelock is stamped once at `block.timestamp`, so any follow-up batch within the same `minDelay` window correctly reverts with `DebounceNotRespected`.

#### Restricted Hubs, Spokes, (Spoke, Hub) tuples, and Reserves:

Specific entities can be restricted on the RiskSteward by calling the owner methods. Once restricted, the steward will reject any update that touches that entity:

- `setHubRestricted(hub, true)` — blocks every update targeting the given hub.
- `setSpokeRestricted(spoke, true)` — blocks every spoke-side update on the given spoke and every hub-spoke cap update routed to it.
- `setSpokeHubRestricted(spoke, hub, true)` — blocks every update whose input struct carries both that spoke and that hub.
- `setReserveRestricted(spoke, hub, asset, true)` — blocks every update touching that specific reserve.

<br>

## Security

- Audits: TBD (pending v4 deployment).

<br>

## Setup

```sh
pnpm install
forge install
pnpm prepare
```

<br>

## Test

```sh
forge test
```

<br>

## Coverage

```sh
make coverage
```

<br>

## Instructions and FAQ's

### How do I use the generator tooling to bootstrap the update?

Run `pnpm run generate` on your terminal in order to start the generator. The generator is a CLI tool which will generate the required helper contract which can be then run to submit updates to the risk steward. The generator will generate the helper contract in the `src/updates` directory.

To get a full list of available commands run `pnpm run generate --help`

```sh
pnpm run generate --help
$ tsx generator/cli --help
Usage: proposal-generator [options]

CLI to generate aave v4 risk steward proposals

Options:
  -V, --version              output the version number
  -f, --force                force creation (might overwrite existing files)
  -p, --pools <pools...>     (choices: "AaveV4Ethereum")
  -t, --title <string>       aip title
  -a, --author <string>      author
  -d, --discussion <string>  forum link
  -c, --configFile <string>  path to config file
  -h, --help                 display help for command
```

Running `pnpm run generate` you should be able to do the risk updates:

```bash
pnpm run generate

$ tsx generator/cli
? Chains this proposal targets AaveV4Ethereum
? Short title of your steward update that will be used as contract name (please refrain from including author or date) TestDynamicReserveUpdate
? Author of your proposal Aave Labs
? Link to forum discussion (Link to forum)

? What do you want to do on AaveV4Ethereum? (Press <space> to select, <a> to toggle all, <i> to invert selection, and <enter> to proceed)
❯◯ HubAssetIrUpdates (optimalUsageRatio, baseDrawnRate, rateGrowthBeforeOptimal, rateGrowthAfterOptimal)
 ◯ HubSpokeCapsUpdates (addCap, drawCap)
 ◯ ReserveConfigUpdates (collateralRisk)
 ◉ DynamicReserveConfigUpdates (collateralFactor, maxLiquidationBonus)
 ◯ DynamicReserveConfigAdditions (collateralFactor, maxLiquidationBonus, liquidationFee)
 ◯ SpokeLiquidationConfigUpdates (targetHealthFactor, healthFactorForMaxBonus, liquidationBonusFactor)

? Select the hub Core
? Select the spoke Main
? Select the asset WETH
  Fetching info for WETH on Main / Core
? dynamicConfigKey 0
? collateralFactor 80 %
? maxLiquidationBonus 105 %
✨  Done in 38.32s.
```

The generator generates the scripts for doing the updates in `src/updates` directory.

The script can be executed by running: `make run-script network=mainnet contract=scripts/examples/EthereumExample.sol:EthereumExample broadcast=false generate_diff=true skip_timelock=false` where:

- `broadcast=` determines if the calldata should be sent to safe
- `generate_diff=` determines if diff report should be generated
- `skip_timelock=` determines if timelock errors should revert the script, helpful in generating diff report / calldata when the current timelock has not ended.

The script also emits the calldata for doing the update in the console which can be used on the safe manually as well.

### Before I will submit anything to sign, how do I test out the update, or get visibility from what will happen?

Running the script generated on the contracts in `src/updates` directory with `generate_diff=true`, there will be files written into the diffs directory, which will show the params changed on the hub/spoke by the update, with before and after values which can be validated with what update is expected.

### Once I have full assurance it looks correct, how do I submit to Safe?

Once the script on the comments of the generated contract has been run with `broadcast=false`, there will be calldata emitted on the console with the contract to call. Please copy the calldata and the contract to execute it on (i.e. RiskSteward) from the console and input it on the [gnosis safe UI](https://app.safe.global/) transaction builder.

If you wish to not use the UI and send the update directly please put `broadcast=true` when running the script to directly broadcast the tx using the gnosis safe.

## License

Copyright © 2026, Aave DAO, represented by its governance smart contracts.
