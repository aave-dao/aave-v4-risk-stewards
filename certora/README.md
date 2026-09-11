# Aave V4 Risk Steward verification

This folder contains the Certora rules for [`src/RiskSteward.sol`](../src/RiskSteward.sol),
the permissioned steward that lets a risk council move a bounded set of Aave V4
parameters without a governance vote.

The rules check who may call the steward, the debounce windows it keeps, the
values it writes into the Aave V4 Hub and Spoke, and the fields it must never
touch. 109 rules across eight configurations.

## How the proofs are set up

The suite is split by how much of the protocol a property needs.

Authorization, config storage, revert conditions and debounce accounting only
need the steward itself, so those configurations compile `RiskSteward.sol` alone
and leave the protocol calls unresolved.

Effect and immutability properties need to observe real protocol storage, so
`Immutability.conf` and `ProtocolEffects.conf` link a scene built from the real
aave-v4 `Hub`, `Spoke`, `HubConfigurator`, `SpokeConfigurator` and
`AssetInterestRateStrategy`. The scene contracts in [`harness/Scene.sol`](./harness/Scene.sol) 
are pass-through wrappers: every function body on the write path is the real aave-v4 code.
They exist because the aave-v4 sources import each other as `src/...`, which only
resolves for transitively imported files. Both configurations therefore execute
the full steward → engine → configurator → Hub/Spoke path and read the result
back through the protocol's own getters.

That multi-hop path needs every call site resolved. The shared summaries in
[`specs/common/SceneDispatch.spec`](./specs/common/SceneDispatch.spec) dispatch
both the allowlisted and the forbidden setters, and deliberately keep
`default HAVOC_ALL` so an un-enumerated write path fails loudly instead of
quietly doing nothing.

`PercentageMath.percentMulDown` is the only nonlinear step on the write path and
the dominant SMT cost, so magnitude rules replace it with the mathint model in
[`specs/common/PercentMath.spec`](./specs/common/PercentMath.spec). The model is
not assumed: `PercentMulDownEquivalence.conf` proves it against the real assembly
and pins the exact region where the Solidity reverts and the model does not.

Oracle adapters are out of scene. Each governed adapter field is a plain
store/load pair, so `OracleProperties.spec` mirrors it in a ghost keyed by
`calledContract` and reads the written value back after the call.

## Access control

Config: [`confs/AccessControl.conf`](./confs/AccessControl.conf). Spec: [`specs/AccessControl.spec`](./specs/AccessControl.spec).

| Rule                                | What it checks                                                                        |
| ----------------------------------- | ------------------------------------------------------------------------------------- |
| `councilOnly`                       | Every mutating entrypoint that is not owner-gated reverts for a sender other than `RISK_COUNCIL`. |
| `ownerOnly`                         | `setConfig` and `setAddressRestricted` revert for a non-owner.                        |
| `ownerCannotCallCouncilEntrypoints` | The owner passes a council entrypoint only when the owner is also the council.        |
| `restricted*Reverts`                | Naming an owner-restricted hub, spoke, underlying or oracle reverts. Nine rules, one per council entrypoint. |
| `setAddressRestrictedTouchesOnlyItsKey` | The setter writes its own key and leaves every other address alone.               |

`councilOnly` is parametric over every mutating method, so a new entrypoint that
forgets its modifier fails the rule without anyone editing the spec.

## Config integrity

Config: [`confs/configIntegrity.conf`](./confs/configIntegrity.conf). Spec: [`specs/configIntegrity.spec`](./specs/configIntegrity.spec).

| Rule                               | What it checks                                                             |
| ---------------------------------- | -------------------------------------------------------------------------- |
| `setConfigWritesArg`               | A successful `setConfig` stores exactly its argument, compared field by field. |
| `configIntactExceptSetConfig`      | No other method changes `_config`.                                         |
| `restrictionMapIntactExceptSetter` | No other method changes the restriction map.                               |
| `setConfigEnforcesPolarity`        | A config whose per-field relative/absolute polarity is wrong is rejected, all seventeen fields. |

