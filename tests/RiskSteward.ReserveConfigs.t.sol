// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './RiskSteward.Base.t.sol';

contract RiskStewardReserveConfigsTest is RiskStewardTestBase {
  using SafeCast for uint256;

  function test_updateReserveConfigs() public {
    uint256 reserveId = MAIN_SPOKE.getReserveId(address(HUB), HUB.getAssetId(ASSET));

    vm.prank(address(steward));
    SPOKE_CONFIGURATOR.updateCollateralRisk(address(MAIN_SPOKE), reserveId, 10_00);

    ISpoke.ReserveConfig memory current = _reserveConfig(MAIN_SPOKE, HUB, ASSET);
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.collateralRisk = (uint256(current.collateralRisk) * 110) / 100; // +10%, within 20% bound

    ISpoke.ReserveConfig memory expected = current;
    expected.collateralRisk = u.collateralRisk.toUint24();
    vm.expectEmit(address(MAIN_SPOKE));
    emit ISpoke.UpdateReserveConfig(reserveId, expected);

    vm.prank(RISK_COUNCIL);
    steward.updateReserveConfigs(_toArray(u));

    assertEq(_reserveConfig(MAIN_SPOKE, HUB, ASSET), expected);

    IRiskSteward.SpokeReserveDebounce memory debounce = steward.getSpokeReserveDebounce(
      address(MAIN_SPOKE),
      address(HUB),
      ASSET
    );
    assertEq(debounce.collateralRisk, vm.getBlockTimestamp().toUint40());
  }

  function test_fuzz_updateReserveConfigs(int256 delta) public {
    uint256 reserveId = MAIN_SPOKE.getReserveId(address(HUB), HUB.getAssetId(ASSET));

    vm.prank(address(steward));
    SPOKE_CONFIGURATOR.updateCollateralRisk(address(MAIN_SPOKE), reserveId, 10_00);
    ISpoke.ReserveConfig memory current = _reserveConfig(MAIN_SPOKE, HUB, ASSET);

    IRiskSteward.RiskParamConfig memory crBounds = steward.getConfig().spoke.collateralRisk;
    delta = _boundDelta(delta, crBounds.maxPercentChange);

    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.collateralRisk = _applyDelta({
      current: current.collateralRisk,
      delta: delta,
      floor: 0 // collateralRisk = 0 is allowed by the steward
    });

    ISpoke.ReserveConfig memory expected = current;
    expected.collateralRisk = u.collateralRisk.toUint24();
    vm.expectEmit(address(MAIN_SPOKE));
    emit ISpoke.UpdateReserveConfig(reserveId, expected);

    vm.prank(RISK_COUNCIL);
    steward.updateReserveConfigs(_toArray(u));

    assertEq(_reserveConfig(MAIN_SPOKE, HUB, ASSET), expected);

    IRiskSteward.SpokeReserveDebounce memory debounce = steward.getSpokeReserveDebounce(
      address(MAIN_SPOKE),
      address(HUB),
      ASSET
    );
    assertEq(debounce.collateralRisk, vm.getBlockTimestamp().toUint40());
  }

  function test_updateReserveConfigs_fromZero_succeeds() public {
    ISpoke.ReserveConfig memory current = _reserveConfig(MAIN_SPOKE, HUB, ASSET);
    assertEq(current.collateralRisk, 0);

    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.collateralRisk = 20_00; // exactly the configured maxPercentChange
    vm.prank(RISK_COUNCIL);
    steward.updateReserveConfigs(_toArray(u));

    assertEq(_reserveConfig(MAIN_SPOKE, HUB, ASSET).collateralRisk, 20_00);
  }

  function test_updateReserveConfigs_outOfRange_revertsWith_UpdateNotInRange() public {
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.collateralRisk = 20_01;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateReserveConfigs(_toArray(u));
  }

  function test_updateReserveConfigs_priceSourceChange_revertsWith_ParamChangeNotAllowed() public {
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.priceSource = address(0xdead);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateReserveConfigs(_toArray(u));
  }

  function test_updateReserveConfigs_pausedChange_revertsWith_ParamChangeNotAllowed() public {
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.paused = 1;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateReserveConfigs(_toArray(u));
  }

  function test_updateReserveConfigs_frozenChange_revertsWith_ParamChangeNotAllowed() public {
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.frozen = 1;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateReserveConfigs(_toArray(u));
  }

  function test_updateReserveConfigs_borrowableChange_revertsWith_ParamChangeNotAllowed() public {
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.borrowable = 0;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateReserveConfigs(_toArray(u));
  }

  function test_updateReserveConfigs_receiveSharesEnabledChange_revertsWith_ParamChangeNotAllowed()
    public
  {
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.receiveSharesEnabled = 0;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateReserveConfigs(_toArray(u));
  }

  function test_updateReserveConfigs_zeroIsAllowed() public {
    uint256 reserveId = MAIN_SPOKE.getReserveId(address(HUB), HUB.getAssetId(ASSET));

    vm.prank(address(steward));
    SPOKE_CONFIGURATOR.updateCollateralRisk(address(MAIN_SPOKE), reserveId, 100);

    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.collateralRisk = 0;

    ISpoke.ReserveConfig memory expected = _reserveConfig(MAIN_SPOKE, HUB, ASSET);
    expected.collateralRisk = 0;
    vm.expectEmit(address(MAIN_SPOKE));
    emit ISpoke.UpdateReserveConfig(reserveId, expected);

    vm.prank(RISK_COUNCIL);
    steward.updateReserveConfigs(_toArray(u));

    assertEq(_reserveConfig(MAIN_SPOKE, HUB, ASSET), expected);
    assertEq(
      steward.getSpokeReserveDebounce(address(MAIN_SPOKE), address(HUB), ASSET).collateralRisk,
      vm.getBlockTimestamp().toUint40()
    );
  }

  function test_updateReserveConfigs_revertsWith_ConfiguratorMismatch() public {
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.spokeConfigurator = ISpokeConfigurator(address(0xdead));

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ConfiguratorMismatch.selector);
    steward.updateReserveConfigs(_toArray(u));
  }

  function test_updateReserveConfigs_revertsWith_HubIsRestricted() public {
    ISpoke.ReserveConfig memory current = _reserveConfig(MAIN_SPOKE, HUB, ASSET);
    vm.prank(OWNER);
    steward.setHubRestricted(address(HUB), true);
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.collateralRisk = current.collateralRisk;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.HubIsRestricted.selector);
    steward.updateReserveConfigs(_toArray(u));
  }

  function test_updateReserveConfigs_revertsWith_ReserveIsRestricted() public {
    ISpoke.ReserveConfig memory current = _reserveConfig(MAIN_SPOKE, HUB, ASSET);
    vm.prank(OWNER);
    steward.setReserveRestricted(address(MAIN_SPOKE), address(HUB), ASSET, true);
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.collateralRisk = current.collateralRisk;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ReserveIsRestricted.selector);
    steward.updateReserveConfigs(_toArray(u));
  }
}
