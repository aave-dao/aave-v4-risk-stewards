# Aave V4 RiskSteward — Configurable Params

This document enumerates every risk-relevant parameter exposed by the v4 [`IAaveV4ConfigEngine`](../lib/aave-helpers/lib/aave-address-book/lib/aave-v4/src/config-engine/interfaces/IAaveV4ConfigEngine.sol) and states, per-param, whether the Risk Steward can change it and how the change is gated.

A single Risk Steward instance handles every Hub and every Spoke in the configurator domain. The **owner** sets a single global `Config` (containing `hub`, `spoke`, and `oracle` sub-configs — the `hub` and `spoke` sub-configs each carry a configurator address, and every sub-config carries per-param `minDelay` + `maxPercentChange` + `isChangeRelative` bounds) via `setConfig`. New listings are automatically in scope; specific addresses (hubs, spokes, assets, or oracles) can be excluded via `setAddressRestricted`. The **risk council** is the only address allowed to invoke the update entrypoints. Each tracked param has its own debounce timestamp keyed by `(scope, paramId)`.

### `RiskParamConfig` layout

```solidity
struct RiskParamConfig {
  uint40 minDelay; // seconds between successive updates
  uint208 maxPercentChange; // absolute units OR relative BPS — see isChangeRelative
  bool isChangeRelative; // mode flag; setter enforces the expected mode per field
}
```

The struct packs into a single storage slot (5 + 26 + 1 = 32 bytes). The `isChangeRelative` flag is stored _and_ enforced at setter time — `setConfig` reverts with `InvalidParamConfig` if any field carries the wrong mode (e.g. an IR field marked relative, or a cap marked absolute). The "Change mode" column in the matrices below is the unique correct value for each field.

## Change-validation model

For every numeric param the steward changes:

1. **Sentinel skip** — if the new value carries the matching `EngineFlags.KEEP_CURRENT*` sentinel, the field is left untouched and its timelock is NOT bumped.
2. **Debounce** — the call reverts with `DebounceNotRespected` unless `block.timestamp - lastUpdated >= minDelay` for that param.
3. **Range check** — `|new - current|` must satisfy the `maxPercentChange` bound. Two modes:
   - **Relative**: `|new - current| ≤ maxPercentChange * current / 100_00` (i.e. BPS of current).
   - **Absolute**: `|new - current| ≤ maxPercentChange` in the param's native units.
4. **Zero check** — the steward refuses to set the following params to 0 (regardless of bound) and reverts with `InvalidUpdateToZero`: `collateralFactor`, `maxLiquidationBonus`, `targetHealthFactor`, `healthFactorForMaxBonus`, `liquidationBonusFactor`. Setting these to 0 removes a safety property and should be a governance action, not a steward action. The IR params (`optimalUsageRatio`, `baseDrawnRate`, `rateGrowthBeforeOptimal`, `rateGrowthAfterOptimal`), `collateralRisk`, and the caps (`addCap`, `drawCap`) are allowed to be 0. For the caps, `0` is a valid risk-reducing target on v4 — it blocks only **new** adds/draws (existing positions are untouched) and does not mean "no cap" (no-cap is `MAX_ALLOWED_SPOKE_CAP`); note that because caps are relative, a cap that reaches 0 can no longer be raised by the steward (see the relative-mode note above). For the IR params and `collateralRisk`, `0` is simply a normal value in v4.
5. **Restrictions** — the call reverts with `RestrictedAddress` if any address it touches (hub, spoke, asset, or oracle) is restricted.
6. **Configurator match** — every update carries a `hubConfigurator` / `spokeConfigurator` field; the call reverts with `ConfiguratorMismatch` unless it equals the configurator recorded in `Config.hub` / `Config.spoke`.

For dynamic reserve params (`collateralFactor`, `maxLiquidationBonus`) the bound is sourced from **two independent** `SpokeDynamicConfig` blobs on `SpokeConfig`:

- `SpokeConfig.dynamicUpdate` governs `updateDynamicReserveConfigs` (mutates an existing key — typically stricter).
- `SpokeConfig.dynamicAdd` governs `addDynamicReserveConfigs` (appends a brand-new key — typically looser).

The debounce mapping is unchanged: both modes share the same `(spoke, hub, asset)` keyed `SpokeDynamicDebounce` (per-reserve — shared across all `dynamicConfigKey`s).

## Hub-level params

