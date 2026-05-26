// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './RiskSteward.Base.t.sol';

contract RiskStewardAddDynamicReserveConfigsTest is RiskStewardTestBase {
  using SafeCast for uint256;

  /// @dev liquidationFee is immutable across dynamic configs for the same reserve since it doesn't
  /// affect risk.
  function test_addDynamicReserveConfigs() public {
    (ISpoke.DynamicReserveConfig memory ref, uint32 latestKey) = _dynamicReserveConfig(
      MAIN_SPOKE,
      HUB,
      ASSET
    );

    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.dynamicConfig.collateralFactor = ref.collateralFactor + 50;
    u.dynamicConfig.maxLiquidationBonus = ref.maxLiquidationBonus + 50;
    u.dynamicConfig.liquidationFee = ref.liquidationFee; // must equal previous

    uint256 reserveId = MAIN_SPOKE.getReserveId(address(HUB), HUB.getAssetId(ASSET));
    uint32 nextKey = latestKey + 1;
    vm.expectEmit(address(MAIN_SPOKE));
    emit ISpoke.AddDynamicReserveConfig(reserveId, nextKey, u.dynamicConfig);

    vm.prank(RISK_COUNCIL);
    steward.addDynamicReserveConfigs(_toArray(u));

    assertEq(MAIN_SPOKE.getDynamicReserveConfig(reserveId, nextKey), u.dynamicConfig);
    assertEq(MAIN_SPOKE.getReserve(reserveId).dynamicConfigKey, nextKey);

    IRiskSteward.SpokeDynamicDebounce memory debounce = steward.getSpokeDynamicDebounce(
      address(MAIN_SPOKE),
      address(HUB),
      ASSET,
      nextKey
    );
    assertEq(debounce.collateralFactor, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.maxLiquidationBonus, vm.getBlockTimestamp().toUint40());
  }

  function test_fuzz_addDynamicReserveConfigs(int256 cfDelta, int256 mlbDelta) public {
    IRiskSteward.SpokeDynamicConfig memory dynBounds = steward
      .getSpokeConfig(address(MAIN_SPOKE))
      .dynamicAdd;
    (ISpoke.DynamicReserveConfig memory ref, uint32 latestKey) = _dynamicReserveConfig(
      MAIN_SPOKE,
      HUB,
      ASSET
    );

    cfDelta = _boundDelta(cfDelta, dynBounds.collateralFactor.maxPercentChange);
    mlbDelta = _boundDelta(mlbDelta, dynBounds.maxLiquidationBonus.maxPercentChange);

    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.dynamicConfig.collateralFactor = _applyDelta({
      current: ref.collateralFactor,
      delta: cfDelta,
      floor: 1 // avoid InvalidUpdateToZero
    }).toUint16();
    u.dynamicConfig.maxLiquidationBonus = _applyDelta({
      current: ref.maxLiquidationBonus,
      delta: mlbDelta,
      floor: PercentageMath.PERCENTAGE_FACTOR
    }).toUint32();
    u.dynamicConfig.liquidationFee = ref.liquidationFee;

    uint256 reserveId = MAIN_SPOKE.getReserveId(address(HUB), HUB.getAssetId(ASSET));
    uint32 nextKey = latestKey + 1;
    vm.expectEmit(address(MAIN_SPOKE));
    emit ISpoke.AddDynamicReserveConfig(reserveId, nextKey, u.dynamicConfig);

    vm.prank(RISK_COUNCIL);
    steward.addDynamicReserveConfigs(_toArray(u));

    assertEq(MAIN_SPOKE.getDynamicReserveConfig(reserveId, nextKey), u.dynamicConfig);
    assertEq(MAIN_SPOKE.getReserve(reserveId).dynamicConfigKey, nextKey);

    IRiskSteward.SpokeDynamicDebounce memory debounce = steward.getSpokeDynamicDebounce(
      address(MAIN_SPOKE),
      address(HUB),
      ASSET,
      nextKey
    );
    assertEq(debounce.collateralFactor, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.maxLiquidationBonus, vm.getBlockTimestamp().toUint40());
  }

  function test_addDynamicReserveConfigs_revertsWith_ConfiguratorMismatch() public {
    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.spokeConfigurator = ISpokeConfigurator(address(0xdead));

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ConfiguratorMismatch.selector);
    steward.addDynamicReserveConfigs(_toArray(u));
  }

  function test_addDynamicReserveConfigs_revertsWith_UpdateNotInRange() public {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);

    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.dynamicConfig.collateralFactor = ref.collateralFactor + 5_01;
    u.dynamicConfig.liquidationFee = ref.liquidationFee;

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.addDynamicReserveConfigs(_toArray(u));
  }

  function test_addDynamicReserveConfigs_liquidationFeeDiffers_revertsWith_ParamChangeNotAllowed()
    public
  {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);

    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.dynamicConfig.collateralFactor = ref.collateralFactor;
    u.dynamicConfig.maxLiquidationBonus = ref.maxLiquidationBonus;
    u.dynamicConfig.liquidationFee = ref.liquidationFee + 1;

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    steward.addDynamicReserveConfigs(_toArray(u));
  }

  function test_addDynamicReserveConfigs_zeroCollateralFactor_revertsWith_InvalidUpdateToZero()
    public
  {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);

    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.dynamicConfig.collateralFactor = 0;
    u.dynamicConfig.liquidationFee = ref.liquidationFee;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
    steward.addDynamicReserveConfigs(_toArray(u));
  }

  function test_addDynamicReserveConfigs_zeroMaxLiquidationBonus_revertsWith_InvalidUpdateToZero()
    public
  {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);

    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.dynamicConfig.maxLiquidationBonus = 0;
    u.dynamicConfig.liquidationFee = ref.liquidationFee;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
    steward.addDynamicReserveConfigs(_toArray(u));
  }

  function test_addDynamicReserveConfigs_revertsWith_SpokeIsRestricted() public {
    vm.prank(OWNER);
    steward.setSpokeRestricted(address(MAIN_SPOKE), true);
    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.SpokeIsRestricted.selector);
    steward.addDynamicReserveConfigs(_toArray(u));
  }
}
