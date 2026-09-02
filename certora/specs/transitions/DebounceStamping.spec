/*
 * RiskSteward — State transitions: debounce stamping and enforcement.
 *
 * Stamping : a successful non-KEEP_CURRENT write stamps that field's debounce to now,
 *            and leaves KEEP_CURRENT siblings and every other key untouched.
 * Enforcement: stamp timestamp is respected => a successful write means minDelay had
 *            elapsed since the field's own previous stamp.
 *
 * Each rule tests element 0 of the batch and reads the rest through the quantified
 * key-isolation requires below, so the properties hold for batches, not just singletons.
 */

methods {
    function RISK_COUNCIL() external returns (address) envfree;
    function getConfig() external returns (IRiskSteward.Config) envfree;

    function getHubAssetDebounce(address hub, address asset) external returns (IRiskSteward.HubAssetDebounce) envfree;
    function getHubSpokeAssetDebounce(address hub, address spoke, address asset) external returns (IRiskSteward.HubSpokeAssetDebounce) envfree;
    function getSpokeReserveDebounce(address spoke, address hub, address asset) external returns (IRiskSteward.SpokeReserveDebounce) envfree;
    function getSpokeDynamicDebounce(address spoke, address hub, address asset) external returns (IRiskSteward.SpokeDynamicDebounce) envfree;
    function getSpokeLiquidationDebounce(address spoke) external returns (IRiskSteward.SpokeLiquidationDebounce) envfree;
    function getOracleDebounce(address oracle) external returns (uint40) envfree;

    // Protocol reads used by validation and engine routing.
    function _.getAssetId(address) external => NONDET;
    function _.getAssetConfig(uint256) external => NONDET;
    function _.getInterestRateData(uint256) external => NONDET;
    function _.getSpokeConfig(uint256, address) external => NONDET;
    function _.getReserveId(address, uint256) external => NONDET;
    function _.getReserveConfig(uint256) external => NONDET;
    function _.getDynamicReserveConfig(uint256, uint32) external => NONDET;
    function _.getReserve(uint256) external => NONDET;
    function _.getLiquidationConfig() external => NONDET;

    // Protocol writes are irrelevant to steward-owned debounce storage.
    function _.updateInterestRateData(address, uint256, bytes) external => NONDET;
    function _.updateSpokeCaps(address, uint256, address, uint256, uint256) external => NONDET;
    function _.updateSpokeAddCap(address, uint256, address, uint256) external => NONDET;
    function _.updateSpokeDrawCap(address, uint256, address, uint256) external => NONDET;
    function _.updateCollateralRisk(address, uint256, uint256) external => NONDET;
    function _.updateDynamicReserveConfig(address, uint256, uint32, ISpoke.DynamicReserveConfig) external => NONDET;
    function _.addDynamicReserveConfig(address, uint256, ISpoke.DynamicReserveConfig) external => NONDET;
    function _.updateLiquidationConfig(address, ISpoke.LiquidationConfig) external => NONDET;
    function _.updateLiquidationTargetHealthFactor(address, uint256) external => NONDET;
    function _.updateHealthFactorForMaxBonus(address, uint256) external => NONDET;
    function _.updateLiquidationBonusFactor(address, uint256) external => NONDET;

    // HubEngine/SpokeEngine expose `external` library functions, i.e. DELEGATECALLs,
    // and the Prover treats the executing contract in that frame as HubEngine.
    //
    // NONDET instead assumes the callee writes no steward storage. That assumption is
    // discharged in two parts:
    //   1. Gated entrypoints — a reentrant callee has msg.sender == callee, so every
    //      onlyRiskCouncil / onlyOwner entrypoint reverts for it
    //      (AccessControl.spec: councilOnly, ownerOnly).
    //   2. Ungated entrypoints — acceptOwnership is reachable by a callee that is the
    //      pendingOwner. `debouncesIntactExceptUpdaters` below proves it, and every
    //      other non-updater method, leaves all six debounce mappings untouched.
    unresolved external in _._ => NONDET;
}

definition KEEP_CURRENT() returns uint256 = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd73;
definition KEEP_CURRENT_UINT16() returns uint16 = 0xffc2;
definition KEEP_CURRENT_UINT32() returns uint32 = 0xffffffe8;

// Key predicates: let a stamping rule test updates[0] against a whole batch by requiring
// no sibling names key(updates[0]) or key(other), whose stamps would read as violations.

