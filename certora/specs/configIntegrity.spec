/*
 * RiskSteward — Invariants: `_config` storage discipline.
 *
 * Property: a successful setConfig stores exactly its argument, and no other
 * method can change `_config`.
 */

methods {
    function getConfig() external returns (IRiskSteward.Config) envfree;

    // See header: keep currentContract storage intact across external hops so R2
    // measures the real (unhavoced) `_config`.
    unresolved external in _._ => HAVOC_ECF;
}

// CVL cannot compare structs, so equality is spelled out. `Config` bottoms out
// in RiskParamConfig leaves, so only the leaf needs field-by-field work.
function paramEq(IRiskSteward.RiskParamConfig a, IRiskSteward.RiskParamConfig b) returns bool {
    return a.minDelay == b.minDelay
        && a.maxPercentChange == b.maxPercentChange
        && a.isChangeRelative == b.isChangeRelative;
}

// Compare two Config structs for equality
function configEq(IRiskSteward.Config a, IRiskSteward.Config b) returns bool {
    return a.hub.configurator == b.hub.configurator
        && paramEq(a.hub.rate.optimalUsageRatio, b.hub.rate.optimalUsageRatio)
        && paramEq(a.hub.rate.baseDrawnRate, b.hub.rate.baseDrawnRate)
        && paramEq(a.hub.rate.rateGrowthBeforeOptimal, b.hub.rate.rateGrowthBeforeOptimal)
        && paramEq(a.hub.rate.rateGrowthAfterOptimal, b.hub.rate.rateGrowthAfterOptimal)
        && paramEq(a.hub.cap.addCap, b.hub.cap.addCap)
        && paramEq(a.hub.cap.drawCap, b.hub.cap.drawCap)
        && a.spoke.configurator == b.spoke.configurator
        && paramEq(a.spoke.collateralRisk, b.spoke.collateralRisk)
        && paramEq(a.spoke.dynamicUpdate.collateralFactor, b.spoke.dynamicUpdate.collateralFactor)
        && paramEq(a.spoke.dynamicUpdate.maxLiquidationBonus, b.spoke.dynamicUpdate.maxLiquidationBonus)
        && paramEq(a.spoke.dynamicAdd.collateralFactor, b.spoke.dynamicAdd.collateralFactor)
        && paramEq(a.spoke.dynamicAdd.maxLiquidationBonus, b.spoke.dynamicAdd.maxLiquidationBonus)
        && paramEq(a.spoke.liquidation.targetHealthFactor, b.spoke.liquidation.targetHealthFactor)
        && paramEq(a.spoke.liquidation.healthFactorForMaxBonus, b.spoke.liquidation.healthFactorForMaxBonus)
        && paramEq(a.spoke.liquidation.liquidationBonusFactor, b.spoke.liquidation.liquidationBonusFactor)
        && paramEq(a.oracle.priceCapLst, b.oracle.priceCapLst)
        && paramEq(a.oracle.priceCapStable, b.oracle.priceCapStable)
        && paramEq(a.oracle.discountRatePendle, b.oracle.discountRatePendle);
}

// R1 — establishment: a non-reverting setConfig (owner + all 17 polarity
// requires passed) leaves `_config` equal to the validated argument.
rule setConfigWritesArg(env e, IRiskSteward.Config cfg) {
    // Execute setConfig
    setConfig(e, cfg);

    // Assert that `_config` equals the validated argument
    assert configEq(getConfig(), cfg);
}

// R2 — non-interference: every other method leaves `_config` byte-identical, i.e. setConfig is the sole writer.
rule configIntactExceptSetConfig(method f, env e)
    filtered { f -> f.selector != sig:setConfig(IRiskSteward.Config).selector }
{
    // Fetch `_config` before the call
    IRiskSteward.Config before = getConfig();
    calldataarg a;

    // Execute the call
    f(e, a);

    // Assert that `_config` was not touched
    assert configEq(getConfig(), before);
}
