// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './DirectionalRiskSteward.Base.t.sol';

abstract contract DirectionalRiskStewardSpokeLiquidationConfigsTest is
  DirectionalRiskStewardTestBase
{
  using SafeCast for uint256;

  uint256 internal constant TARGET_HEALTH_FACTOR = 0;
  uint256 internal constant HEALTH_FACTOR_FOR_MAX_BONUS = 1;
  uint256 internal constant LIQUIDATION_BONUS_FACTOR = 2;
  function test_updateSpokeLiquidationConfigs_allThree() public {
    ISpoke.LiquidationConfig memory current = MAIN_SPOKE.getLiquidationConfig();

    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.targetHealthFactor = (uint256(current.targetHealthFactor) * 103) / 100; // +3% relative
    u.healthFactorForMaxBonus = (uint256(current.healthFactorForMaxBonus) * 103) / 100;
    u.liquidationBonusFactor = uint256(current.liquidationBonusFactor) + 1_00; // absolute

    _assertUpdateSpokeLiquidationConfigs(u);
  }

  function test_updateSpokeLiquidationConfigs_allThree_decrease() public {
    ISpoke.LiquidationConfig memory current = MAIN_SPOKE.getLiquidationConfig();

    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.targetHealthFactor = (uint256(current.targetHealthFactor) * 99) / 100;
    u.healthFactorForMaxBonus = (uint256(current.healthFactorForMaxBonus) * 97) / 100;
    u.liquidationBonusFactor = uint256(current.liquidationBonusFactor) - 1_00;

    _assertUpdateSpokeLiquidationConfigs(u);
  }

  function test_fuzz_updateSpokeLiquidationConfigs_allThree(
    int256 targetHealthFactorDeltaBps,
    int256 healthFactorForMaxBonusDeltaBps,
    int256 liquidationBonusFactorDelta
  ) public {
    IDirectionalRiskSteward.SpokeLiquidationConfig memory liqBounds = steward
      .getConfig()
      .spoke
      .liquidation;
    ISpoke.LiquidationConfig memory current = MAIN_SPOKE.getLiquidationConfig();

    targetHealthFactorDeltaBps = _boundDelta(
      targetHealthFactorDeltaBps,
      liqBounds.targetHealthFactor.maxPercentChange
    );
    healthFactorForMaxBonusDeltaBps = _boundDelta(
      healthFactorForMaxBonusDeltaBps,
      liqBounds.healthFactorForMaxBonus.maxPercentChange
    );
    liquidationBonusFactorDelta = _boundDelta(
      liquidationBonusFactorDelta,
      liqBounds.liquidationBonusFactor.maxPercentChange
    );

    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.targetHealthFactor = _applyRelativeDelta({
      current: current.targetHealthFactor,
      deltaBps: targetHealthFactorDeltaBps,
      floor: 1e18 // HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    });
    u.healthFactorForMaxBonus = _applyRelativeDelta({
      current: current.healthFactorForMaxBonus,
      deltaBps: healthFactorForMaxBonusDeltaBps,
      floor: 0,
      ceiling: 1e18 - 1 // strictly < HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    });
    u.liquidationBonusFactor = _applyDelta({
      current: current.liquidationBonusFactor,
      delta: liquidationBonusFactorDelta,
      floor: 1, // avoid InvalidUpdateToZero
      ceiling: 100_00 // PERCENTAGE_FACTOR (protocol max)
    });

    _assertUpdateSpokeLiquidationConfigs(u);
  }

  function test_updateSpokeLiquidationConfigs_outOfRangeRelative_revertsWith_UpdateNotInRange()
    public
  {
    ISpoke.LiquidationConfig memory current = MAIN_SPOKE.getLiquidationConfig();
    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.targetHealthFactor = (uint256(current.targetHealthFactor) * 110) / 100; // +10% > 5% bound
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.UpdateNotInRange.selector);
    steward.updateSpokeLiquidationConfigs(_toArray(u));
  }

  function test_updateSpokeLiquidationConfigs_outOfRangeAbsolute_revertsWith_UpdateNotInRange()
    public
  {
    ISpoke.LiquidationConfig memory current = MAIN_SPOKE.getLiquidationConfig();
    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.liquidationBonusFactor = uint256(current.liquidationBonusFactor) + 5_01; // > 5_00 absolute
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.UpdateNotInRange.selector);
    steward.updateSpokeLiquidationConfigs(_toArray(u));
  }

  function test_updateSpokeLiquidationConfigs_revertsWith_InvalidUpdateToZero() public {
    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.targetHealthFactor = 0;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.InvalidUpdateToZero.selector);
    steward.updateSpokeLiquidationConfigs(_toArray(u));
  }

  function test_updateSpokeLiquidationConfigs_revertsWith_ConfiguratorMismatch() public {
    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.spokeConfigurator = ISpokeConfigurator(address(0xdead));

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.ConfiguratorMismatch.selector);
    steward.updateSpokeLiquidationConfigs(_toArray(u));
  }

  function test_updateSpokeLiquidationConfigs_whenSpokeRestricted_revertsWith_RestrictedAddress()
    public
  {
    ISpoke.LiquidationConfig memory current = MAIN_SPOKE.getLiquidationConfig();
    vm.prank(OWNER);
    steward.setAddressRestricted(address(MAIN_SPOKE), true);
    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.targetHealthFactor = current.targetHealthFactor;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(
      abi.encodeWithSelector(
        IDirectionalRiskSteward.RestrictedAddress.selector,
        address(MAIN_SPOKE)
      )
    );
    steward.updateSpokeLiquidationConfigs(_toArray(u));
  }

  function test_updateSpokeLiquidationConfigs_partialUpdate_onlyBumpsTouched() public {
    ISpoke.LiquidationConfig memory current = MAIN_SPOKE.getLiquidationConfig();
    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.liquidationBonusFactor = _allowedValue(
      uint256(current.liquidationBonusFactor) + 1_00,
      uint256(current.liquidationBonusFactor) - 1_00
    );
    vm.prank(RISK_COUNCIL);
    steward.updateSpokeLiquidationConfigs(_toArray(u));

    IDirectionalRiskSteward.SpokeLiquidationDebounce memory debounce = steward
      .getSpokeLiquidationDebounce(address(MAIN_SPOKE));
    assertEq(debounce.liquidationBonusFactor, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.targetHealthFactor, 0);
    assertEq(debounce.healthFactorForMaxBonus, 0);
  }

  function test_updateSpokeLiquidationConfigs_onLidoSpoke() public {
    // Lido's liquidationBonusFactor is already at its 100_00 max
    vm.skip(_direction() == IDirectionalRiskSteward.Direction.INCREASE);

    ISpoke.LiquidationConfig memory current = LIDO_SPOKE.getLiquidationConfig();

    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.spoke = address(LIDO_SPOKE);
    u.liquidationBonusFactor = uint256(current.liquidationBonusFactor) - 1_00;

    vm.prank(RISK_COUNCIL);
    steward.updateSpokeLiquidationConfigs(_toArray(u));

    assertEq(
      steward.getSpokeLiquidationDebounce(address(LIDO_SPOKE)).liquidationBonusFactor,
      vm.getBlockTimestamp().toUint40()
    );
  }

  function test_updateSpokeLiquidationConfigs_targetHealthFactorUp_othersAllowed() public {
    _assertUpdateSpokeLiquidationConfigs(_liquidationUpdateMoving(TARGET_HEALTH_FACTOR, true));
  }

  function test_updateSpokeLiquidationConfigs_targetHealthFactorDown_othersAllowed() public {
    _assertUpdateSpokeLiquidationConfigs(_liquidationUpdateMoving(TARGET_HEALTH_FACTOR, false));
  }

  function test_updateSpokeLiquidationConfigs_healthFactorForMaxBonusUp_othersAllowed() public {
    _assertUpdateSpokeLiquidationConfigs(
      _liquidationUpdateMoving(HEALTH_FACTOR_FOR_MAX_BONUS, true)
    );
  }

  function test_updateSpokeLiquidationConfigs_healthFactorForMaxBonusDown_othersAllowed() public {
    _assertUpdateSpokeLiquidationConfigs(
      _liquidationUpdateMoving(HEALTH_FACTOR_FOR_MAX_BONUS, false)
    );
  }

  function test_updateSpokeLiquidationConfigs_liquidationBonusFactorUp_othersAllowed() public {
    _assertUpdateSpokeLiquidationConfigs(_liquidationUpdateMoving(LIQUIDATION_BONUS_FACTOR, true));
  }

  function test_updateSpokeLiquidationConfigs_liquidationBonusFactorDown_othersAllowed() public {
    _assertUpdateSpokeLiquidationConfigs(_liquidationUpdateMoving(LIQUIDATION_BONUS_FACTOR, false));
  }

  /// @dev Moves `param` up or down (1% for the health factors, 1_00 BPS for the bonus factor) and
  /// every other param in the allowed direction.
  function _liquidationUpdateMoving(
    uint256 param,
    bool up
  ) internal view returns (IEngine.LiquidationConfigUpdate memory) {
    ISpoke.LiquidationConfig memory current = MAIN_SPOKE.getLiquidationConfig();
    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.targetHealthFactor = _move(
      current.targetHealthFactor,
      current.targetHealthFactor / 100,
      param == TARGET_HEALTH_FACTOR,
      up
    );
    u.healthFactorForMaxBonus = _move(
      current.healthFactorForMaxBonus,
      current.healthFactorForMaxBonus / 100,
      param == HEALTH_FACTOR_FOR_MAX_BONUS,
      up
    );
    u.liquidationBonusFactor = _move(
      current.liquidationBonusFactor,
      1_00,
      param == LIQUIDATION_BONUS_FACTOR,
      up
    );
    return u;
  }

  function _assertUpdateSpokeLiquidationConfigs(IEngine.LiquidationConfigUpdate memory u) internal {
    ISpoke.LiquidationConfig memory current = MAIN_SPOKE.getLiquidationConfig();
    bool allowed =
      _isDirectionAllowed(current.targetHealthFactor, u.targetHealthFactor) &&
        _isDirectionAllowed(current.healthFactorForMaxBonus, u.healthFactorForMaxBonus) &&
        _isDirectionAllowed(current.liquidationBonusFactor, u.liquidationBonusFactor);

    ISpoke.LiquidationConfig memory expected = ISpoke.LiquidationConfig({
      targetHealthFactor: u.targetHealthFactor.toUint128(),
      healthFactorForMaxBonus: u.healthFactorForMaxBonus.toUint64(),
      liquidationBonusFactor: u.liquidationBonusFactor.toUint16()
    });
    if (allowed) {
      vm.expectEmit(address(MAIN_SPOKE));
      emit ISpoke.UpdateLiquidationConfig(expected);
    } else {
      _expectDirectionRevert();
    }

    vm.prank(RISK_COUNCIL);
    steward.updateSpokeLiquidationConfigs(_toArray(u));
    if (!allowed) return;

    assertEq(MAIN_SPOKE.getLiquidationConfig(), expected);

    IDirectionalRiskSteward.SpokeLiquidationDebounce memory debounce = steward
      .getSpokeLiquidationDebounce(address(MAIN_SPOKE));
    assertEq(debounce.targetHealthFactor, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.healthFactorForMaxBonus, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.liquidationBonusFactor, vm.getBlockTimestamp().toUint40());
  }
}

contract DirectionalRiskStewardSpokeLiquidationConfigsBothTest is
  DirectionalRiskStewardSpokeLiquidationConfigsTest,
  DirectionBoth
{}

contract DirectionalRiskStewardSpokeLiquidationConfigsReduceTest is
  DirectionalRiskStewardSpokeLiquidationConfigsTest,
  DirectionReduce
{}

contract DirectionalRiskStewardSpokeLiquidationConfigsIncreaseTest is
  DirectionalRiskStewardSpokeLiquidationConfigsTest,
  DirectionIncrease
{}
