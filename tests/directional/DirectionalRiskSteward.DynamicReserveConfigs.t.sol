// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './DirectionalRiskSteward.Base.t.sol';

abstract contract DirectionalRiskStewardDynamicReserveConfigsTest is
  DirectionalRiskStewardTestBase
{
  using SafeCast for uint256;

  uint256 internal constant COLLATERAL_FACTOR = 0;
  uint256 internal constant MAX_LIQUIDATION_BONUS = 1;
  function test_updateDynamicReserveConfigs() public {
    (ISpoke.DynamicReserveConfig memory current, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);

    IEngine.DynamicReserveConfigUpdate memory u = _baseDynamicUpdate();
    u.collateralFactor = current.collateralFactor + 50;
    u.maxLiquidationBonus = current.maxLiquidationBonus + 50;

    _assertUpdateDynamicReserveConfigs(u);
  }

  function test_updateDynamicReserveConfigs_decrease() public {
    (ISpoke.DynamicReserveConfig memory current, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);

    IEngine.DynamicReserveConfigUpdate memory u = _baseDynamicUpdate();
    u.collateralFactor = current.collateralFactor - 50;
    u.maxLiquidationBonus = current.maxLiquidationBonus - 50;

    _assertUpdateDynamicReserveConfigs(u);
  }

  function test_fuzz_updateDynamicReserveConfigs(int256 cfDelta, int256 mlbDelta) public {
    IDirectionalRiskSteward.SpokeDynamicConfig memory dynBounds = steward
      .getConfig()
      .spoke
      .dynamicUpdate;
    (ISpoke.DynamicReserveConfig memory current, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);

    cfDelta = _boundDelta(cfDelta, dynBounds.collateralFactor.maxPercentChange);
    mlbDelta = _boundDelta(mlbDelta, dynBounds.maxLiquidationBonus.maxPercentChange);

    IEngine.DynamicReserveConfigUpdate memory u = _baseDynamicUpdate();
    u.collateralFactor = _applyDelta({
      current: current.collateralFactor,
      delta: cfDelta,
      floor: 1 // avoid InvalidUpdateToZero
    });
    u.maxLiquidationBonus = _applyDelta({
      current: current.maxLiquidationBonus,
      delta: mlbDelta,
      floor: PercentageMath.PERCENTAGE_FACTOR
    });

    _assertUpdateDynamicReserveConfigs(u);
  }

  function test_updateDynamicReserveConfigs_revertsWith_UpdateNotInRange() public {
    (ISpoke.DynamicReserveConfig memory current, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);

    IEngine.DynamicReserveConfigUpdate memory u = _baseDynamicUpdate();
    u.collateralFactor = uint256(current.collateralFactor) + 51;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.UpdateNotInRange.selector);
    steward.updateDynamicReserveConfigs(_toArray(u));
  }

  function test_updateDynamicReserveConfigs_revertsWith_ConfiguratorMismatch() public {
    IEngine.DynamicReserveConfigUpdate memory u = _baseDynamicUpdate();
    u.spokeConfigurator = ISpokeConfigurator(address(0xdead));

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.ConfiguratorMismatch.selector);
    steward.updateDynamicReserveConfigs(_toArray(u));
  }

  function test_updateDynamicReserveConfigs_revertsWith_DebounceNotRespected() public {
    (ISpoke.DynamicReserveConfig memory current, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);

    IEngine.DynamicReserveConfigUpdate memory u = _baseDynamicUpdate();
    u.collateralFactor = _allowedValue(
      uint256(current.collateralFactor) + 50,
      uint256(current.collateralFactor) - 50
    );
    vm.prank(RISK_COUNCIL);
    steward.updateDynamicReserveConfigs(_toArray(u));

    IEngine.DynamicReserveConfigUpdate memory u2 = _baseDynamicUpdate();
    u2.collateralFactor = uint256(current.collateralFactor) + 1;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.DebounceNotRespected.selector);
    steward.updateDynamicReserveConfigs(_toArray(u2));
  }

  function test_updateDynamicReserveConfigs_liquidationFeeChange_revertsWith_ParamChangeNotAllowed()
    public
  {
    IEngine.DynamicReserveConfigUpdate memory u = _baseDynamicUpdate();
    u.liquidationFee = 5_00;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateDynamicReserveConfigs(_toArray(u));
  }

  function test_updateDynamicReserveConfigs_zeroCollateralFactor_revertsWith_InvalidUpdateToZero()
    public
  {
    IEngine.DynamicReserveConfigUpdate memory u = _baseDynamicUpdate();
    u.collateralFactor = 0;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.InvalidUpdateToZero.selector);
    steward.updateDynamicReserveConfigs(_toArray(u));
  }

  function test_updateDynamicReserveConfigs_zeroMaxLiquidationBonus_revertsWith_InvalidUpdateToZero()
    public
  {
    IEngine.DynamicReserveConfigUpdate memory u = _baseDynamicUpdate();
    u.maxLiquidationBonus = 0;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.InvalidUpdateToZero.selector);
    steward.updateDynamicReserveConfigs(_toArray(u));
  }

  function test_updateDynamicReserveConfigs_collateralFactorUp_othersAllowed() public {
    _assertUpdateDynamicReserveConfigs(_dynamicUpdateMoving(COLLATERAL_FACTOR, true));
  }

  function test_updateDynamicReserveConfigs_collateralFactorDown_othersAllowed() public {
    _assertUpdateDynamicReserveConfigs(_dynamicUpdateMoving(COLLATERAL_FACTOR, false));
  }

  function test_updateDynamicReserveConfigs_maxLiquidationBonusUp_othersAllowed() public {
    _assertUpdateDynamicReserveConfigs(_dynamicUpdateMoving(MAX_LIQUIDATION_BONUS, true));
  }

  function test_updateDynamicReserveConfigs_maxLiquidationBonusDown_othersAllowed() public {
    _assertUpdateDynamicReserveConfigs(_dynamicUpdateMoving(MAX_LIQUIDATION_BONUS, false));
  }

  /// @dev Moves `param` up or down by 50 BPS and the other param in the allowed direction.
  function _dynamicUpdateMoving(
    uint256 param,
    bool up
  ) internal view returns (IEngine.DynamicReserveConfigUpdate memory) {
    (ISpoke.DynamicReserveConfig memory current, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);
    IEngine.DynamicReserveConfigUpdate memory u = _baseDynamicUpdate();
    u.collateralFactor = _move(current.collateralFactor, 50, param == COLLATERAL_FACTOR, up);
    u.maxLiquidationBonus = _move(
      current.maxLiquidationBonus,
      50,
      param == MAX_LIQUIDATION_BONUS,
      up
    );
    return u;
  }

  function _assertUpdateDynamicReserveConfigs(
    IEngine.DynamicReserveConfigUpdate memory u
  ) internal {
    (ISpoke.DynamicReserveConfig memory current, uint32 latestKey) = _dynamicReserveConfig(
      MAIN_SPOKE,
      HUB,
      ASSET
    );
    bool allowed =
      _isDirectionAllowed(current.collateralFactor, u.collateralFactor) &&
        _isDirectionAllowed(current.maxLiquidationBonus, u.maxLiquidationBonus);

    uint256 reserveId = MAIN_SPOKE.getReserveId(address(HUB), HUB.getAssetId(ASSET));
    ISpoke.DynamicReserveConfig memory expected = ISpoke.DynamicReserveConfig({
      collateralFactor: u.collateralFactor.toUint16(),
      maxLiquidationBonus: u.maxLiquidationBonus.toUint32(),
      liquidationFee: current.liquidationFee
    });
    if (allowed) {
      vm.expectEmit(address(MAIN_SPOKE));
      emit ISpoke.UpdateDynamicReserveConfig(reserveId, latestKey, expected);
    } else {
      _expectDirectionRevert();
    }

    vm.prank(RISK_COUNCIL);
    steward.updateDynamicReserveConfigs(_toArray(u));
    if (!allowed) return;

    (ISpoke.DynamicReserveConfig memory updated, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);
    assertEq(updated, expected);

    IDirectionalRiskSteward.SpokeDynamicDebounce memory debounce = steward.getSpokeDynamicDebounce(
      address(MAIN_SPOKE),
      address(HUB),
      ASSET
    );
    assertEq(debounce.collateralFactor, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.maxLiquidationBonus, vm.getBlockTimestamp().toUint40());
  }
}

contract DirectionalRiskStewardDynamicReserveConfigsBothTest is
  DirectionalRiskStewardDynamicReserveConfigsTest,
  DirectionBoth
{}

contract DirectionalRiskStewardDynamicReserveConfigsReduceTest is
  DirectionalRiskStewardDynamicReserveConfigsTest,
  DirectionReduce
{}

contract DirectionalRiskStewardDynamicReserveConfigsIncreaseTest is
  DirectionalRiskStewardDynamicReserveConfigsTest,
  DirectionIncrease
{}
