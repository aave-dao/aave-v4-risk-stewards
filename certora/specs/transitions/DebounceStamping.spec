/*
 * RiskSteward — State transitions: debounce stamping.
 *
 * Property: a successful non-KEEP_CURRENT write stamps that field's debounce to
 * now, and leaves KEEP_CURRENT siblings and every other key untouched.
 */

methods {
    function RISK_COUNCIL() external returns (address) envfree;
    function getConfig() external returns (IRiskSteward.Config) envfree;

    function getHubAssetDebounce(address hub, address asset) external returns (IRiskSteward.HubAssetDebounce) envfree;
    function getHubSpokeAssetDebounce(address hub, address spoke, address asset) external returns (IRiskSteward.HubSpokeAssetDebounce) envfree;
    function getSpokeReserveDebounce(address spoke, address hub, address asset) external returns (IRiskSteward.SpokeReserveDebounce) envfree;
    function getSpokeDynamicDebounce(address spoke, address hub, address asset) external returns (IRiskSteward.SpokeDynamicDebounce) envfree;
    function getSpokeLiquidationDebounce(address spoke) external returns (IRiskSteward.SpokeLiquidationDebounce) envfree;
    
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
}

definition KEEP_CURRENT() returns uint256 = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd73;
definition KEEP_CURRENT_UINT16() returns uint16 = 0xffc2;
definition KEEP_CURRENT_UINT32() returns uint32 = 0xffffffe8;

// ---------------------------------------------------------------------------
// Hub asset IR: key (hub, asset), four width-matched sentinel fields.
// ---------------------------------------------------------------------------

rule hubAssetIrDebounceStamping(env e, IAaveV4ConfigEngine.AssetConfigUpdate u,address otherHub, address otherAsset) {
    require otherHub != u.hub || otherAsset != u.underlying,"Other hub and asset must be different from the input";

    // Create a valid AssetConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.AssetConfigUpdate[] updates;
    require updates.length == 1
        && updates[0].hubConfigurator == u.hubConfigurator
        && updates[0].hub == u.hub && updates[0].underlying == u.underlying
        && updates[0].liquidityFee == u.liquidityFee
        && updates[0].feeReceiver == u.feeReceiver
        && updates[0].irStrategy == u.irStrategy
        && updates[0].irData.optimalUsageRatio == u.irData.optimalUsageRatio
        && updates[0].irData.baseDrawnRate == u.irData.baseDrawnRate
        && updates[0].irData.rateGrowthBeforeOptimal == u.irData.rateGrowthBeforeOptimal
        && updates[0].irData.rateGrowthAfterOptimal == u.irData.rateGrowthAfterOptimal
        && updates[0].reinvestmentController == u.reinvestmentController;

    // Fetch the HubAssetDebounce before the update
    IRiskSteward.HubAssetDebounce before = getHubAssetDebounce(u.hub, u.underlying);
    // Fetch the HubAssetDebounce of other hub and other asset before the update
    IRiskSteward.HubAssetDebounce otherBefore = getHubAssetDebounce(otherHub, otherAsset);

    // Execute the update
    updateHubAssetIRs(e, updates);

    // Fetch the HubAssetDebounce after the update
    IRiskSteward.HubAssetDebounce after = getHubAssetDebounce(u.hub, u.underlying);
    IRiskSteward.HubAssetDebounce otherAfter = getHubAssetDebounce(otherHub, otherAsset);

    // Assert that the submitted IR fields stamp to tx time, KEEP_CURRENT preserves the stamp
    assert (u.irData.optimalUsageRatio != KEEP_CURRENT_UINT16()) => to_mathint(after.optimalUsageRatio) == to_mathint(e.block.timestamp);
    assert (u.irData.optimalUsageRatio == KEEP_CURRENT_UINT16()) => after.optimalUsageRatio == before.optimalUsageRatio;
    assert (u.irData.baseDrawnRate != KEEP_CURRENT_UINT32()) => to_mathint(after.baseDrawnRate) == to_mathint(e.block.timestamp);
    assert (u.irData.baseDrawnRate == KEEP_CURRENT_UINT32()) => after.baseDrawnRate == before.baseDrawnRate;
    assert (u.irData.rateGrowthBeforeOptimal != KEEP_CURRENT_UINT32()) => to_mathint(after.rateGrowthBeforeOptimal) == to_mathint(e.block.timestamp);
    assert (u.irData.rateGrowthBeforeOptimal == KEEP_CURRENT_UINT32()) => after.rateGrowthBeforeOptimal == before.rateGrowthBeforeOptimal;
    assert (u.irData.rateGrowthAfterOptimal != KEEP_CURRENT_UINT32()) => to_mathint(after.rateGrowthAfterOptimal) == to_mathint(e.block.timestamp);
    assert (u.irData.rateGrowthAfterOptimal == KEEP_CURRENT_UINT32()) => after.rateGrowthAfterOptimal == before.rateGrowthAfterOptimal;
    
    // Verify other (hub,asset) pairs debounces are not updated
    assert otherAfter.optimalUsageRatio == otherBefore.optimalUsageRatio
        && otherAfter.baseDrawnRate == otherBefore.baseDrawnRate
        && otherAfter.rateGrowthBeforeOptimal == otherBefore.rateGrowthBeforeOptimal
        && otherAfter.rateGrowthAfterOptimal == otherBefore.rateGrowthAfterOptimal;
}

