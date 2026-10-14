/*
 * ReduceRiskStewardWrapper — Access control and reduce-only checks.
 *
 * Property: only RISK_COUNCIL can call the wrapper, and a successful call only
 * forwarded updates that lower the risk against the values read from the real
 * Hub and Spoke before the call.
 *
 * The wrapped steward is out of scene, so its call is left unresolved. Every
 * assertion is over calldata and pre-call snapshots, so whatever that call does
 * cannot weaken them.
 */

using HubHarness as hubH;
using SpokeHarness as spokeH;

methods {
    function RISK_COUNCIL() external returns (address) envfree;

    function hubH.getAssetId(address underlying) external returns (uint256) envfree;
    function hubH.getSpokeConfig(uint256 assetId, address spoke) external returns (IHub.SpokeConfig) envfree;
    function spokeH.getReserveId(address hub, uint256 assetId) external returns (uint256) envfree;
    function spokeH.getDynamicReserveConfig(uint256 reserveId, uint32 dynamicConfigKey) external returns (ISpoke.DynamicReserveConfig) envfree;
    function spokeH.latestDynamicConfigKey(uint256 reserveId) external returns (uint32) envfree;

    // The wrapper's reads, routed to the scene Hub and Spoke. DISPATCHER(true) is
    // optimistic: it assumes every hub and spoke named in the batch is the scene one.
    function _.getAssetId(address) external => DISPATCHER(true);
    function _.getSpokeConfig(uint256, address) external => DISPATCHER(true);
    function _.getReserveId(address, uint256) external => DISPATCHER(true);
    function _.getReserve(uint256) external => DISPATCHER(true);
    function _.getDynamicReserveConfig(uint256, uint32) external => DISPATCHER(true);
}

// EngineFlags.KEEP_CURRENT = type(uint256).max - 652.
definition KEEP_CURRENT() returns uint256 = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd73;

// ---------------------------------------------------------------------------
// Access control
// ---------------------------------------------------------------------------

// Every mutating entrypoint reverts for a sender other than RISK_COUNCIL.
rule councilOnly(method f, env e) filtered { f -> !f.isView && !f.isPure } {
    require e.msg.sender != RISK_COUNCIL();
    calldataarg a;

    // Execute the call
    f@withrevert(e, a);

    // Assert that a non-council caller reverts
    assert lastReverted;
}

// ---------------------------------------------------------------------------
// reduceHubSpokeCaps
// ---------------------------------------------------------------------------

// A successful call only carried an add cap that is KEEP_CURRENT or strictly lower.
rule reduceCapsSuccessImpliesAddCapLowered(env e, IAaveV4ConfigEngine.SpokeConfigUpdate[] updates, uint256 i) {
    require i < updates.length, "Make sure i is in bounds";

    // Fetch the add cap before the update
    mathint before = hubH.getSpokeConfig(hubH.getAssetId(updates[i].underlying), updates[i].spoke).addCap;

    // Execute the update
    reduceHubSpokeCaps(e, updates);

    // Assert that success implies the add cap was kept or lowered
    assert updates[i].addCap == KEEP_CURRENT() || updates[i].addCap < before;
}

// A successful call only carried a draw cap that is KEEP_CURRENT or strictly lower.
rule reduceCapsSuccessImpliesDrawCapLowered(env e, IAaveV4ConfigEngine.SpokeConfigUpdate[] updates, uint256 i) {
    require i < updates.length, "Make sure i is in bounds";

    // Fetch the draw cap before the update
    mathint before = hubH.getSpokeConfig(hubH.getAssetId(updates[i].underlying), updates[i].spoke).drawCap;

    // Execute the update
    reduceHubSpokeCaps(e, updates);

    // Assert that success implies the draw cap was kept or lowered
    assert updates[i].drawCap == KEEP_CURRENT() || updates[i].drawCap < before;
}

// ---------------------------------------------------------------------------
// addReducedDynamicReserveConfigs
// ---------------------------------------------------------------------------

// A successful call only appended a collateral factor strictly lower than the latest key's.
rule addReducedSuccessImpliesCollateralFactorLowered(env e, IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions, uint256 i) {
    require i < additions.length, "Make sure i is in bounds";

    // Fetch the latest dynamic config before the addition
    uint256 reserveId = spokeH.getReserveId(additions[i].hub, hubH.getAssetId(additions[i].underlying));
    ISpoke.DynamicReserveConfig latest = spokeH.getDynamicReserveConfig(reserveId, spokeH.latestDynamicConfigKey(reserveId));

    // Execute the addition
    addReducedDynamicReserveConfigs(e, additions);

    // Assert that success implies the collateral factor was lowered
    assert additions[i].dynamicConfig.collateralFactor < latest.collateralFactor;
}

// A successful call never appended a max liquidation bonus below the latest key's.
rule addReducedSuccessImpliesBonusNotLowered(env e, IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions, uint256 i) {
    require i < additions.length, "Make sure i is in bounds";

    // Fetch the latest dynamic config before the addition
    uint256 reserveId = spokeH.getReserveId(additions[i].hub, hubH.getAssetId(additions[i].underlying));
    ISpoke.DynamicReserveConfig latest = spokeH.getDynamicReserveConfig(reserveId, spokeH.latestDynamicConfigKey(reserveId));

    // Execute the addition
    addReducedDynamicReserveConfigs(e, additions);

    // Assert that success implies the max liquidation bonus was kept or raised
    assert additions[i].dynamicConfig.maxLiquidationBonus >= latest.maxLiquidationBonus;
}

// A successful call never raised the liquidation penalty (maxLiquidationBonus * collateralFactor).
rule addReducedSuccessImpliesPenaltyNotRaised(env e, IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions, uint256 i) {
    require i < additions.length, "Make sure i is in bounds";

    // Fetch the latest dynamic config before the addition
    uint256 reserveId = spokeH.getReserveId(additions[i].hub, hubH.getAssetId(additions[i].underlying));
    ISpoke.DynamicReserveConfig latest = spokeH.getDynamicReserveConfig(reserveId, spokeH.latestDynamicConfigKey(reserveId));

    // Execute the addition
    addReducedDynamicReserveConfigs(e, additions);

    // Assert that success implies the liquidation penalty was kept or lowered
    assert additions[i].dynamicConfig.maxLiquidationBonus * additions[i].dynamicConfig.collateralFactor
        <= latest.maxLiquidationBonus * latest.collateralFactor;
}