| Engine struct                                      | Field                            | In scope   | Change mode | Notes                                                                  |
| -------------------------------------------------- | -------------------------------- | ---------- | ----------- | ---------------------------------------------------------------------- |
| `AssetListing`                                     | (all fields)                     | NO         | —           | Listings are governance-only.                                          |
| `AssetConfigUpdate`                                | `hubConfigurator`                | identifier | —           | Must equal `Config.hub.configurator`; else `ConfiguratorMismatch`.     |
| `AssetConfigUpdate`                                | `hub`                            | identifier | —           | Reverts if the hub is restricted.                                      |
| `AssetConfigUpdate`                                | `underlying`                     | identifier | —           | Used to resolve `assetId`; reverts if the asset is restricted.         |
| `AssetConfigUpdate`                                | `liquidityFee`                   | NO         | —           | Must carry `KEEP_CURRENT`; otherwise `ParamChangeNotAllowed`.          |
| `AssetConfigUpdate`                                | `feeReceiver`                    | NO         | —           | Must carry `KEEP_CURRENT_ADDRESS`.                                     |
| `AssetConfigUpdate`                                | `irStrategy`                     | NO         | —           | Strategy address swap is refused — must carry `KEEP_CURRENT_ADDRESS`.  |
| `AssetConfigUpdate`                                | `irData.optimalUsageRatio`       | YES        | absolute    | Sentinel `KEEP_CURRENT_UINT16`.                                        |
| `AssetConfigUpdate`                                | `irData.baseDrawnRate`           | YES        | absolute    | Sentinel `KEEP_CURRENT_UINT32`.                                        |
| `AssetConfigUpdate`                                | `irData.rateGrowthBeforeOptimal` | YES        | absolute    | Sentinel `KEEP_CURRENT_UINT32`.                                        |
| `AssetConfigUpdate`                                | `irData.rateGrowthAfterOptimal`  | YES        | absolute    | Sentinel `KEEP_CURRENT_UINT32`.                                        |
| `AssetConfigUpdate`                                | `reinvestmentController`         | NO         | —           | Must carry `KEEP_CURRENT_ADDRESS`.                                     |
| `SpokeToAssetsAddition`                            | (all fields)                     | NO         | —           | Spoke registration is governance-only.                                 |
| `SpokeConfigUpdate`                                | `hubConfigurator`                | identifier | —           | Must equal `Config.hub.configurator`; else `ConfiguratorMismatch`.     |
| `SpokeConfigUpdate`                                | `hub`                            | identifier | —           | Reverts if the hub is restricted.                                      |
| `SpokeConfigUpdate`                                | `underlying`                     | identifier | —           | Used to resolve `assetId`; reverts if the asset is restricted.         |
| `SpokeConfigUpdate`                                | `spoke`                          | identifier | —           | Reverts if the spoke is restricted.                                    |
| `SpokeConfigUpdate`                                | `addCap`                         | YES        | relative    | Sentinel `KEEP_CURRENT`. `0` allowed (blocks new adds; not "no cap").  |
| `SpokeConfigUpdate`                                | `drawCap`                        | YES        | relative    | Sentinel `KEEP_CURRENT`. `0` allowed (blocks new draws; not "no cap"). |
| `SpokeConfigUpdate`                                | `riskPremiumThreshold`           | NO         | —           | Must carry `KEEP_CURRENT`.                                             |
| `SpokeConfigUpdate`                                | `active`                         | NO         | —           | Must carry `KEEP_CURRENT` (boolean).                                   |
| `SpokeConfigUpdate`                                | `halted`                         | NO         | —           | Must carry `KEEP_CURRENT` (boolean).                                   |
| `AssetHalt`, `AssetDeactivation`, `AssetCapsReset` | (all fields)                     | NO         | —           | Emergency / governance-only.                                           |
| `SpokeDeactivation`, `SpokeCapsReset`              | (all fields)                     | NO         | —           | Emergency / governance-only.                                           |

## Spoke-level params