// ---------------------------------------------------------------------------
// Hub-spoke caps: key (hub, spoke, asset), addCap and drawCap.
// ---------------------------------------------------------------------------

rule hubSpokeCapsDebounceStamping(env e, IAaveV4ConfigEngine.SpokeConfigUpdate u, address otherHub, address otherSpoke, address otherAsset) {
    require otherHub != u.hub || otherSpoke != u.spoke || otherAsset != u.underlying,"Other hub, spoke and asset must be different from the input";

    // Create a valid SpokeConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.SpokeConfigUpdate[] updates;
    require updates.length == 1
        && updates[0].hubConfigurator == u.hubConfigurator
        && updates[0].hub == u.hub && updates[0].spoke == u.spoke
        && updates[0].underlying == u.underlying
        && updates[0].addCap == u.addCap && updates[0].drawCap == u.drawCap
        && updates[0].riskPremiumThreshold == u.riskPremiumThreshold
        && updates[0].active == u.active && updates[0].halted == u.halted;

    // Fetch the HubSpokeAssetDebounce before the update
    IRiskSteward.HubSpokeAssetDebounce before = getHubSpokeAssetDebounce(u.hub, u.spoke, u.underlying);
    // Fetch the HubSpokeAssetDebounce of other hub, spoke and asset before the update
    IRiskSteward.HubSpokeAssetDebounce otherBefore = getHubSpokeAssetDebounce(otherHub, otherSpoke, otherAsset);

    // Execute the update
    updateHubSpokeCaps(e, updates);

    // Fetch the HubSpokeAssetDebounce after the update
    IRiskSteward.HubSpokeAssetDebounce after = getHubSpokeAssetDebounce(u.hub, u.spoke, u.underlying);
    IRiskSteward.HubSpokeAssetDebounce otherAfter = getHubSpokeAssetDebounce(otherHub, otherSpoke, otherAsset);

    // Assert that the submitted cap fields stamp to tx time, KEEP_CURRENT preserves the stamp
    assert u.addCap != KEEP_CURRENT() => to_mathint(after.addCap) == to_mathint(e.block.timestamp);
    assert u.addCap == KEEP_CURRENT() => after.addCap == before.addCap;
    assert u.drawCap != KEEP_CURRENT() => to_mathint(after.drawCap) == to_mathint(e.block.timestamp);
    assert u.drawCap == KEEP_CURRENT() => after.drawCap == before.drawCap;

    // Verify other (hub,spoke,asset) pairs debounces are not updated
    assert otherAfter.addCap == otherBefore.addCap && otherAfter.drawCap == otherBefore.drawCap;
}