// Hub,Underlying Key => OptimalUsageRatio,BaseDrawnRate,RateGrowthBeforeOptimal,RateGrowthAfterOptimal
definition irKeyIs(IAaveV4ConfigEngine.AssetConfigUpdate u, address h, address a) returns bool =
    u.hub == h && u.underlying == a;

// Hub,Spoke,Underlying Key => AddCap,DrawCap
definition capsKeyIs(IAaveV4ConfigEngine.SpokeConfigUpdate u, address h, address s, address a) returns bool =
    u.hub == h && u.spoke == s && u.underlying == a;

// Spoke,Hub,Underlying Key => CollateralRisk
definition reserveKeyIs(IAaveV4ConfigEngine.ReserveConfigUpdate u, address s, address h, address a) returns bool =
    u.spoke == s && u.hub == h && u.underlying == a;

// Spoke,Hub,Underlying Key => CollateralFactor,MaxLiquidationBonus
definition dynKeyIs(IAaveV4ConfigEngine.DynamicReserveConfigUpdate u, address s, address h, address a) returns bool =
    u.spoke == s && u.hub == h && u.underlying == a;

// Spoke,Hub,Underlying Key => CollateralFactor,MaxLiquidationBonus
definition dynAddKeyIs(IAaveV4ConfigEngine.DynamicReserveConfigAddition u, address s, address h, address a) returns bool =
    u.spoke == s && u.hub == h && u.underlying == a;

// ===========================================================================
// STAMPING
// ===========================================================================

// ---------------------------------------------------------------------------
// Hub asset IR: key (hub, asset), four width-matched sentinel fields.
// ---------------------------------------------------------------------------

rule hubAssetIrDebounceStamping(env e, address otherHub, address otherAsset) {
    // Create a valid AssetConfigUpdate batch where index 0 is the element under test
    IAaveV4ConfigEngine.AssetConfigUpdate[] updates;
    require otherHub != updates[0].hub || otherAsset != updates[0].underlying;

    // Require siblings to name neither the tested key nor the other key
    require forall uint256 j. (j != 0 && j < updates.length)
        => !irKeyIs(updates[j], updates[0].hub, updates[0].underlying);
    require forall uint256 j. j < updates.length => !irKeyIs(updates[j], otherHub, otherAsset);

    // Fetch the HubAssetDebounce of the tested key and of the other key before the update
    IRiskSteward.HubAssetDebounce before = getHubAssetDebounce(updates[0].hub, updates[0].underlying);
    IRiskSteward.HubAssetDebounce otherBefore = getHubAssetDebounce(otherHub, otherAsset);

    // Execute the update
    updateHubAssetIRs(e, updates);

    // Fetch the HubAssetDebounce of the tested key and of the other key after the update
    IRiskSteward.HubAssetDebounce after = getHubAssetDebounce(updates[0].hub, updates[0].underlying);
    IRiskSteward.HubAssetDebounce otherAfter = getHubAssetDebounce(otherHub, otherAsset);

    // Assert that the submitted IR fields stamp to tx time, KEEP_CURRENT preserves the stamp
    assert updates[0].irData.optimalUsageRatio != KEEP_CURRENT_UINT16() => to_mathint(after.optimalUsageRatio) == to_mathint(e.block.timestamp);
    assert updates[0].irData.optimalUsageRatio == KEEP_CURRENT_UINT16() => after.optimalUsageRatio == before.optimalUsageRatio;
    assert updates[0].irData.baseDrawnRate != KEEP_CURRENT_UINT32() => to_mathint(after.baseDrawnRate) == to_mathint(e.block.timestamp);
    assert updates[0].irData.baseDrawnRate == KEEP_CURRENT_UINT32() => after.baseDrawnRate == before.baseDrawnRate;
    assert updates[0].irData.rateGrowthBeforeOptimal != KEEP_CURRENT_UINT32() => to_mathint(after.rateGrowthBeforeOptimal) == to_mathint(e.block.timestamp);
    assert updates[0].irData.rateGrowthBeforeOptimal == KEEP_CURRENT_UINT32() => after.rateGrowthBeforeOptimal == before.rateGrowthBeforeOptimal;
    assert updates[0].irData.rateGrowthAfterOptimal != KEEP_CURRENT_UINT32() => to_mathint(after.rateGrowthAfterOptimal) == to_mathint(e.block.timestamp);
    assert updates[0].irData.rateGrowthAfterOptimal == KEEP_CURRENT_UINT32() => after.rateGrowthAfterOptimal == before.rateGrowthAfterOptimal;

    // Verify other (hub,asset) pairs debounces are not updated
    assert otherAfter.optimalUsageRatio == otherBefore.optimalUsageRatio
        && otherAfter.baseDrawnRate == otherBefore.baseDrawnRate
        && otherAfter.rateGrowthBeforeOptimal == otherBefore.rateGrowthBeforeOptimal
        && otherAfter.rateGrowthAfterOptimal == otherBefore.rateGrowthAfterOptimal;
}