| Engine struct                  | Field                                                             | In scope   | Change mode | Notes                                                                                                                                                               |
| ------------------------------ | ----------------------------------------------------------------- | ---------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ReserveListing`               | (all fields)                                                      | NO         | —           | Listings are governance-only.                                                                                                                                       |
| `ReserveConfigUpdate`          | `spokeConfigurator`                                               | identifier | —           | Must equal `Config.spoke.configurator`; else `ConfiguratorMismatch`.                                                                                                |
| `ReserveConfigUpdate`          | `spoke`                                                           | identifier | —           | Reverts if the spoke is restricted.                                                                                                                                 |
| `ReserveConfigUpdate`          | `hub`                                                             | identifier | —           | Reverts if the hub is restricted.                                                                                                                                   |
| `ReserveConfigUpdate`          | `underlying`                                                      | identifier | —           | Resolves to a `reserveId`; reverts if the asset is restricted.                                                                                                      |
| `ReserveConfigUpdate`          | `priceSource`                                                     | NO         | —           | Must carry `KEEP_CURRENT_ADDRESS`.                                                                                                                                  |
| `ReserveConfigUpdate`          | `collateralRisk`                                                  | YES        | absolute    | Sentinel `KEEP_CURRENT`.                                                                                                                                            |
| `ReserveConfigUpdate`          | `paused`                                                          | NO         | —           | Must carry `KEEP_CURRENT`.                                                                                                                                          |
| `ReserveConfigUpdate`          | `frozen`                                                          | NO         | —           | Must carry `KEEP_CURRENT`.                                                                                                                                          |
| `ReserveConfigUpdate`          | `borrowable`                                                      | NO         | —           | Must carry `KEEP_CURRENT`.                                                                                                                                          |
| `ReserveConfigUpdate`          | `receiveSharesEnabled`                                            | NO         | —           | Must carry `KEEP_CURRENT`.                                                                                                                                          |
| `LiquidationConfigUpdate`      | `spokeConfigurator`                                               | identifier | —           | Must equal `Config.spoke.configurator`; else `ConfiguratorMismatch`.                                                                                                |
| `LiquidationConfigUpdate`      | `spoke`                                                           | identifier | —           | Reverts if the spoke is restricted.                                                                                                                                 |
| `LiquidationConfigUpdate`      | `targetHealthFactor`                                              | YES        | relative    | WAD scaled. Sentinel `KEEP_CURRENT`.                                                                                                                                |
| `LiquidationConfigUpdate`      | `healthFactorForMaxBonus`                                         | YES        | relative    | WAD scaled. Sentinel `KEEP_CURRENT`.                                                                                                                                |
| `LiquidationConfigUpdate`      | `liquidationBonusFactor`                                          | YES        | absolute    | BPS. Sentinel `KEEP_CURRENT`.                                                                                                                                       |
| `DynamicReserveConfigAddition` | `spokeConfigurator`/`spoke`/`hub`/`underlying`                    | identifier | —           | Resolves `reserveId`.                                                                                                                                               |
| `DynamicReserveConfigAddition` | `dynamicConfig.collateralFactor`                                  | YES        | absolute    | Bound from `SpokeConfig.dynamicAdd`. Validated against the latest existing key for that reserve (read from `ISpoke(spoke).getReserve(reserveId).dynamicConfigKey`). |
| `DynamicReserveConfigAddition` | `dynamicConfig.maxLiquidationBonus`                               | YES        | absolute    | Bound from `SpokeConfig.dynamicAdd`. Validated against the latest existing key.                                                                                     |
| `DynamicReserveConfigAddition` | `dynamicConfig.liquidationFee`                                    | NO         | —           | Must equal the latest existing key's `liquidationFee`; otherwise `ParamChangeNotAllowed`.                                                                           |
| `DynamicReserveConfigUpdate`   | `spokeConfigurator`/`spoke`/`hub`/`underlying`/`dynamicConfigKey` | identifier | —           | Resolves `reserveId` and selects the key being updated.                                                                                                             |
| `DynamicReserveConfigUpdate`   | `collateralFactor`                                                | YES        | absolute    | Bound from `SpokeConfig.dynamicUpdate` (typically stricter than `dynamicAdd`). Sentinel `KEEP_CURRENT`. Per-reserve debounce timestamp (shared across all keys).    |
| `DynamicReserveConfigUpdate`   | `maxLiquidationBonus`                                             | YES        | absolute    | Bound from `SpokeConfig.dynamicUpdate`. Sentinel `KEEP_CURRENT`. Per-reserve debounce timestamp (shared across all keys).                                           |
| `DynamicReserveConfigUpdate`   | `liquidationFee`                                                  | NO         | —           | Must carry `KEEP_CURRENT`.                                                                                                                                          |
| `PositionManagerUpdate`        | (all fields)                                                      | NO         | —           | Governance-only.                                                                                                                                                    |

## CAPO oracle params

These are the steward entrypoints that talk to the [aave-capo](https://github.com/bgd-labs/aave-capo) price-cap adapters. Mirrors the v3 RiskSteward 1:1 — same adapter contracts, same setter signatures, same validation shape. Bounds come from `Config.oracle` set by `setConfig`; per-oracle debounce in `_oracleDebounces[oracle]`. Each entrypoint reverts with `RestrictedAddress` if the target oracle is restricted.

| Entrypoint                  | Adapter interface                               | Touched field                 | Change mode | Notes                                                                                                                                                                                                 |
| --------------------------- | ----------------------------------------------- | ----------------------------- | ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `updateLstPriceCaps`        | `IPriceCapAdapter.setCapParameters`             | `maxYearlyRatioGrowthPercent` | relative    | Also requires non-zero `snapshotRatio` / `snapshotTimestamp` / `maxYearlyRatioGrowthPercent`; `snapshotRatio` must be ≤ `getRatio()`; reverts with `InvalidPriceCapUpdate` if `isCapped()` post-call. |
| `updateStablePriceCaps`     | `IPriceCapAdapterStable.setPriceCap`            | `priceCap`                    | relative    | Non-zero.                                                                                                                                                                                             |
| `updatePendleDiscountRates` | `IPendlePriceCapAdapter.setDiscountRatePerYear` | `discountRatePerYear`         | absolute    | Non-zero.                                                                                                                                                                                             |

## Access manager / position manager / spoke registration / emergency methods

| Engine method                                           | In scope |
| ------------------------------------------------------- | -------- |
| `executePositionManagerSpokeRegistrations`              | NO       |
| `executePositionManagerRoleRenouncements`               | NO       |
| `executeRoleMemberships`                                | NO       |
| `executeRoleUpdates`                                    | NO       |
| `executeTargetFunctionRoleUpdates`                      | NO       |
| `executeTargetAdminDelayUpdates`                        | NO       |
| `executeHubAssetHalts`, `…Deactivations`, `…CapsResets` | NO       |
| `executeHubSpokeDeactivations`, `…CapsResets`           | NO       |

All of these are emergency / governance-only operations and are NOT exposed via the steward.

## Restrictions

The owner marks any address restricted via a single flat mapping; any council call that touches a restricted address reverts with `RestrictedAddress`.

| Method                             | Storage key                  | Restricting it blocks                                                                                                                                                                                           |
| ---------------------------------- | ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `setAddressRestricted(addr, bool)` | `_restrictedAddresses[addr]` | every update touching `addr` — a hub (all its updates), a spoke (all spoke-side updates + hub-spoke caps), an asset (every update touching it, across all spokes/hubs), or a CAPO oracle (its price-cap update) |

This is deliberately coarse — there is no per-`(spoke, hub)` or per-reserve granularity. Restricting a spoke or asset applies everywhere it appears, which is acceptable for an owner-held emergency exclusion. E.g. GHO should be restricted outright since it has its own dedicated stewards.

## Timelock storage

Each scope has a dedicated Debounce struct with one named `uint40` field per tracked param. The structs are defined in [`IRiskSteward`](../src/interfaces/IRiskSteward.sol) so external readers can decode them directly.

| Scope             | Mapping shape                                                          | Struct fields                                                                                         |
| ----------------- | ---------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Hub asset IR      | `_hubAssetDebounces[hub][asset]` → `HubAssetDebounce`                  | optimalUsageRatio, baseDrawnRate, rateGrowthBeforeOptimal, rateGrowthAfterOptimal                     |
| Hub spoke caps    | `_hubSpokeAssetDebounces[hub][spoke][asset]` → `HubSpokeAssetDebounce` | addCap, drawCap                                                                                       |
| Spoke reserve     | `_spokeReserveDebounces[spoke][hub][asset]` → `SpokeReserveDebounce`   | collateralRisk                                                                                        |
| Spoke dynamic     | `_spokeDynamicDebounces[spoke][hub][asset]` → `SpokeDynamicDebounce`   | collateralFactor, maxLiquidationBonus (per-reserve — shared by additions and updates across all keys) |
| Spoke liquidation | `_spokeLiquidationDebounces[spoke]` → `SpokeLiquidationDebounce`       | targetHealthFactor, healthFactorForMaxBonus, liquidationBonusFactor                                   |
| CAPO oracle       | `_oracleDebounces[oracle]` → `uint40`                                  | single shared timestamp across LST / stable / Pendle updates on the same oracle                       |

External getters: `getHubAssetDebounce`, `getHubSpokeAssetDebounce`, `getSpokeReserveDebounce`, `getSpokeDynamicDebounce`, `getSpokeLiquidationDebounce`, `getOracleDebounce`.