## Revert conditions

Config: [`confs/RevertConditions.conf`](./confs/RevertConditions.conf). Spec: [`specs/RevertConditions.spec`](./specs/RevertConditions.spec).

| Rule                        | What it checks                                                                    |
| --------------------------- | --------------------------------------------------------------------------------- |
| `*SuccessImpliesInScope`, `dynUpdateSuccessImpliesFeeKept` | A successful update carried the `KEEP_CURRENT` sentinel in every out-of-scope field. Four rules over the hub-IR, caps, reserve and dynamic-update paths. |
| `*SuccessImpliesAllMatched` | Every element's configurator equals the one pinned in the config. Six rules, one per engine path. |
| `*ZeroReverts`              | A governed field may be left alone through the sentinel but never actively set to zero. Six rules. |
| `lstSnapshotMustBeBackwardLooking` | A snapshot ratio above the adapter's live ratio is rejected.               |
| `lstCappedResultReverts`    | An update that would leave the adapter capped is rejected.                        |
| `stableRejectsKeepCurrent`  | The stable path has no sentinel, so the sentinel value itself is rejected.        |
| `pendleRejectsKeepCurrent`  | Same for the Pendle discount rate.                                                |

## Debounce stamping and enforcement

Config: [`confs/DebounceStamping.conf`](./confs/DebounceStamping.conf). Spec: [`specs/transitions/DebounceStamping.spec`](./specs/transitions/DebounceStamping.spec).

| Rule                            | What it checks                                                                  |
| ------------------------------- | -------------------------------------------------------------------------------- |
| `*DebounceStamping`             | A non-sentinel write stamps that field's debounce to the transaction time, a sentinel sibling keeps its old stamp, and every other key is untouched. Five rules, one per debounce mapping. |
| `dynamicAdditionStampsBoth`     | An addition consumes both shared dynamic debounce windows.                       |
| `*DebounceEnforced`             | A successful non-sentinel write means the configured `minDelay` had elapsed since that field's own previous stamp. Nine rules, covering the six protocol paths and the three oracle families. |
| `debouncesIntactExceptUpdaters` | No non-updater method moves any of the six debounce mappings.                    |
| `*DebounceIntactExceptWriters` | Each mapping is preserved by every method outside its designated writer set, including unrelated council updaters. Six rules; dynamic update/addition share one mapping, and the three oracle families share another. |

## Immutability

Config: [`confs/Immutability.conf`](./confs/Immutability.conf). Spec: [`specs/transitions/Immutability.spec`](./specs/transitions/Immutability.spec).

| Rule                            | What it checks                                                            |
| ------------------------------- | -------------------------------------------------------------------------- |
| `hubKeepsOutOfScopeFields`      | The IR path leaves `liquidityFee`, `feeReceiver`, `irStrategy` and `reinvestmentController` alone. |
| `capsKeepsOutOfScopeFields`     | The caps path leaves `riskPremiumThreshold`, `active` and `halted` alone.  |
| `reserveKeepsPriceSource`       | The reserve path never reaches the oracle's price-source setter.           |
| `reserveKeepsFlags`             | The reserve path leaves the four reserve flags alone.                      |
| `dynKeepsLiquidationFee`        | The dynamic-update path never moves `liquidationFee`.                      |
| `dynAddKeepsEarlierKeys`        | An addition appends, so keys already in use keep their values.             |
| `irKeepsSentinelFields`         | A sentinel interest-rate field is never written.                           |
| `addCapDoesNotMoveDrawCap`, `drawCapDoesNotMoveAddCap` | Moving one cap leaves the sibling cap alone.        |
| `collateralFactorKeepsMaxBonus`, `maxBonusKeepsCollateralFactor` | Same for the two dynamic fields.           |
| `liqKeepsSentinelFields`        | A sentinel liquidation field is never written.                             |

`reserveKeepsPriceSource` works differently from its siblings: the price source
lives in the out-of-scene oracle, so the setter is summarized with a ghost flag
and the rule proves the flag is never raised.