// ---------------------------------------------------------------------------
// Hub-spoke caps: key (hub, spoke, asset), addCap and drawCap.
// ---------------------------------------------------------------------------

rule hubSpokeCapsDebounceStamping(env e, address otherHub, address otherSpoke, address otherAsset) {
    // Create a valid SpokeConfigUpdate batch; index 0 is the element under test
    IAaveV4ConfigEngine.SpokeConfigUpdate[] updates;
    require otherHub != updates[0].hub || otherSpoke != updates[0].spoke
        || otherAsset != updates[0].underlying;

    // Require siblings to name neither the tested key nor the other key
    require forall uint256 j. (j != 0 && j < updates.length)
        => !capsKeyIs(updates[j], updates[0].hub, updates[0].spoke, updates[0].underlying);
    require forall uint256 j. j < updates.length
        => !capsKeyIs(updates[j], otherHub, otherSpoke, otherAsset);

    // Fetch the HubSpokeAssetDebounce of the tested key and of the other key before the update
    IRiskSteward.HubSpokeAssetDebounce before = getHubSpokeAssetDebounce(updates[0].hub, updates[0].spoke, updates[0].underlying);
    IRiskSteward.HubSpokeAssetDebounce otherBefore = getHubSpokeAssetDebounce(otherHub, otherSpoke, otherAsset);

    // Execute the update
    updateHubSpokeCaps(e, updates);

    // Fetch the HubSpokeAssetDebounce of the tested key and of the other key after the update
    IRiskSteward.HubSpokeAssetDebounce after = getHubSpokeAssetDebounce(updates[0].hub, updates[0].spoke, updates[0].underlying);
    IRiskSteward.HubSpokeAssetDebounce otherAfter = getHubSpokeAssetDebounce(otherHub, otherSpoke, otherAsset);

    // Assert that the submitted cap fields stamp to tx time, KEEP_CURRENT preserves the stamp
    assert updates[0].addCap != KEEP_CURRENT() => to_mathint(after.addCap) == to_mathint(e.block.timestamp);
    assert updates[0].addCap == KEEP_CURRENT() => after.addCap == before.addCap;
    assert updates[0].drawCap != KEEP_CURRENT() => to_mathint(after.drawCap) == to_mathint(e.block.timestamp);
    assert updates[0].drawCap == KEEP_CURRENT() => after.drawCap == before.drawCap;

    // Verify other (hub,spoke,asset) pairs debounces are not updated
    assert otherAfter.addCap == otherBefore.addCap && otherAfter.drawCap == otherBefore.drawCap;
}

// ---------------------------------------------------------------------------
// Reserve config: key (spoke, hub, asset), collateralRisk.
// ---------------------------------------------------------------------------

rule reserveDebounceStamping(env e, address otherSpoke, address otherHub, address otherAsset) {
    // Create a valid ReserveConfigUpdate batch; index 0 is the element under test
    IAaveV4ConfigEngine.ReserveConfigUpdate[] updates;
    require otherSpoke != updates[0].spoke || otherHub != updates[0].hub
        || otherAsset != updates[0].underlying;

    // Require siblings to name neither the tested key nor the other key
    require forall uint256 j. (j != 0 && j < updates.length)
        => !reserveKeyIs(updates[j], updates[0].spoke, updates[0].hub, updates[0].underlying);
    require forall uint256 j. j < updates.length
        => !reserveKeyIs(updates[j], otherSpoke, otherHub, otherAsset);

    // Fetch the SpokeReserveDebounce of the tested key and of the other key before the update
    IRiskSteward.SpokeReserveDebounce before = getSpokeReserveDebounce(updates[0].spoke, updates[0].hub, updates[0].underlying);
    IRiskSteward.SpokeReserveDebounce otherBefore = getSpokeReserveDebounce(otherSpoke, otherHub, otherAsset);

    // Execute the update
    updateReserveConfigs(e, updates);

    // Fetch the SpokeReserveDebounce of the tested key and of the other key after the update
    IRiskSteward.SpokeReserveDebounce after = getSpokeReserveDebounce(updates[0].spoke, updates[0].hub, updates[0].underlying);
    IRiskSteward.SpokeReserveDebounce otherAfter = getSpokeReserveDebounce(otherSpoke, otherHub, otherAsset);

    // Assert that collateralRisk stamps to tx time, KEEP_CURRENT preserves the stamp
    assert updates[0].collateralRisk != KEEP_CURRENT() => to_mathint(after.collateralRisk) == to_mathint(e.block.timestamp);
    assert updates[0].collateralRisk == KEEP_CURRENT() => after.collateralRisk == before.collateralRisk;

    // Verify other (spoke,hub,asset) pairs debounces are not updated
    assert otherAfter.collateralRisk == otherBefore.collateralRisk;
}

