/*
 * RiskSteward — Access Control.
 *
 * Property: only RISK_COUNCIL can call update entrypoints, only the owner can
 * change config, RISK_COUNCIL never moves, and no call can name a restricted address.
 */

methods {
    function RISK_COUNCIL() external returns (address) envfree;
    function owner()        external returns (address) envfree;
    function isAddressRestricted(address addr) external returns (bool) envfree;
}

// Owner-gated config entrypoints, both onlyOwner.
definition isOwnerEntrypoint(method f) returns bool =
    f.selector == sig:setConfig(IRiskSteward.Config).selector ||
    f.selector == sig:setAddressRestricted(address,bool).selector;

// Ownable2Step ownership-handover functions: owner/pendingOwner gated, NOT
// council gated.
definition isOwnershipHandover(method f) returns bool =
    f.selector == sig:transferOwnership(address).selector ||
    f.selector == sig:acceptOwnership().selector ||
    f.selector == sig:renounceOwnership().selector;

// Council entrypoints = every mutating entrypoint that isn't owner-gated or an
// ownership handover. 
definition isCouncilEntrypoint(method f) returns bool =
    !f.isView && !f.isPure && !isOwnerEntrypoint(f) && !isOwnershipHandover(f);

// ---------------------------------------------------------------------------
// The council half: any sender != RISK_COUNCIL reverts.
// Covers third parties and address(0) (RISK_COUNCIL is immutable & nonzero).
// ---------------------------------------------------------------------------

rule councilOnly(method f, env e) filtered { f -> isCouncilEntrypoint(f) } {
    require e.msg.sender != RISK_COUNCIL();
    calldataarg a;

    // Execute the call
    f@withrevert(e, a);

    // Assert that a non-council caller reverts
    assert lastReverted;
}

// ---------------------------------------------------------------------------
// The owner cannot call a council entrypoint unless the owner is
// also RISK_COUNCIL.
// ---------------------------------------------------------------------------

rule ownerOnly(method f, env e) filtered { f -> isOwnerEntrypoint(f) } {
    require e.msg.sender != owner();
    calldataarg a;

    // Execute the call
    f@withrevert(e, a);

    // Assert that a non-owner caller reverts
    assert lastReverted;
}

// ---------------------------------------------------------------------------
// The owner cannot call a council entrypoint unless the owner is
// also RISK_COUNCIL. 
// ---------------------------------------------------------------------------

rule ownerCannotCallCouncilEntrypoints(method f, env e) filtered { f -> isCouncilEntrypoint(f) }
{
    require e.msg.sender == owner();
    calldataarg a;
    
    // Execute the call
    f@withrevert(e, a);

    // Assert that an owner who is not also RISK_COUNCIL reverts
    assert !lastReverted => owner() == RISK_COUNCIL();
}

// ---------------------------------------------------------------------------
// Restricted-address gate — target-side authorization
// ---------------------------------------------------------------------------

rule restrictedHubAssetIRsReverts(env e, IAaveV4ConfigEngine.AssetConfigUpdate[] updates, uint256 i) {
    require i < updates.length,"Make sure i is in bounds";

    // Check if any named address is owner-restricted
    bool restricted = isAddressRestricted(updates[i].hub) || isAddressRestricted(updates[i].underlying);

    // Execute the update
    updateHubAssetIRs@withrevert(e, updates);

    // Assert that a restricted address causes a revert
    assert restricted => lastReverted;
}

rule restrictedHubSpokeCapsReverts(env e, IAaveV4ConfigEngine.SpokeConfigUpdate[] updates, uint256 i) {
    require i < updates.length,"Make sure i is in bounds";

    // Check if any named address is owner-restricted
    bool restricted = isAddressRestricted(updates[i].hub)
        || isAddressRestricted(updates[i].spoke)
        || isAddressRestricted(updates[i].underlying);

    // Execute the update
    updateHubSpokeCaps@withrevert(e, updates);

    // Assert that a restricted address causes a revert
    assert restricted => lastReverted;
}

