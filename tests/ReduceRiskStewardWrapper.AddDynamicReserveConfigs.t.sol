// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './ReduceRiskStewardWrapper.Base.t.sol';

contract ReduceRiskStewardWrapperAddDynamicReserveConfigsTest is ReduceRiskStewardWrapperTestBase {
  using SafeCast for uint256;

  function test_addReducedDynamicReserveConfigs() public {
    (ISpoke.DynamicReserveConfig memory ref, uint32 latestKey) = _dynamicReserveConfig(
      MAIN_SPOKE,
      HUB,
      ASSET
    );
    IEngine.DynamicReserveConfigAddition memory u = _baseReducedAddDynamic(
      ref.collateralFactor - 1_00
    );

    uint256 reserveId = _reserveId(MAIN_SPOKE, HUB, ASSET);
    vm.expectEmit(address(MAIN_SPOKE));
    emit ISpoke.AddDynamicReserveConfig(reserveId, latestKey + 1, u.dynamicConfig);

    vm.prank(REDUCE_COUNCIL);
    wrapper.addReducedDynamicReserveConfigs(_toArray(u));

    assertEq(MAIN_SPOKE.getReserve(reserveId).dynamicConfigKey, latestKey + 1);
    assertEq(MAIN_SPOKE.getDynamicReserveConfig(reserveId, latestKey + 1), u.dynamicConfig);
    assertEq(MAIN_SPOKE.getDynamicReserveConfig(reserveId, latestKey), ref);

    IRiskSteward.SpokeDynamicDebounce memory debounce = steward.getSpokeDynamicDebounce(
      address(MAIN_SPOKE),
      address(HUB),
      ASSET
    );
    assertEq(debounce.collateralFactor, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.maxLiquidationBonus, vm.getBlockTimestamp().toUint40());
  }

  function test_fuzz_addReducedDynamicReserveConfigs(uint256 reduction) public {
    (ISpoke.DynamicReserveConfig memory ref, uint32 latestKey) = _dynamicReserveConfig(
      MAIN_SPOKE,
      HUB,
      ASSET
    );
    uint256 maxReduction = steward.getConfig().spoke.dynamicAdd.collateralFactor.maxPercentChange;
    reduction = bound(reduction, 1, _min(maxReduction, ref.collateralFactor - 1));

    IEngine.DynamicReserveConfigAddition memory u = _baseReducedAddDynamic(
      (ref.collateralFactor - reduction).toUint16()
    );

    vm.prank(REDUCE_COUNCIL);
    wrapper.addReducedDynamicReserveConfigs(_toArray(u));

    uint256 reserveId = _reserveId(MAIN_SPOKE, HUB, ASSET);
    assertEq(MAIN_SPOKE.getReserve(reserveId).dynamicConfigKey, latestKey + 1);
    assertEq(MAIN_SPOKE.getDynamicReserveConfig(reserveId, latestKey + 1), u.dynamicConfig);
  }

  function test_addReducedDynamicReserveConfigs_increase_revertsWith_UpdateNotReducing() public {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);
    IEngine.DynamicReserveConfigAddition memory u = _baseReducedAddDynamic(
      ref.collateralFactor + 1
    );

    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IReduceRiskStewardWrapper.UpdateNotReducing.selector);
    wrapper.addReducedDynamicReserveConfigs(_toArray(u));
  }

  function test_addReducedDynamicReserveConfigs_sameValue_revertsWith_UpdateNotReducing() public {
    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();

    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IReduceRiskStewardWrapper.UpdateNotReducing.selector);
    wrapper.addReducedDynamicReserveConfigs(_toArray(u));
  }

  function test_fuzz_addReducedDynamicReserveConfigs_increase_revertsWith_UpdateNotReducing(
    uint16 collateralFactor
  ) public {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);
    collateralFactor = bound(collateralFactor, ref.collateralFactor, type(uint16).max).toUint16();

    IEngine.DynamicReserveConfigAddition[] memory additions = _toArray(
      _baseReducedAddDynamic(collateralFactor)
    );
    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IReduceRiskStewardWrapper.UpdateNotReducing.selector);
    wrapper.addReducedDynamicReserveConfigs(additions);
  }

  function test_addReducedDynamicReserveConfigs_maxLiquidationBonusUp_revertsWith_ParamChangeNotAllowed()
    public
  {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);
    IEngine.DynamicReserveConfigAddition memory u = _baseReducedAddDynamic(
      ref.collateralFactor - 1
    );
    u.dynamicConfig.maxLiquidationBonus = ref.maxLiquidationBonus + 1;

    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IReduceRiskStewardWrapper.ParamChangeNotAllowed.selector);
    wrapper.addReducedDynamicReserveConfigs(_toArray(u));
  }

  function test_addReducedDynamicReserveConfigs_maxLiquidationBonusDown_revertsWith_ParamChangeNotAllowed()
    public
  {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);
    IEngine.DynamicReserveConfigAddition memory u = _baseReducedAddDynamic(
      ref.collateralFactor - 1
    );
    u.dynamicConfig.maxLiquidationBonus = ref.maxLiquidationBonus - 1;

    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IReduceRiskStewardWrapper.ParamChangeNotAllowed.selector);
    wrapper.addReducedDynamicReserveConfigs(_toArray(u));
  }

  function test_addReducedDynamicReserveConfigs_liquidationFeeDiffers_revertsWith_ParamChangeNotAllowed()
    public
  {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);
    IEngine.DynamicReserveConfigAddition memory u = _baseReducedAddDynamic(
      ref.collateralFactor - 1
    );
    u.dynamicConfig.liquidationFee = ref.liquidationFee + 1;

    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    wrapper.addReducedDynamicReserveConfigs(_toArray(u));
  }

  function test_addReducedDynamicReserveConfigs_zeroCollateralFactor_revertsWith_InvalidUpdateToZero()
    public
  {
    IEngine.DynamicReserveConfigAddition[] memory additions = _toArray(_baseReducedAddDynamic(0));
    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
    wrapper.addReducedDynamicReserveConfigs(additions);
  }

  function test_addReducedDynamicReserveConfigs_beyondStewardBound_revertsWith_UpdateNotInRange()
    public
  {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);
    uint256 maxReduction = steward.getConfig().spoke.dynamicAdd.collateralFactor.maxPercentChange;
    IEngine.DynamicReserveConfigAddition memory u = _baseReducedAddDynamic(
      (ref.collateralFactor - maxReduction - 1).toUint16()
    );

    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    wrapper.addReducedDynamicReserveConfigs(_toArray(u));
  }

  function test_addReducedDynamicReserveConfigs_tooSoon_revertsWith_DebounceNotRespected() public {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);
    IEngine.DynamicReserveConfigAddition[] memory first = _toArray(
      _baseReducedAddDynamic(ref.collateralFactor - 1_00)
    );
    vm.prank(REDUCE_COUNCIL);
    wrapper.addReducedDynamicReserveConfigs(first);

    skip(steward.getConfig().spoke.dynamicAdd.collateralFactor.minDelay - 1);

    IEngine.DynamicReserveConfigAddition[] memory second = _toArray(
      _baseReducedAddDynamic(ref.collateralFactor - 2_00)
    );
    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IRiskSteward.DebounceNotRespected.selector);
    wrapper.addReducedDynamicReserveConfigs(second);
  }

  function test_addReducedDynamicReserveConfigs_afterDelay_succeeds() public {
    (ISpoke.DynamicReserveConfig memory ref, uint32 latestKey) = _dynamicReserveConfig(
      MAIN_SPOKE,
      HUB,
      ASSET
    );
    IEngine.DynamicReserveConfigAddition[] memory first = _toArray(
      _baseReducedAddDynamic(ref.collateralFactor - 1_00)
    );
    vm.prank(REDUCE_COUNCIL);
    wrapper.addReducedDynamicReserveConfigs(first);

    skip(steward.getConfig().spoke.dynamicAdd.collateralFactor.minDelay);

    IEngine.DynamicReserveConfigAddition[] memory second = _toArray(
      _baseReducedAddDynamic(ref.collateralFactor - 2_00)
    );
    vm.prank(REDUCE_COUNCIL);
    wrapper.addReducedDynamicReserveConfigs(second);

    uint256 reserveId = _reserveId(MAIN_SPOKE, HUB, ASSET);
    assertEq(MAIN_SPOKE.getReserve(reserveId).dynamicConfigKey, latestKey + 2);
    assertEq(
      MAIN_SPOKE.getDynamicReserveConfig(reserveId, latestKey + 2).collateralFactor,
      ref.collateralFactor - 2_00
    );
  }

  /// @dev A second reduction is measured against the key the first one appended.
  function test_addReducedDynamicReserveConfigs_measuredAgainstLatestKey_afterPriorReduction()
    public
  {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);
    IEngine.DynamicReserveConfigAddition[] memory first = _toArray(
      _baseReducedAddDynamic(ref.collateralFactor - 2_00)
    );
    vm.prank(REDUCE_COUNCIL);
    wrapper.addReducedDynamicReserveConfigs(first);

    skip(steward.getConfig().spoke.dynamicAdd.collateralFactor.minDelay);

    // below the original key, above the latest one
    IEngine.DynamicReserveConfigAddition[] memory second = _toArray(
      _baseReducedAddDynamic(ref.collateralFactor - 1_00)
    );
    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IReduceRiskStewardWrapper.UpdateNotReducing.selector);
    wrapper.addReducedDynamicReserveConfigs(second);
  }

  /// @dev After governance appends a key with a higher CF, a reduction is measured against it.
  function test_addReducedDynamicReserveConfigs_measuredAgainstLatestKey_afterGovernanceRaise()
    public
  {
    (ISpoke.DynamicReserveConfig memory ref, uint32 latestKey) = _dynamicReserveConfig(
      MAIN_SPOKE,
      HUB,
      ASSET
    );
    uint256 reserveId = _reserveId(MAIN_SPOKE, HUB, ASSET);
    ISpoke.DynamicReserveConfig memory raised = ISpoke.DynamicReserveConfig({
      collateralFactor: ref.collateralFactor + 2_00,
      maxLiquidationBonus: ref.maxLiquidationBonus,
      liquidationFee: ref.liquidationFee
    });

    vm.prank(GOVERNANCE);
    SPOKE_CONFIGURATOR.addDynamicReserveConfig(address(MAIN_SPOKE), reserveId, raised);

    // above the original key, below the latest one
    IEngine.DynamicReserveConfigAddition memory u = _baseReducedAddDynamic(
      ref.collateralFactor + 1_00
    );
    vm.prank(REDUCE_COUNCIL);
    wrapper.addReducedDynamicReserveConfigs(_toArray(u));

    assertEq(MAIN_SPOKE.getReserve(reserveId).dynamicConfigKey, latestKey + 2);
    assertEq(MAIN_SPOKE.getDynamicReserveConfig(reserveId, latestKey + 2), u.dynamicConfig);
  }

  function test_addReducedDynamicReserveConfigs_increaseInBatch_revertsWith_UpdateNotReducing()
    public
  {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);

    IEngine.DynamicReserveConfigAddition[]
      memory additions = new IEngine.DynamicReserveConfigAddition[](2);
    additions[0] = _baseReducedAddDynamic(ref.collateralFactor - 1_00);
    additions[1] = _baseReducedAddDynamic(ref.collateralFactor + 1);

    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IReduceRiskStewardWrapper.UpdateNotReducing.selector);
    wrapper.addReducedDynamicReserveConfigs(additions);
  }

  function test_addReducedDynamicReserveConfigs_emptyAdditions_revertsWith_NoZeroUpdates() public {
    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IRiskSteward.NoZeroUpdates.selector);
    wrapper.addReducedDynamicReserveConfigs(new IEngine.DynamicReserveConfigAddition[](0));
  }

  function test_addReducedDynamicReserveConfigs_whenSpokeRestricted_revertsWith_RestrictedAddress()
    public
  {
    vm.prank(OWNER);
    steward.setAddressRestricted(address(MAIN_SPOKE), true);

    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);
    IEngine.DynamicReserveConfigAddition[] memory additions = _toArray(
      _baseReducedAddDynamic(ref.collateralFactor - 1)
    );
    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(
      abi.encodeWithSelector(IRiskSteward.RestrictedAddress.selector, address(MAIN_SPOKE))
    );
    wrapper.addReducedDynamicReserveConfigs(additions);
  }

  function test_addReducedDynamicReserveConfigs_configuratorMismatch_revertsWith_ConfiguratorMismatch()
    public
  {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);
    IEngine.DynamicReserveConfigAddition memory u = _baseReducedAddDynamic(
      ref.collateralFactor - 1
    );
    u.spokeConfigurator = ISpokeConfigurator(address(0xdead));

    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IRiskSteward.ConfiguratorMismatch.selector);
    wrapper.addReducedDynamicReserveConfigs(_toArray(u));
  }

  function _min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }
}