// ---------------------------------------------------------------------------
// Dynamic update: shared key (spoke, hub, asset), two governed fields.
// ---------------------------------------------------------------------------

rule dynamicUpdateDebounceStamping(env e, address otherSpoke, address otherHub, address otherAsset) {
    // Create a valid DynamicReserveConfigUpdate batch; index 0 is the element under test
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates;
    require otherSpoke != updates[0].spoke || otherHub != updates[0].hub
        || otherAsset != updates[0].underlying;

    // Require siblings to name neither the tested key nor the other key. The debounce key
    // ignores dynamicConfigKey, so two entries on different config keys of the same
    // reserve still collide here and must be excluded.
    require forall uint256 j. (j != 0 && j < updates.length)
        => !dynKeyIs(updates[j], updates[0].spoke, updates[0].hub, updates[0].underlying);
    require forall uint256 j. j < updates.length
        => !dynKeyIs(updates[j], otherSpoke, otherHub, otherAsset);

    // Fetch the SpokeDynamicDebounce of the tested key and of the other key before the update
    IRiskSteward.SpokeDynamicDebounce before = getSpokeDynamicDebounce(updates[0].spoke, updates[0].hub, updates[0].underlying);
    IRiskSteward.SpokeDynamicDebounce otherBefore = getSpokeDynamicDebounce(otherSpoke, otherHub, otherAsset);

    // Execute the update
    updateDynamicReserveConfigs(e, updates);

    // Fetch the SpokeDynamicDebounce of the tested key and of the other key after the update
    IRiskSteward.SpokeDynamicDebounce after = getSpokeDynamicDebounce(updates[0].spoke, updates[0].hub, updates[0].underlying);
    IRiskSteward.SpokeDynamicDebounce otherAfter = getSpokeDynamicDebounce(otherSpoke, otherHub, otherAsset);

    // Assert that the submitted dynamic fields stamp to tx time, KEEP_CURRENT preserves the stamp
    assert updates[0].collateralFactor != KEEP_CURRENT() => to_mathint(after.collateralFactor) == to_mathint(e.block.timestamp);
    assert updates[0].collateralFactor == KEEP_CURRENT() => after.collateralFactor == before.collateralFactor;
    assert updates[0].maxLiquidationBonus != KEEP_CURRENT() => to_mathint(after.maxLiquidationBonus) == to_mathint(e.block.timestamp);
    assert updates[0].maxLiquidationBonus == KEEP_CURRENT() => after.maxLiquidationBonus == before.maxLiquidationBonus;

    // Verify other (spoke,hub,asset) pairs debounces are not updated
    assert otherAfter.collateralFactor == otherBefore.collateralFactor
        && otherAfter.maxLiquidationBonus == otherBefore.maxLiquidationBonus;
}

// ---------------------------------------------------------------------------
// Spoke-global liquidation config: key spoke, three governed fields.
// ---------------------------------------------------------------------------

