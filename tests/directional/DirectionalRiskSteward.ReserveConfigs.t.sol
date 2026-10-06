// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './DirectionalRiskSteward.Base.t.sol';

abstract contract DirectionalRiskStewardReserveConfigsTest is DirectionalRiskStewardTestBase {
  using SafeCast for uint256;

  function test_updateReserveConfigs() public {
    _setCollateralRisk(10_00);

    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.collateralRisk = 11_00; // +10%, within 20% bound

    _assertUpdateReserveConfigs(u);
  }

  function test_updateReserveConfigs_decrease() public {
    _setCollateralRisk(10_00);

    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.collateralRisk = 9_00;

    _assertUpdateReserveConfigs(u);
  }

  function test_fuzz_updateReserveConfigs(int256 delta) public {
    _setCollateralRisk(10_00);
    ISpoke.ReserveConfig memory current = _reserveConfig(MAIN_SPOKE, HUB, ASSET);

    IDirectionalRiskSteward.RiskParamConfig memory crBounds = steward
      .getConfig()
      .spoke
      .collateralRisk;
    delta = _boundDelta(delta, crBounds.maxPercentChange);

    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.collateralRisk = _applyDelta({
      current: current.collateralRisk,
      delta: delta,
      floor: 0 // collateralRisk = 0 is allowed by the steward
    });

    _assertUpdateReserveConfigs(u);
  }

  function test_updateReserveConfigs_fromZero() public {
    assertEq(_reserveConfig(MAIN_SPOKE, HUB, ASSET).collateralRisk, 0);

    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.collateralRisk = 20_00; // exactly the configured maxPercentChange

    _assertUpdateReserveConfigs(u);
  }

  function test_updateReserveConfigs_outOfRange_revertsWith_UpdateNotInRange() public {
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.collateralRisk = 20_01;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.UpdateNotInRange.selector);
    steward.updateReserveConfigs(_toArray(u));
  }

  function test_updateReserveConfigs_priceSourceChange_revertsWith_ParamChangeNotAllowed() public {
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.priceSource = address(0xdead);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateReserveConfigs(_toArray(u));
  }

  function test_updateReserveConfigs_pausedChange_revertsWith_ParamChangeNotAllowed() public {
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.paused = 1;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateReserveConfigs(_toArray(u));
  }

  function test_updateReserveConfigs_frozenChange_revertsWith_ParamChangeNotAllowed() public {
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.frozen = 1;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateReserveConfigs(_toArray(u));
  }

  function test_updateReserveConfigs_borrowableChange_revertsWith_ParamChangeNotAllowed() public {
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.borrowable = 0;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateReserveConfigs(_toArray(u));
  }

  function test_updateReserveConfigs_receiveSharesEnabledChange_revertsWith_ParamChangeNotAllowed()
    public
  {
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.receiveSharesEnabled = 0;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateReserveConfigs(_toArray(u));
  }

  function test_updateReserveConfigs_toZero() public {
    _setCollateralRisk(100);

    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.collateralRisk = 0;

    _assertUpdateReserveConfigs(u);
  }

  function test_updateReserveConfigs_revertsWith_ConfiguratorMismatch() public {
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.spokeConfigurator = ISpokeConfigurator(address(0xdead));

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.ConfiguratorMismatch.selector);
    steward.updateReserveConfigs(_toArray(u));
  }

  function test_updateReserveConfigs_whenHubRestricted_revertsWith_RestrictedAddress() public {
    ISpoke.ReserveConfig memory current = _reserveConfig(MAIN_SPOKE, HUB, ASSET);
    vm.prank(OWNER);
    steward.setAddressRestricted(address(HUB), true);
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.collateralRisk = current.collateralRisk;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(
      abi.encodeWithSelector(IDirectionalRiskSteward.RestrictedAddress.selector, address(HUB))
    );
    steward.updateReserveConfigs(_toArray(u));
  }

  function test_updateReserveConfigs_whenSpokeRestricted_revertsWith_RestrictedAddress() public {
    ISpoke.ReserveConfig memory current = _reserveConfig(MAIN_SPOKE, HUB, ASSET);
    vm.prank(OWNER);
    steward.setAddressRestricted(address(MAIN_SPOKE), true);
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.collateralRisk = current.collateralRisk;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(
      abi.encodeWithSelector(
        IDirectionalRiskSteward.RestrictedAddress.selector,
        address(MAIN_SPOKE)
      )
    );
    steward.updateReserveConfigs(_toArray(u));
  }

  function test_updateReserveConfigs_whenAssetRestricted_revertsWith_RestrictedAddress() public {
    ISpoke.ReserveConfig memory current = _reserveConfig(MAIN_SPOKE, HUB, ASSET);
    vm.prank(OWNER);
    steward.setAddressRestricted(ASSET, true);
    IEngine.ReserveConfigUpdate memory u = _baseReserveUpdate();
    u.collateralRisk = current.collateralRisk;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(
      abi.encodeWithSelector(IDirectionalRiskSteward.RestrictedAddress.selector, ASSET)
    );
    steward.updateReserveConfigs(_toArray(u));
  }

  function _setCollateralRisk(uint24 collateralRisk) internal {
    uint256 reserveId = MAIN_SPOKE.getReserveId(address(HUB), HUB.getAssetId(ASSET));
    vm.prank(address(steward));
    SPOKE_CONFIGURATOR.updateCollateralRisk(address(MAIN_SPOKE), reserveId, collateralRisk);
  }

  function _assertUpdateReserveConfigs(IEngine.ReserveConfigUpdate memory u) internal {
    uint256 reserveId = MAIN_SPOKE.getReserveId(address(HUB), HUB.getAssetId(ASSET));
    ISpoke.ReserveConfig memory current = _reserveConfig(MAIN_SPOKE, HUB, ASSET);
    bool allowed = _isDirectionAllowed(current.collateralRisk, u.collateralRisk);

    ISpoke.ReserveConfig memory expected = current;
    expected.collateralRisk = u.collateralRisk.toUint24();
    if (allowed) {
      vm.expectEmit(address(MAIN_SPOKE));
      emit ISpoke.UpdateReserveConfig(reserveId, expected);
    } else {
      _expectDirectionRevert();
    }

    vm.prank(RISK_COUNCIL);
    steward.updateReserveConfigs(_toArray(u));
    if (!allowed) return;

    assertEq(_reserveConfig(MAIN_SPOKE, HUB, ASSET), expected);

    IDirectionalRiskSteward.SpokeReserveDebounce memory debounce = steward.getSpokeReserveDebounce(
      address(MAIN_SPOKE),
      address(HUB),
      ASSET
    );
    assertEq(debounce.collateralRisk, vm.getBlockTimestamp().toUint40());
  }
}

contract DirectionalRiskStewardReserveConfigsBothTest is
  DirectionalRiskStewardReserveConfigsTest,
  DirectionBoth
{}

contract DirectionalRiskStewardReserveConfigsReduceTest is
  DirectionalRiskStewardReserveConfigsTest,
  DirectionReduce
{}

contract DirectionalRiskStewardReserveConfigsIncreaseTest is
  DirectionalRiskStewardReserveConfigsTest,
  DirectionIncrease
{}