## Protocol effects

Config: [`confs/ProtocolEffects.conf`](./confs/ProtocolEffects.conf). Spec: [`specs/transitions/ProtocolEffects.spec`](./specs/transitions/ProtocolEffects.spec).

| Rule                        | What it checks                                                                |
| --------------------------- | ------------------------------------------------------------------------------ |
| `*Magnitude`                | The move from the pre-transaction protocol value is at most the configured `maxPercentChange`, relative or absolute according to the field's polarity. Fourteen rules over the caps, collateral risk, dynamic, liquidation and interest-rate fields. |
| `*Fidelity`                 | A successful non-sentinel submission wrote that exact value into real Hub, Spoke or strategy storage. Fourteen rules, matching the magnitude set. |
| `dynAddLiquidationFeeFrozen`| An addition that changes `liquidationFee` reverts.                            |
| `dynAddRequiresExistingConfig` | An addition must extend an existing dynamic config, never bootstrap one.   |

## Oracle properties

Config: [`confs/OracleProperties.conf`](./confs/OracleProperties.conf). Spec: [`specs/OracleProperties.spec`](./specs/OracleProperties.spec).

| Rule                     | What it checks                                                                 |
| ------------------------ | ------------------------------------------------------------------------------- |
| `*DebounceStamping`      | A successful LST, stable or Pendle update stamps that oracle and leaves every other oracle untouched. Three rules. |
| `*Magnitude`             | The value written to an adapter is within `maxPercentChange` of the value read from that same adapter. Three rules. |

## Arithmetic

Config: [`confs/PercentMulDownEquivalence.conf`](./confs/PercentMulDownEquivalence.conf). Spec: [`specs/PercentMulDownEquivalence.spec`](./specs/PercentMulDownEquivalence.spec).

| Rule                                | What it checks                                                        |
| ----------------------------------- | ---------------------------------------------------------------------- |
| `percentMulDownRevertsOnlyOnOverflow` | The assembly reverts exactly when the intermediate product exceeds 256 bits. |
| `percentMulDownMatchesCVL`          | Wherever the assembly produces a result, the CVL model produces the same one, which also pins the rounding direction. |

This configuration verifies aave-v4's `PercentageMathWrapper`, not `RiskSteward`.
It exists to discharge the summary the magnitude rules rely on.

## Main model assumptions

- Batch claims are bounded by `loop_iter` and optimistic loop unrolling:
  `ProtocolEffects` uses 1, the other steward suites use 3. Per-element
  validation shares no state, so longer batches follow by induction, but the
  runs themselves do not establish arbitrary-batch coverage.
- `DISPATCHER(true)` on the write path is optimistic: it assumes the callee is
  one of the scene contracts. `default HAVOC_ALL` keeps an un-enumerated path
  from passing silently.
- `Hub.setInterestRateData` also runs accrual, whose nonlinear ray math never
  touches the fields these rules assert on and is left `NONDET`.

## Running a proof

The CI workflow runs every `.conf` below `certora/confs/` with Certora CLI
8.19.1 and `solc8.28`.

From the repository root:

```sh
pip install certora-cli==8.19.1
export CERTORAKEY=<your-api-key>
certoraRun certora/confs/ProtocolEffects.conf all
```

Use `--rule <rule-name>` to run only one rule from a config. Configs that set
`split_rules` invoke the local Typechecker jar to enumerate rules, so Java 21 or
newer has to be on `PATH`.

## Running everything

To submit the whole suite locally, use [`runAll.sh`](./runAll.sh). It can be
called from any directory, walks every `.conf` under `certora/confs/` in sorted
order, and forwards its arguments to each `certoraRun`:

```sh
./certora/runAll.sh 
```

It lists any config that failed and exits non-zero.

The full CI setup is in
[`../.github/workflows/certora.yml`](../.github/workflows/certora.yml), which
discovers the configs into one matrix and fails the job if a config points at a
spec path that no longer exists.