rule liquidationDebounceStamping(env e, address otherSpoke) {
    // Create a valid LiquidationConfigUpdate batch; index 0 is the element under test
    IAaveV4ConfigEngine.LiquidationConfigUpdate[] updates;
    require otherSpoke != updates[0].spoke;

    // Require siblings to name neither spoke — this debounce is keyed on spoke alone
    require forall uint256 j. (j != 0 && j < updates.length) => updates[j].spoke != updates[0].spoke;
    require forall uint256 j. j < updates.length => updates[j].spoke != otherSpoke;

    // Fetch the SpokeLiquidationDebounce of the tested spoke and of the other spoke before the update
    IRiskSteward.SpokeLiquidationDebounce before = getSpokeLiquidationDebounce(updates[0].spoke);
    IRiskSteward.SpokeLiquidationDebounce otherBefore = getSpokeLiquidationDebounce(otherSpoke);

    // Execute the update
    updateSpokeLiquidationConfigs(e, updates);

    // Fetch the SpokeLiquidationDebounce of the tested spoke and of the other spoke after the update
    IRiskSteward.SpokeLiquidationDebounce after = getSpokeLiquidationDebounce(updates[0].spoke);
    IRiskSteward.SpokeLiquidationDebounce otherAfter = getSpokeLiquidationDebounce(otherSpoke);

    // Assert that the submitted liquidation fields stamp to tx time, KEEP_CURRENT preserves the stamp
    assert updates[0].targetHealthFactor != KEEP_CURRENT() => to_mathint(after.targetHealthFactor) == to_mathint(e.block.timestamp);
    assert updates[0].targetHealthFactor == KEEP_CURRENT() => after.targetHealthFactor == before.targetHealthFactor;
    assert updates[0].healthFactorForMaxBonus != KEEP_CURRENT() => to_mathint(after.healthFactorForMaxBonus) == to_mathint(e.block.timestamp);
    assert updates[0].healthFactorForMaxBonus == KEEP_CURRENT() => after.healthFactorForMaxBonus == before.healthFactorForMaxBonus;
    assert updates[0].liquidationBonusFactor != KEEP_CURRENT() => to_mathint(after.liquidationBonusFactor) == to_mathint(e.block.timestamp);
    assert updates[0].liquidationBonusFactor == KEEP_CURRENT() => after.liquidationBonusFactor == before.liquidationBonusFactor;

    // Verify other spoke debounces are not updated
    assert otherAfter.targetHealthFactor == otherBefore.targetHealthFactor
        && otherAfter.healthFactorForMaxBonus == otherBefore.healthFactorForMaxBonus
        && otherAfter.liquidationBonusFactor == otherBefore.liquidationBonusFactor;
}

// Dynamic additions intentionally consume both shared debounce windows. Only the
// `other` clause is needed: an addition stamps unconditionally, so a sibling at the
// same key stamps to the same timestamp and cannot break the assert.
rule dynamicAdditionStampsBoth(env e, address otherSpoke, address otherHub, address otherAsset) {
    // Create a valid DynamicReserveConfigAddition batch; index 0 is the element under test
    IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions;
    require otherSpoke != additions[0].spoke || otherHub != additions[0].hub
        || otherAsset != additions[0].underlying;

    // Require siblings to name the other key
    require forall uint256 j. j < additions.length
        => !dynAddKeyIs(additions[j], otherSpoke, otherHub, otherAsset);

    // Fetch the SpokeDynamicDebounce of the other key before the update
    IRiskSteward.SpokeDynamicDebounce otherBefore =
        getSpokeDynamicDebounce(otherSpoke, otherHub, otherAsset);

    // Execute the addition
    addDynamicReserveConfigs(e, additions);

    // Fetch the SpokeDynamicDebounce of the tested key and of the other key after the update
    IRiskSteward.SpokeDynamicDebounce after = getSpokeDynamicDebounce(additions[0].spoke, additions[0].hub, additions[0].underlying);
    IRiskSteward.SpokeDynamicDebounce otherAfter = getSpokeDynamicDebounce(otherSpoke, otherHub, otherAsset);

    // Assert that both shared dynamic debounce fields stamp to tx time
    assert to_mathint(after.collateralFactor) == to_mathint(e.block.timestamp)
        && to_mathint(after.maxLiquidationBonus) == to_mathint(e.block.timestamp);

    // Verify other (spoke,hub,asset) pairs debounces are not updated
    assert otherAfter.collateralFactor == otherBefore.collateralFactor && otherAfter.maxLiquidationBonus == otherBefore.maxLiquidationBonus;
}

// ---------------------------------------------------------------------------
// ENFORCEMENT — the read side of every governed (field, entrypoint) pair.
// ---------------------------------------------------------------------------

