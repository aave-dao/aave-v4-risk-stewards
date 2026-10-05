// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './DirectionalRiskSteward.Base.t.sol';

abstract contract DirectionalRiskStewardHubAssetIRsTest is DirectionalRiskStewardTestBase {
  using SafeCast for *;

  uint256 internal constant OPTIMAL_USAGE_RATIO = 0;
  uint256 internal constant BASE_DRAWN_RATE = 1;
  uint256 internal constant RATE_GROWTH_BEFORE_OPTIMAL = 2;
  uint256 internal constant RATE_GROWTH_AFTER_OPTIMAL = 3;
  function test_updateHubAssetIRs() public {
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = current.optimalUsageRatio + 1_00;
    u.irData.baseDrawnRate = current.baseDrawnRate + 1_00;
    u.irData.rateGrowthBeforeOptimal = current.rateGrowthBeforeOptimal + 1_00;
    u.irData.rateGrowthAfterOptimal = current.rateGrowthAfterOptimal + 1_00;

    _assertUpdateHubAssetIRs(u);
  }

  function test_updateHubAssetIRs_decrease() public {
    _setBaseDrawnRate(1_00); // 0 on the fork, leaves no room to decrease
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = _applyDelta({
      current: current.optimalUsageRatio,
      delta: -1_00,
      floor: 1_00 // MIN_OPTIMAL_RATIO
    }).toUint16();
    u.irData.baseDrawnRate = _applyDelta({current: current.baseDrawnRate, delta: -1_00, floor: 0})
      .toUint32();
    u.irData.rateGrowthBeforeOptimal = _applyDelta({
      current: current.rateGrowthBeforeOptimal,
      delta: -1_00,
      floor: 0
    }).toUint32();
    u.irData.rateGrowthAfterOptimal = _applyDelta({
      current: current.rateGrowthAfterOptimal,
      delta: -1_00,
      floor: 0
    }).toUint32();

    _assertUpdateHubAssetIRs(u);
  }

  function test_fuzz_updateHubAssetIRs(
    int256 optUsageDelta,
    int256 baseDrawnDelta,
    int256 rateGrowthBeforeDelta,
    int256 rateGrowthAfterDelta
  ) public {
    IDirectionalRiskSteward.HubRateConfig memory rateBounds = steward.getConfig().hub.rate;
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);

    optUsageDelta = _boundDelta(optUsageDelta, rateBounds.optimalUsageRatio.maxPercentChange);
    baseDrawnDelta = _boundDelta(baseDrawnDelta, rateBounds.baseDrawnRate.maxPercentChange);
    rateGrowthBeforeDelta = _boundDelta(
      rateGrowthBeforeDelta,
      rateBounds.rateGrowthBeforeOptimal.maxPercentChange
    );
    rateGrowthAfterDelta = _boundDelta(
      rateGrowthAfterDelta,
      rateBounds.rateGrowthAfterOptimal.maxPercentChange
    );

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = _applyDelta({
      current: current.optimalUsageRatio,
      delta: optUsageDelta,
      floor: 1_00, // MIN_OPTIMAL_RATIO
      ceiling: 99_00 // MAX_OPTIMAL_RATIO
    }).toUint16();
    u.irData.baseDrawnRate = _applyDelta({
      current: current.baseDrawnRate,
      delta: baseDrawnDelta,
      floor: 0
    }).toUint32();
    u.irData.rateGrowthBeforeOptimal = _applyDelta({
      current: current.rateGrowthBeforeOptimal,
      delta: rateGrowthBeforeDelta,
      floor: 0
    }).toUint32();
    u.irData.rateGrowthAfterOptimal = _applyDelta({
      current: current.rateGrowthAfterOptimal,
      delta: rateGrowthAfterDelta,
      floor: 0
    }).toUint32();

    _assertUpdateHubAssetIRs(u);
  }

  function test_updateHubAssetIRs_keepCurrent_doesNotBumpTimelock() public {
    IEngine.AssetConfigUpdate memory u = _baseIRUpdate(); // all KEEP_CURRENT
    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(_toArray(u));

    IDirectionalRiskSteward.HubAssetDebounce memory debounce = steward.getHubAssetDebounce(
      address(HUB),
      ASSET
    );
    assertEq(debounce.optimalUsageRatio, 0);
    assertEq(debounce.baseDrawnRate, 0);
    assertEq(debounce.rateGrowthBeforeOptimal, 0);
    assertEq(debounce.rateGrowthAfterOptimal, 0);
  }

  function test_updateHubAssetIRs_partialUpdate_onlyBumpsTouched() public {
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = _allowedValue(
      current.optimalUsageRatio + 1_00,
      current.optimalUsageRatio - 1_00
    ).toUint16();

    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(_toArray(u));

    IDirectionalRiskSteward.HubAssetDebounce memory debounce = steward.getHubAssetDebounce(
      address(HUB),
      ASSET
    );
    assertEq(debounce.optimalUsageRatio, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.baseDrawnRate, 0);
    assertEq(debounce.rateGrowthBeforeOptimal, 0);
    assertEq(debounce.rateGrowthAfterOptimal, 0);
  }

  function test_updateHubAssetIRs_sameValueUpdate_succeeds_bumpsTimelock() public {
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = current.optimalUsageRatio; // same value

    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(_toArray(u));

    assertEq(
      steward.getHubAssetDebounce(address(HUB), ASSET).optimalUsageRatio,
      vm.getBlockTimestamp().toUint40()
    );
  }

  function test_updateHubAssetIRs_revertsWith_DebounceNotRespected() public {
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = _allowedValue(
      current.optimalUsageRatio + 1_00,
      current.optimalUsageRatio - 1_00
    ).toUint16();

    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(_toArray(u));

    // Try again same block.
    IEngine.AssetConfigUpdate memory u2 = _baseIRUpdate();
    u2.irData.optimalUsageRatio = current.optimalUsageRatio + 1_00;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.DebounceNotRespected.selector);
    steward.updateHubAssetIRs(_toArray(u2));
  }

  function test_updateHubAssetIRs_batchSameParam_lastEntryWins() public {
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);

    IEngine.AssetConfigUpdate memory u1 = _baseIRUpdate();
    u1.irData.optimalUsageRatio = _allowedValue(
      current.optimalUsageRatio + 50,
      current.optimalUsageRatio - 50
    ).toUint16(); // both within 3_00 bound
    IEngine.AssetConfigUpdate memory u2 = _baseIRUpdate();
    u2.irData.optimalUsageRatio = _allowedValue(
      current.optimalUsageRatio + 100,
      current.optimalUsageRatio - 100
    ).toUint16();

    IEngine.AssetConfigUpdate[] memory updates = new IEngine.AssetConfigUpdate[](2);
    updates[0] = u1;
    updates[1] = u2;

    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(updates);

    assertEq(
      steward.getHubAssetDebounce(address(HUB), ASSET).optimalUsageRatio,
      vm.getBlockTimestamp().toUint40()
    );
    // u2's value is the final on-chain value.
    assertEq(_interestRateData(HUB, ASSET).optimalUsageRatio, u2.irData.optimalUsageRatio);

    IEngine.AssetConfigUpdate memory u3 = _baseIRUpdate();
    u3.irData.optimalUsageRatio = current.optimalUsageRatio + 110;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.DebounceNotRespected.selector);
    steward.updateHubAssetIRs(_toArray(u3));
  }

  function test_updateHubAssetIRs_overUpperBound_revertsWith_UpdateNotInRange() public {
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);
    IDirectionalRiskSteward.HubConfig memory hubConfig = steward.getConfig().hub;
    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio =
      current.optimalUsageRatio +
      hubConfig.rate.optimalUsageRatio.maxPercentChange.toUint16() +
      1;

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.UpdateNotInRange.selector);
    steward.updateHubAssetIRs(_toArray(u));
  }

  function test_updateHubAssetIRs_underLowerBound_revertsWith_UpdateNotInRange() public {
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);
    IDirectionalRiskSteward.HubConfig memory hubConfig = steward.getConfig().hub;
    uint16 maxPercentageChange = hubConfig.rate.optimalUsageRatio.maxPercentChange.toUint16();
    vm.assume(current.optimalUsageRatio >= maxPercentageChange + 2); // need room to subtract

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = current.optimalUsageRatio - maxPercentageChange - 1;

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.UpdateNotInRange.selector);
    steward.updateHubAssetIRs(_toArray(u));
  }

  function test_updateHubAssetIRs_revertsWith_NoZeroUpdates() public {
    IEngine.AssetConfigUpdate[] memory updates = new IEngine.AssetConfigUpdate[](0);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.NoZeroUpdates.selector);
    steward.updateHubAssetIRs(updates);
  }

  function test_updateHubAssetIRs_zeroIsAllowed() public {
    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.baseDrawnRate = 0;

    bool allowed = _isDirectionAllowed(_interestRateData(HUB, ASSET).baseDrawnRate, 0);
    if (!allowed) _expectDirectionRevert();
    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(_toArray(u));
    if (!allowed) return;

    assertEq(
      steward.getHubAssetDebounce(address(HUB), ASSET).baseDrawnRate,
      vm.getBlockTimestamp().toUint40()
    );
  }

  function test_updateHubAssetIRs_revertsWith_ConfiguratorMismatch() public {
    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.hubConfigurator = IHubConfigurator(address(0xdead));

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.ConfiguratorMismatch.selector);
    steward.updateHubAssetIRs(_toArray(u));
  }

  function test_updateHubAssetIRs_whenHubRestricted_revertsWith_RestrictedAddress() public {
    vm.prank(OWNER);
    steward.setAddressRestricted(address(HUB), true);

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = _interestRateData(HUB, ASSET).optimalUsageRatio + 1_00;

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(
      abi.encodeWithSelector(IDirectionalRiskSteward.RestrictedAddress.selector, address(HUB))
    );
    steward.updateHubAssetIRs(_toArray(u));
  }

  function test_updateHubAssetIRs_whenAssetRestricted_revertsWith_RestrictedAddress() public {
    vm.prank(OWNER);
    steward.setAddressRestricted(ASSET, true);

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = _interestRateData(HUB, ASSET).optimalUsageRatio + 1_00;

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(
      abi.encodeWithSelector(IDirectionalRiskSteward.RestrictedAddress.selector, ASSET)
    );
    steward.updateHubAssetIRs(_toArray(u));
  }

  function test_updateHubAssetIRs_irStrategyChange_revertsWith_ParamChangeNotAllowed() public {
    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irStrategy = address(0xdead);

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateHubAssetIRs(_toArray(u));
  }

  function test_updateHubAssetIRs_feeReceiverChange_revertsWith_ParamChangeNotAllowed() public {
    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.feeReceiver = address(0xdead);

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateHubAssetIRs(_toArray(u));
  }

  function test_updateHubAssetIRs_reinvestmentControllerChange_revertsWith_ParamChangeNotAllowed()
    public
  {
    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.reinvestmentController = address(0xdead);

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateHubAssetIRs(_toArray(u));
  }

  function test_updateHubAssetIRs_liquidityFeeChange_revertsWith_ParamChangeNotAllowed() public {
    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.liquidityFee = 9_99;

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateHubAssetIRs(_toArray(u));
  }

  function test_updateHubAssetIRs_afterDebounce_succeeds() public {
    IAssetInterestRateStrategy.InterestRateData memory before = _interestRateData(HUB, ASSET);

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = _allowedValue(
      before.optimalUsageRatio + 1_00,
      before.optimalUsageRatio - 1_00
    ).toUint16();
    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(_toArray(u));

    IAssetInterestRateStrategy.InterestRateData memory afterFirst = _interestRateData(HUB, ASSET);

    skip(3 days + 1);
    IEngine.AssetConfigUpdate memory u2 = _baseIRUpdate();
    u2.irData.optimalUsageRatio = _allowedValue(
      afterFirst.optimalUsageRatio + 50,
      afterFirst.optimalUsageRatio - 50
    ).toUint16();
    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(_toArray(u2));

    assertEq(
      steward.getHubAssetDebounce(address(HUB), ASSET).optimalUsageRatio,
      vm.getBlockTimestamp().toUint40()
    );
    assertEq(_interestRateData(HUB, ASSET).optimalUsageRatio, u2.irData.optimalUsageRatio);
  }

  function test_updateHubAssetIRs_optimalUsageRatioUp_othersAllowed() public {
    _assertUpdateHubAssetIRs(_irUpdateMoving(OPTIMAL_USAGE_RATIO, true));
  }

  function test_updateHubAssetIRs_optimalUsageRatioDown_othersAllowed() public {
    _assertUpdateHubAssetIRs(_irUpdateMoving(OPTIMAL_USAGE_RATIO, false));
  }

  function test_updateHubAssetIRs_baseDrawnRateUp_othersAllowed() public {
    _assertUpdateHubAssetIRs(_irUpdateMoving(BASE_DRAWN_RATE, true));
  }

  function test_updateHubAssetIRs_baseDrawnRateDown_othersAllowed() public {
    _assertUpdateHubAssetIRs(_irUpdateMoving(BASE_DRAWN_RATE, false));
  }

  function test_updateHubAssetIRs_rateGrowthBeforeOptimalUp_othersAllowed() public {
    _assertUpdateHubAssetIRs(_irUpdateMoving(RATE_GROWTH_BEFORE_OPTIMAL, true));
  }

  function test_updateHubAssetIRs_rateGrowthBeforeOptimalDown_othersAllowed() public {
    _assertUpdateHubAssetIRs(_irUpdateMoving(RATE_GROWTH_BEFORE_OPTIMAL, false));
  }

  function test_updateHubAssetIRs_rateGrowthAfterOptimalUp_othersAllowed() public {
    _assertUpdateHubAssetIRs(_irUpdateMoving(RATE_GROWTH_AFTER_OPTIMAL, true));
  }

  function test_updateHubAssetIRs_rateGrowthAfterOptimalDown_othersAllowed() public {
    _assertUpdateHubAssetIRs(_irUpdateMoving(RATE_GROWTH_AFTER_OPTIMAL, false));
  }

  /// @dev Moves `param` up or down by 50 BPS and every other IR param in the allowed direction.
  function _irUpdateMoving(
    uint256 param,
    bool up
  ) internal returns (IEngine.AssetConfigUpdate memory) {
    _setBaseDrawnRate(1_00); // 0 on the fork, leaves no room to decrease
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);
    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = _move(
      current.optimalUsageRatio,
      50,
      param == OPTIMAL_USAGE_RATIO,
      up
    ).toUint16();
    u.irData.baseDrawnRate = _move(current.baseDrawnRate, 50, param == BASE_DRAWN_RATE, up)
      .toUint32();
    u.irData.rateGrowthBeforeOptimal = _move(
      current.rateGrowthBeforeOptimal,
      50,
      param == RATE_GROWTH_BEFORE_OPTIMAL,
      up
    ).toUint32();
    u.irData.rateGrowthAfterOptimal = _move(
      current.rateGrowthAfterOptimal,
      50,
      param == RATE_GROWTH_AFTER_OPTIMAL,
      up
    ).toUint32();
    return u;
  }

  function _setBaseDrawnRate(uint32 baseDrawnRate) internal {
    uint256 assetId = HUB.getAssetId(ASSET);
    IAssetInterestRateStrategy.InterestRateData memory irData = _interestRateData(HUB, ASSET);
    irData.baseDrawnRate = baseDrawnRate;
    vm.prank(address(steward));
    HUB_CONFIGURATOR.updateInterestRateData(address(HUB), assetId, abi.encode(irData));
  }

  function _assertUpdateHubAssetIRs(IEngine.AssetConfigUpdate memory u) internal {
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);
    bool allowed =
      _isDirectionAllowed(current.optimalUsageRatio, u.irData.optimalUsageRatio) &&
        _isDirectionAllowed(current.baseDrawnRate, u.irData.baseDrawnRate) &&
        _isDirectionAllowed(current.rateGrowthBeforeOptimal, u.irData.rateGrowthBeforeOptimal) &&
        _isDirectionAllowed(current.rateGrowthAfterOptimal, u.irData.rateGrowthAfterOptimal);

    uint256 assetId = HUB.getAssetId(ASSET);
    if (allowed) {
      vm.expectEmit(HUB.getAssetConfig(assetId).irStrategy);
      emit IAssetInterestRateStrategy.UpdateInterestRateData(
        address(HUB),
        assetId,
        u.irData.optimalUsageRatio,
        u.irData.baseDrawnRate,
        u.irData.rateGrowthBeforeOptimal,
        u.irData.rateGrowthAfterOptimal
      );
    } else {
      _expectDirectionRevert();
    }

    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(_toArray(u));
    if (!allowed) return;

    assertEq(_interestRateData(HUB, ASSET), u.irData);

    IDirectionalRiskSteward.HubAssetDebounce memory debounce = steward.getHubAssetDebounce(
      address(HUB),
      ASSET
    );
    assertEq(debounce.optimalUsageRatio, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.baseDrawnRate, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.rateGrowthBeforeOptimal, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.rateGrowthAfterOptimal, vm.getBlockTimestamp().toUint40());
  }
}

contract DirectionalRiskStewardHubAssetIRsBothTest is
  DirectionalRiskStewardHubAssetIRsTest,
  DirectionBoth
{}

contract DirectionalRiskStewardHubAssetIRsReduceTest is
  DirectionalRiskStewardHubAssetIRsTest,
  DirectionReduce
{}

contract DirectionalRiskStewardHubAssetIRsIncreaseTest is
  DirectionalRiskStewardHubAssetIRsTest,
  DirectionIncrease
{}