rule restrictedReserveConfigsReverts(env e, IAaveV4ConfigEngine.ReserveConfigUpdate[] updates, uint256 i) {
    require i < updates.length,"Make sure i is in bounds";

    // Check if any named address is owner-restricted
    bool restricted = isAddressRestricted(updates[i].spoke)
        || isAddressRestricted(updates[i].hub)
        || isAddressRestricted(updates[i].underlying);

    // Execute the update
    updateReserveConfigs@withrevert(e, updates);

    // Assert that a restricted address causes a revert
    assert restricted => lastReverted;
}

rule restrictedDynamicReserveConfigsReverts(env e, IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates, uint256 i) {
    require i < updates.length,"Make sure i is in bounds";

    // Check if any named address is owner-restricted
    bool restricted = isAddressRestricted(updates[i].spoke)
        || isAddressRestricted(updates[i].hub)
        || isAddressRestricted(updates[i].underlying);

    // Execute the update
    updateDynamicReserveConfigs@withrevert(e, updates);

    // Assert that a restricted address causes a revert
    assert restricted => lastReverted;
}

rule restrictedAddDynamicReserveConfigsReverts(env e, IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions, uint256 i) {
    require i < additions.length,"Make sure i is in bounds";

    // Check if any named address is owner-restricted
    bool restricted = isAddressRestricted(additions[i].spoke)
        || isAddressRestricted(additions[i].hub)
        || isAddressRestricted(additions[i].underlying);

    // Execute the update
    addDynamicReserveConfigs@withrevert(e, additions);

    // Assert that a restricted address causes a revert
    assert restricted => lastReverted;
}

// Liquidation config is spoke-global, so the spoke is the only address named.
rule restrictedSpokeLiquidationConfigsReverts(env e, IAaveV4ConfigEngine.LiquidationConfigUpdate[] updates, uint256 i) {
    require i < updates.length,"Make sure i is in bounds";

    // Check if the named spoke is owner-restricted
    bool restricted = isAddressRestricted(updates[i].spoke);

    // Execute the update
    updateSpokeLiquidationConfigs@withrevert(e, updates);

    // Assert that a restricted address causes a revert
    assert restricted => lastReverted;
}

rule restrictedLstPriceCapsReverts(env e, IRiskSteward.PriceCapLstUpdate[] updates, uint256 i) {
    require i < updates.length,"Make sure i is in bounds";

    // Check if the named oracle is owner-restricted
    bool restricted = isAddressRestricted(updates[i].oracle);

    // Execute the update
    updateLstPriceCaps@withrevert(e, updates);

    // Assert that a restricted address causes a revert
    assert restricted => lastReverted;
}

rule restrictedStablePriceCapsReverts(env e, IRiskSteward.PriceCapStableUpdate[] updates, uint256 i) {
    require i < updates.length,"Make sure i is in bounds";

    // Check if the named oracle is owner-restricted
    bool restricted = isAddressRestricted(updates[i].oracle);

    // Execute the update
    updateStablePriceCaps@withrevert(e, updates);

    // Assert that a restricted address causes a revert
    assert restricted => lastReverted;
}

rule restrictedPendleDiscountRatesReverts(env e, IRiskSteward.DiscountRatePendleUpdate[] updates, uint256 i) {
    require i < updates.length,"Make sure i is in bounds";

    // Check if the named oracle is owner-restricted
    bool restricted = isAddressRestricted(updates[i].oracle);

    // Execute the update
    updatePendleDiscountRates@withrevert(e, updates);

    // Assert that a restricted address causes a revert
    assert restricted => lastReverted;
}

rule setAddressRestrictedTouchesOnlyItsKey(env e, address a, bool v, address other) {
    require other != a;
    
    // Fetch the restricted status before the update
    bool before = isAddressRestricted(other);

    // Execute the update
    setAddressRestricted(e, a, v);

    // Assert that the restricted status was not touched for the other address
    assert isAddressRestricted(a) == v && isAddressRestricted(other) == before;
}