// Four fields, each with its width-matched sentinel. `_validateIRFieldUint16/32` skips on
// the narrow sentinel; the widened value can never equal the uint256 KEEP_CURRENT, so the
// narrow sentinel is the only skip path.
rule hubAssetIrDebounceEnforced(env e) {
    // Create a valid AssetConfigUpdate batch; index 0 is the element under test
    IAaveV4ConfigEngine.AssetConfigUpdate[] updates;

    // Fetch the HubAssetDebounce and the configured minDelays before the update
    IRiskSteward.HubAssetDebounce before = getHubAssetDebounce(updates[0].hub, updates[0].underlying);
    IRiskSteward.HubRateConfig rate = getConfig().hub.rate;

    // Execute the update
    updateHubAssetIRs(e, updates);

    // Assert that a successful non-sentinel write respected minDelay
    assert updates[0].irData.optimalUsageRatio != KEEP_CURRENT_UINT16()
        => to_mathint(e.block.timestamp) - to_mathint(before.optimalUsageRatio)
             >= to_mathint(rate.optimalUsageRatio.minDelay);
    assert updates[0].irData.baseDrawnRate != KEEP_CURRENT_UINT32()
        => to_mathint(e.block.timestamp) - to_mathint(before.baseDrawnRate)
             >= to_mathint(rate.baseDrawnRate.minDelay);
    assert updates[0].irData.rateGrowthBeforeOptimal != KEEP_CURRENT_UINT32()
        => to_mathint(e.block.timestamp) - to_mathint(before.rateGrowthBeforeOptimal)
             >= to_mathint(rate.rateGrowthBeforeOptimal.minDelay);
    assert updates[0].irData.rateGrowthAfterOptimal != KEEP_CURRENT_UINT32()
        => to_mathint(e.block.timestamp) - to_mathint(before.rateGrowthAfterOptimal)
             >= to_mathint(rate.rateGrowthAfterOptimal.minDelay);
}

rule hubSpokeCapsDebounceEnforced(env e) {
    // Create a valid SpokeConfigUpdate batch; index 0 is the element under test
    IAaveV4ConfigEngine.SpokeConfigUpdate[] updates;

    // Fetch the HubSpokeAssetDebounce and the configured minDelays before the update
    IRiskSteward.HubSpokeAssetDebounce before = getHubSpokeAssetDebounce(updates[0].hub, updates[0].spoke, updates[0].underlying);
    IRiskSteward.HubCapConfig cap = getConfig().hub.cap;

    // Execute the update
    updateHubSpokeCaps(e, updates);

    // Assert that a successful non-sentinel write respected minDelay
    assert updates[0].addCap != KEEP_CURRENT()
        => to_mathint(e.block.timestamp) - to_mathint(before.addCap) >= to_mathint(cap.addCap.minDelay);
    assert updates[0].drawCap != KEEP_CURRENT()
        => to_mathint(e.block.timestamp) - to_mathint(before.drawCap) >= to_mathint(cap.drawCap.minDelay);
}

rule reserveDebounceEnforced(env e) {
    // Create a valid ReserveConfigUpdate batch; index 0 is the element under test
    IAaveV4ConfigEngine.ReserveConfigUpdate[] updates;

    // Fetch the SpokeReserveDebounce and the configured minDelay before the update
    IRiskSteward.SpokeReserveDebounce before = getSpokeReserveDebounce(updates[0].spoke, updates[0].hub, updates[0].underlying);
    mathint minDelay = to_mathint(getConfig().spoke.collateralRisk.minDelay);

    // Execute the update
    updateReserveConfigs(e, updates);

    // Assert that a successful non-sentinel write respected minDelay
    assert updates[0].collateralRisk != KEEP_CURRENT() => to_mathint(e.block.timestamp) - to_mathint(before.collateralRisk) >= minDelay;
}

// Bounded by `_config.spoke.dynamicUpdate`; the add path uses a separate bound, below.
rule dynamicUpdateDebounceEnforced(env e) {
    // Create a valid DynamicReserveConfigUpdate batch; index 0 is the element under test
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates;

    // Fetch the SpokeDynamicDebounce and the configured minDelays before the update
    IRiskSteward.SpokeDynamicDebounce before = getSpokeDynamicDebounce(updates[0].spoke, updates[0].hub, updates[0].underlying);
    IRiskSteward.SpokeDynamicConfig bounds = getConfig().spoke.dynamicUpdate;

    // Execute the update
    updateDynamicReserveConfigs(e, updates);

    // Assert that a successful non-sentinel write respected minDelay
    assert updates[0].collateralFactor != KEEP_CURRENT()
        => to_mathint(e.block.timestamp) - to_mathint(before.collateralFactor)
             >= to_mathint(bounds.collateralFactor.minDelay);
    assert updates[0].maxLiquidationBonus != KEEP_CURRENT()
        => to_mathint(e.block.timestamp) - to_mathint(before.maxLiquidationBonus)
             >= to_mathint(bounds.maxLiquidationBonus.minDelay);
}