// ---------------------------------------------------------------------------
// Debounce ENFORCEMENT
// ---------------------------------------------------------------------------

rule hubSpokeCapsDebounceEnforced(env e, IAaveV4ConfigEngine.SpokeConfigUpdate u) {
    // Create a valid SpokeConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.SpokeConfigUpdate[] updates;
    require updates.length == 1
        && updates[0].hubConfigurator == u.hubConfigurator
        && updates[0].hub == u.hub && updates[0].spoke == u.spoke
        && updates[0].underlying == u.underlying
        && updates[0].addCap == u.addCap && updates[0].drawCap == u.drawCap
        && updates[0].riskPremiumThreshold == u.riskPremiumThreshold
        && updates[0].active == u.active && updates[0].halted == u.halted;

    // Fetch the HubSpokeAssetDebounce and minDelay before the update
    IRiskSteward.HubSpokeAssetDebounce before = getHubSpokeAssetDebounce(u.hub, u.spoke, u.underlying);
    mathint addMinDelay = to_mathint(getConfig().hub.cap.addCap.minDelay);
    mathint drawMinDelay = to_mathint(getConfig().hub.cap.drawCap.minDelay);

    // Execute the update
    updateHubSpokeCaps(e, updates);

    // Assert that a successful non-sentinel write respected minDelay
    assert u.addCap != KEEP_CURRENT() => to_mathint(e.block.timestamp) - to_mathint(before.addCap) >= addMinDelay;
    assert u.drawCap != KEEP_CURRENT() => to_mathint(e.block.timestamp) - to_mathint(before.drawCap) >= drawMinDelay;
}

// ---------------------------------------------------------------------------
// Reserve config: key (spoke, hub, asset), collateralRisk.
// ---------------------------------------------------------------------------

rule reserveDebounceStamping(env e, IAaveV4ConfigEngine.ReserveConfigUpdate u, address otherSpoke, address otherHub, address otherAsset) {
    require otherSpoke != u.spoke || otherHub != u.hub || otherAsset != u.underlying,"Other spoke, hub and asset must be different from the input";

    // Create a valid ReserveConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.ReserveConfigUpdate[] updates;
    require updates.length == 1
        && updates[0].spokeConfigurator == u.spokeConfigurator
        && updates[0].spoke == u.spoke && updates[0].hub == u.hub
        && updates[0].underlying == u.underlying
        && updates[0].priceSource == u.priceSource
        && updates[0].collateralRisk == u.collateralRisk
        && updates[0].paused == u.paused && updates[0].frozen == u.frozen
        && updates[0].borrowable == u.borrowable
        && updates[0].receiveSharesEnabled == u.receiveSharesEnabled;

    // Fetch the SpokeReserveDebounce before the update
    IRiskSteward.SpokeReserveDebounce before = getSpokeReserveDebounce(u.spoke, u.hub, u.underlying);
    // Fetch the SpokeReserveDebounce of other spoke, hub and asset before the update
    IRiskSteward.SpokeReserveDebounce otherBefore = getSpokeReserveDebounce(otherSpoke, otherHub, otherAsset);

    // Execute the update
    updateReserveConfigs(e, updates);

    // Fetch the SpokeReserveDebounce after the update
    IRiskSteward.SpokeReserveDebounce after = getSpokeReserveDebounce(u.spoke, u.hub, u.underlying);
    IRiskSteward.SpokeReserveDebounce otherAfter = getSpokeReserveDebounce(otherSpoke, otherHub, otherAsset);

    // Assert that collateralRisk stamps to tx time, KEEP_CURRENT preserves the stamp
    assert u.collateralRisk != KEEP_CURRENT() => to_mathint(after.collateralRisk) == to_mathint(e.block.timestamp);
    assert u.collateralRisk == KEEP_CURRENT() => after.collateralRisk == before.collateralRisk;
    
    // Verify other (spoke,hub,asset) pairs debounces are not updated
    assert otherAfter.collateralRisk == otherBefore.collateralRisk;
}