// Unconditional: an addition always writes both fields, so `_validateParamUpdate` never
// takes its KEEP_CURRENT early-return on this path.
rule dynamicAdditionDebounceEnforced(env e) {
    // Create a valid DynamicReserveConfigAddition batch; index 0 is the element under test
    IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions;

    // Fetch the SpokeDynamicDebounce and the configured minDelays before the addition
    IRiskSteward.SpokeDynamicDebounce before = getSpokeDynamicDebounce(additions[0].spoke, additions[0].hub, additions[0].underlying);
    IRiskSteward.SpokeDynamicConfig bounds = getConfig().spoke.dynamicAdd;

    // Execute the addition
    addDynamicReserveConfigs(e, additions);

    // Assert that a successful addition respected minDelay
    assert to_mathint(e.block.timestamp) - to_mathint(before.collateralFactor) >= to_mathint(bounds.collateralFactor.minDelay);
    assert to_mathint(e.block.timestamp) - to_mathint(before.maxLiquidationBonus) >= to_mathint(bounds.maxLiquidationBonus.minDelay);
}

// The rule that would catch a council moving targetHealthFactor every block.
rule liquidationDebounceEnforced(env e) {
    // Create a valid LiquidationConfigUpdate batch; index 0 is the element under test
    IAaveV4ConfigEngine.LiquidationConfigUpdate[] updates;

    // Fetch the SpokeLiquidationDebounce and the configured minDelays before the update
    IRiskSteward.SpokeLiquidationDebounce before = getSpokeLiquidationDebounce(updates[0].spoke);
    IRiskSteward.SpokeLiquidationConfig bounds = getConfig().spoke.liquidation;

    // Execute the update
    updateSpokeLiquidationConfigs(e, updates);

    // Assert that a successful non-sentinel write respected minDelay
    assert updates[0].targetHealthFactor != KEEP_CURRENT()
        => to_mathint(e.block.timestamp) - to_mathint(before.targetHealthFactor)
             >= to_mathint(bounds.targetHealthFactor.minDelay);
    assert updates[0].healthFactorForMaxBonus != KEEP_CURRENT()
        => to_mathint(e.block.timestamp) - to_mathint(before.healthFactorForMaxBonus)
             >= to_mathint(bounds.healthFactorForMaxBonus.minDelay);
    assert updates[0].liquidationBonusFactor != KEEP_CURRENT()
        => to_mathint(e.block.timestamp) - to_mathint(before.liquidationBonusFactor)
             >= to_mathint(bounds.liquidationBonusFactor.minDelay);
}

// ---------------------------------------------------------------------------
// Oracle paths — one shared stamp per oracle across all three families.
// ---------------------------------------------------------------------------

// LST: the gate is on maxYearlyRatioGrowthPercent (uint16), so it is never skipped.
rule lstOracleDebounceEnforced(env e) {
    // Create a valid PriceCapLstUpdate batch; index 0 is the element under test
    IRiskSteward.PriceCapLstUpdate[] updates;

    // Fetch the oracle debounce and the configured minDelay before the update
    uint40 before = getOracleDebounce(updates[0].oracle);
    mathint minDelay = to_mathint(getConfig().oracle.priceCapLst.minDelay);

    // Execute the update
    updateLstPriceCaps(e, updates);

    // Assert that a successful write respected minDelay
    assert to_mathint(e.block.timestamp) - to_mathint(before) >= minDelay;
}

// Stable / Pendle: the new value is a uint256, so KEEP_CURRENT reaches the early-return
// in `_validateParamUpdate` and skips the gate. The guard mirrors that skip;
// RevertConditions.spec proves no such write can actually land.
rule stableOracleDebounceEnforced(env e) {
    // Create a valid PriceCapStableUpdate batch; index 0 is the element under test
    IRiskSteward.PriceCapStableUpdate[] updates;

    // Fetch the oracle debounce and the configured minDelay before the update
    uint40 before = getOracleDebounce(updates[0].oracle);
    mathint minDelay = to_mathint(getConfig().oracle.priceCapStable.minDelay);

    // Execute the update
    updateStablePriceCaps(e, updates);

    // Assert that a successful non-sentinel write respected minDelay
    assert updates[0].priceCap != KEEP_CURRENT()
        => to_mathint(e.block.timestamp) - to_mathint(before) >= minDelay;
}