// ---------------------------------------------------------------------------
// Dynamic update: shared key (spoke, hub, asset), two governed fields.
// ---------------------------------------------------------------------------

rule dynamicUpdateDebounceStamping(env e, IAaveV4ConfigEngine.DynamicReserveConfigUpdate u, address otherSpoke, address otherHub, address otherAsset) {
    require otherSpoke != u.spoke || otherHub != u.hub || otherAsset != u.underlying,"Other spoke, hub and asset must be different from the input";

    // Create a valid DynamicReserveConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates;
    require updates.length == 1
        && updates[0].spokeConfigurator == u.spokeConfigurator
        && updates[0].spoke == u.spoke && updates[0].hub == u.hub
        && updates[0].underlying == u.underlying
        && updates[0].dynamicConfigKey == u.dynamicConfigKey
        && updates[0].collateralFactor == u.collateralFactor
        && updates[0].maxLiquidationBonus == u.maxLiquidationBonus
        && updates[0].liquidationFee == u.liquidationFee;

    // Fetch the SpokeDynamicDebounce before the update
    IRiskSteward.SpokeDynamicDebounce before = getSpokeDynamicDebounce(u.spoke, u.hub, u.underlying);
    // Fetch the SpokeDynamicDebounce of other spoke, hub and asset before the update
    IRiskSteward.SpokeDynamicDebounce otherBefore = getSpokeDynamicDebounce(otherSpoke, otherHub, otherAsset);

    // Execute the update
    updateDynamicReserveConfigs(e, updates);

    // Fetch the SpokeDynamicDebounce after the update
    IRiskSteward.SpokeDynamicDebounce after = getSpokeDynamicDebounce(u.spoke, u.hub, u.underlying);
    IRiskSteward.SpokeDynamicDebounce otherAfter = getSpokeDynamicDebounce(otherSpoke, otherHub, otherAsset);

    // Assert that the submitted dynamic fields stamp to tx time, KEEP_CURRENT preserves the stamp
    assert u.collateralFactor != KEEP_CURRENT() => to_mathint(after.collateralFactor) == to_mathint(e.block.timestamp);
    assert u.collateralFactor == KEEP_CURRENT() => after.collateralFactor == before.collateralFactor;
    assert u.maxLiquidationBonus != KEEP_CURRENT() => to_mathint(after.maxLiquidationBonus) == to_mathint(e.block.timestamp);
    assert u.maxLiquidationBonus == KEEP_CURRENT() => after.maxLiquidationBonus == before.maxLiquidationBonus;
    
    // Verify other (spoke,hub,asset) pairs debounces are not updated
    assert otherAfter.collateralFactor == otherBefore.collateralFactor && otherAfter.maxLiquidationBonus == otherBefore.maxLiquidationBonus;
}

// ---------------------------------------------------------------------------
// Spoke-global liquidation config: key spoke, three governed fields.
// ---------------------------------------------------------------------------

rule liquidationDebounceStamping(env e, IAaveV4ConfigEngine.LiquidationConfigUpdate u, address otherSpoke) {
    require otherSpoke != u.spoke,"Other spoke must be different from the input";

    // Create a valid LiquidationConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.LiquidationConfigUpdate[] updates;
    require updates.length == 1
        && updates[0].spokeConfigurator == u.spokeConfigurator
        && updates[0].spoke == u.spoke
        && updates[0].targetHealthFactor == u.targetHealthFactor
        && updates[0].healthFactorForMaxBonus == u.healthFactorForMaxBonus
        && updates[0].liquidationBonusFactor == u.liquidationBonusFactor;

    // Fetch the SpokeLiquidationDebounce before the update
    IRiskSteward.SpokeLiquidationDebounce before = getSpokeLiquidationDebounce(u.spoke);
    // Fetch the SpokeLiquidationDebounce of other spoke before the update
    IRiskSteward.SpokeLiquidationDebounce otherBefore = getSpokeLiquidationDebounce(otherSpoke);

    // Execute the update
    updateSpokeLiquidationConfigs(e, updates);

    // Fetch the SpokeLiquidationDebounce after the update
    IRiskSteward.SpokeLiquidationDebounce after = getSpokeLiquidationDebounce(u.spoke);
    IRiskSteward.SpokeLiquidationDebounce otherAfter = getSpokeLiquidationDebounce(otherSpoke);

    // Assert that the submitted liquidation fields stamp to tx time, KEEP_CURRENT preserves the stamp
    assert u.targetHealthFactor != KEEP_CURRENT() => to_mathint(after.targetHealthFactor) == to_mathint(e.block.timestamp);
    assert u.targetHealthFactor == KEEP_CURRENT() => after.targetHealthFactor == before.targetHealthFactor;
    assert u.healthFactorForMaxBonus != KEEP_CURRENT() => to_mathint(after.healthFactorForMaxBonus) == to_mathint(e.block.timestamp);
    assert u.healthFactorForMaxBonus == KEEP_CURRENT() => after.healthFactorForMaxBonus == before.healthFactorForMaxBonus;
    assert u.liquidationBonusFactor != KEEP_CURRENT() => to_mathint(after.liquidationBonusFactor) == to_mathint(e.block.timestamp);
    assert u.liquidationBonusFactor == KEEP_CURRENT() => after.liquidationBonusFactor == before.liquidationBonusFactor;
    
    // Verify other spoke debounces are not updated
    assert otherAfter.targetHealthFactor == otherBefore.targetHealthFactor
        && otherAfter.healthFactorForMaxBonus == otherBefore.healthFactorForMaxBonus
        && otherAfter.liquidationBonusFactor == otherBefore.liquidationBonusFactor;
}

// Dynamic additions intentionally consume both shared debounce windows.
rule dynamicAdditionStampsBoth(env e, IAaveV4ConfigEngine.DynamicReserveConfigAddition a, address otherSpoke, address otherHub, address otherAsset) {
    require otherSpoke != a.spoke || otherHub != a.hub || otherAsset != a.underlying,"Other spoke, hub and asset must be different from the input";

    // Create a valid DynamicReserveConfigAddition array and constrain it to the input
    IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions;
    require additions.length == 1
        && additions[0].spokeConfigurator == a.spokeConfigurator
        && additions[0].spoke == a.spoke && additions[0].hub == a.hub
        && additions[0].underlying == a.underlying
        && additions[0].dynamicConfig.collateralFactor == a.dynamicConfig.collateralFactor
        && additions[0].dynamicConfig.maxLiquidationBonus == a.dynamicConfig.maxLiquidationBonus
        && additions[0].dynamicConfig.liquidationFee == a.dynamicConfig.liquidationFee;

    // Fetch the SpokeDynamicDebounce of other spoke, hub and asset before the update
    IRiskSteward.SpokeDynamicDebounce otherBefore = getSpokeDynamicDebounce(otherSpoke, otherHub, otherAsset);

    // Execute the update
    addDynamicReserveConfigs(e, additions);

    // Fetch the SpokeDynamicDebounce after the update
    IRiskSteward.SpokeDynamicDebounce after = getSpokeDynamicDebounce(a.spoke, a.hub, a.underlying);
    IRiskSteward.SpokeDynamicDebounce otherAfter = getSpokeDynamicDebounce(otherSpoke, otherHub, otherAsset);
    
    // Assert that both shared dynamic debounce fields stamp to tx time
    assert to_mathint(after.collateralFactor) == to_mathint(e.block.timestamp) && to_mathint(after.maxLiquidationBonus) == to_mathint(e.block.timestamp);
   
    // Verify other (spoke,hub,asset) pairs debounces are not updated
    assert otherAfter.collateralFactor == otherBefore.collateralFactor && otherAfter.maxLiquidationBonus == otherBefore.maxLiquidationBonus;
}