rule pendleOracleDebounceEnforced(env e) {
    // Create a valid DiscountRatePendleUpdate batch; index 0 is the element under test
    IRiskSteward.DiscountRatePendleUpdate[] updates;

    // Fetch the oracle debounce and the configured minDelay before the update
    uint40 before = getOracleDebounce(updates[0].oracle);
    mathint minDelay = to_mathint(getConfig().oracle.discountRatePendle.minDelay);

    // Execute the update
    updatePendleDiscountRates(e, updates);

    // Assert that a successful non-sentinel write respected minDelay
    assert updates[0].discountRate != KEEP_CURRENT() => to_mathint(e.block.timestamp) - to_mathint(before) >= minDelay;
}

// No method outside the nine update entrypoints can move a debounce stamp. 
rule debouncesIntactExceptUpdaters(method f, env e,address hub, address spoke, address asset, address oracle)
    filtered { 
        f -> f.selector != sig:updateHubAssetIRs(IAaveV4ConfigEngine.AssetConfigUpdate[]).selector &&
        f.selector != sig:updateHubSpokeCaps(IAaveV4ConfigEngine.SpokeConfigUpdate[]).selector &&
        f.selector != sig:updateReserveConfigs(IAaveV4ConfigEngine.ReserveConfigUpdate[]).selector &&
        f.selector != sig:updateDynamicReserveConfigs(IAaveV4ConfigEngine.DynamicReserveConfigUpdate[]).selector &&
        f.selector != sig:addDynamicReserveConfigs(IAaveV4ConfigEngine.DynamicReserveConfigAddition[]).selector &&
        f.selector != sig:updateSpokeLiquidationConfigs(IAaveV4ConfigEngine.LiquidationConfigUpdate[]).selector &&
        f.selector != sig:updateLstPriceCaps(IRiskSteward.PriceCapLstUpdate[]).selector &&
        f.selector != sig:updateStablePriceCaps(IRiskSteward.PriceCapStableUpdate[]).selector &&
        f.selector != sig:updatePendleDiscountRates(IRiskSteward.DiscountRatePendleUpdate[]).selector
    }
{
    // Fetch every debounce mapping at an arbitrary key before the call
    IRiskSteward.HubAssetDebounce ha0 = getHubAssetDebounce(hub, asset);
    IRiskSteward.HubSpokeAssetDebounce hs0 = getHubSpokeAssetDebounce(hub, spoke, asset);
    IRiskSteward.SpokeReserveDebounce sr0 = getSpokeReserveDebounce(spoke, hub, asset);
    IRiskSteward.SpokeDynamicDebounce sd0 = getSpokeDynamicDebounce(spoke, hub, asset);
    IRiskSteward.SpokeLiquidationDebounce sl0 = getSpokeLiquidationDebounce(spoke);
    uint40 or0 = getOracleDebounce(oracle);

    // Execute an arbitrary non-updater method
    calldataarg args;
    f(e, args);

    // Fetch the same six debounces after the call
    IRiskSteward.HubAssetDebounce ha1 = getHubAssetDebounce(hub, asset);
    IRiskSteward.HubSpokeAssetDebounce hs1 = getHubSpokeAssetDebounce(hub, spoke, asset);
    IRiskSteward.SpokeReserveDebounce sr1 = getSpokeReserveDebounce(spoke, hub, asset);
    IRiskSteward.SpokeDynamicDebounce sd1 = getSpokeDynamicDebounce(spoke, hub, asset);
    IRiskSteward.SpokeLiquidationDebounce sl1 = getSpokeLiquidationDebounce(spoke);
    uint40 or1 = getOracleDebounce(oracle);

    // Assert that no debounce stamp moved
    assert ha1.optimalUsageRatio == ha0.optimalUsageRatio
        && ha1.baseDrawnRate == ha0.baseDrawnRate
        && ha1.rateGrowthBeforeOptimal == ha0.rateGrowthBeforeOptimal
        && ha1.rateGrowthAfterOptimal == ha0.rateGrowthAfterOptimal;
    assert hs1.addCap == hs0.addCap && hs1.drawCap == hs0.drawCap;
    assert sr1.collateralRisk == sr0.collateralRisk;
    assert sd1.collateralFactor == sd0.collateralFactor && sd1.maxLiquidationBonus == sd0.maxLiquidationBonus;
    assert sl1.targetHealthFactor == sl0.targetHealthFactor
        && sl1.healthFactorForMaxBonus == sl0.healthFactorForMaxBonus
        && sl1.liquidationBonusFactor == sl0.liquidationBonusFactor;
    assert or1 == or0;
}
