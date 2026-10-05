// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './DirectionalRiskSteward.Base.t.sol';

abstract contract DirectionalRiskStewardHubSpokeCapsTest is DirectionalRiskStewardTestBase {
  using SafeCast for uint256;

  uint256 internal constant ADD_CAP = 0;
  uint256 internal constant DRAW_CAP = 1;
  function test_updateHubSpokeCaps() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = (uint256(current.addCap) * 110) / 100; // +10% relative, within +100% bound
    u.drawCap = (uint256(current.drawCap) * 110) / 100;

    _assertUpdateHubSpokeCaps(u);
  }

  function test_updateHubSpokeCaps_decrease() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = (uint256(current.addCap) * 90) / 100;
    u.drawCap = (uint256(current.drawCap) * 90) / 100;

    _assertUpdateHubSpokeCaps(u);
  }

  function test_fuzz_updateHubSpokeCaps(int256 addCapDeltaBps, int256 drawCapDeltaBps) public {
    IDirectionalRiskSteward.HubCapConfig memory capBounds = steward.getConfig().hub.cap;
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    addCapDeltaBps = _boundDelta(addCapDeltaBps, capBounds.addCap.maxPercentChange);
    drawCapDeltaBps = _boundDelta(drawCapDeltaBps, capBounds.drawCap.maxPercentChange);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = _applyRelativeDelta({current: current.addCap, deltaBps: addCapDeltaBps, floor: 0});
    u.drawCap = _applyRelativeDelta({
      current: current.drawCap,
      deltaBps: drawCapDeltaBps,
      floor: 0
    });

    _assertUpdateHubSpokeCaps(u);
  }

  function test_updateHubSpokeCaps_revertsWith_UpdateNotInRange() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = (uint256(current.addCap) * 210) / 100; // +110%

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.UpdateNotInRange.selector);
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_updateHubSpokeCaps_revertsWith_DebounceNotRespected() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = _allowedValue((uint256(current.addCap) * 110) / 100, (current.addCap * 90) / 100);
    vm.prank(RISK_COUNCIL);
    steward.updateHubSpokeCaps(_toArray(u));

    IEngine.SpokeConfigUpdate memory u2 = _baseSpokeCapsUpdate();
    u2.addCap = (uint256(current.addCap) * 105) / 100;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.DebounceNotRespected.selector);
    steward.updateHubSpokeCaps(_toArray(u2));
  }

  function test_updateHubSpokeCaps_toZero() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    assertGt(current.addCap, 0);
    assertGt(current.drawCap, 0);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = 0;
    u.drawCap = 0;

    _assertUpdateHubSpokeCaps(u);
  }

  function test_updateHubSpokeCaps_cannotRaiseFromZero_revertsWith_UpdateNotInRange() public {
    // a cap can only reach zero through a decrease
    vm.skip(_direction() == IDirectionalRiskSteward.Direction.INCREASE);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = 0;
    vm.prank(RISK_COUNCIL);
    steward.updateHubSpokeCaps(_toArray(u));

    skip(3 days + 1); // clear the debounce

    IEngine.SpokeConfigUpdate memory u2 = _baseSpokeCapsUpdate();
    u2.addCap = 1;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.UpdateNotInRange.selector);
    steward.updateHubSpokeCaps(_toArray(u2));
  }

  function test_updateHubSpokeCaps_riskPremiumThresholdChange_revertsWith_ParamChangeNotAllowed()
    public
  {
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.riskPremiumThreshold = 1_00;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_updateHubSpokeCaps_activeChange_revertsWith_ParamChangeNotAllowed() public {
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.active = 1;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_updateHubSpokeCaps_haltedChange_revertsWith_ParamChangeNotAllowed() public {
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.halted = 1;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_updateHubSpokeCaps_revertsWith_ConfiguratorMismatch() public {
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.hubConfigurator = IHubConfigurator(address(0xdead));

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.ConfiguratorMismatch.selector);
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_updateHubSpokeCaps_whenHubRestricted_revertsWith_RestrictedAddress() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    vm.prank(OWNER);
    steward.setAddressRestricted(address(HUB), true);
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = current.addCap;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(
      abi.encodeWithSelector(IDirectionalRiskSteward.RestrictedAddress.selector, address(HUB))
    );
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_updateHubSpokeCaps_whenSpokeRestricted_revertsWith_RestrictedAddress() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    vm.prank(OWNER);
    steward.setAddressRestricted(address(MAIN_SPOKE), true);
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = current.addCap;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(
      abi.encodeWithSelector(
        IDirectionalRiskSteward.RestrictedAddress.selector,
        address(MAIN_SPOKE)
      )
    );
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_updateHubSpokeCaps_whenAssetRestricted_revertsWith_RestrictedAddress() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    vm.prank(OWNER);
    steward.setAddressRestricted(ASSET, true);
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = current.addCap;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(
      abi.encodeWithSelector(IDirectionalRiskSteward.RestrictedAddress.selector, ASSET)
    );
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_updateHubSpokeCaps_revertsWith_NoZeroUpdates() public {
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.NoZeroUpdates.selector);
    steward.updateHubSpokeCaps(new IEngine.SpokeConfigUpdate[](0));
  }

  function test_updateHubSpokeCaps_onLidoSpoke() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, LIDO_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.spoke = address(LIDO_SPOKE);
    u.drawCap = _allowedValue((uint256(current.drawCap) * 110) / 100, (current.drawCap * 90) / 100);

    vm.prank(RISK_COUNCIL);
    steward.updateHubSpokeCaps(_toArray(u));

    assertEq(
      steward.getHubSpokeAssetDebounce(address(HUB), address(LIDO_SPOKE), ASSET).drawCap,
      vm.getBlockTimestamp().toUint40()
    );
  }

  function test_updateHubSpokeCaps_addCapUp_othersAllowed() public {
    _assertUpdateHubSpokeCaps(_capsUpdateMoving(ADD_CAP, true));
  }

  function test_updateHubSpokeCaps_addCapDown_othersAllowed() public {
    _assertUpdateHubSpokeCaps(_capsUpdateMoving(ADD_CAP, false));
  }

  function test_updateHubSpokeCaps_drawCapUp_othersAllowed() public {
    _assertUpdateHubSpokeCaps(_capsUpdateMoving(DRAW_CAP, true));
  }

  function test_updateHubSpokeCaps_drawCapDown_othersAllowed() public {
    _assertUpdateHubSpokeCaps(_capsUpdateMoving(DRAW_CAP, false));
  }

  /// @dev Moves `param` up or down by 10% and the other cap in the allowed direction.
  function _capsUpdateMoving(
    uint256 param,
    bool up
  ) internal view returns (IEngine.SpokeConfigUpdate memory) {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = _move(current.addCap, current.addCap / 10, param == ADD_CAP, up);
    u.drawCap = _move(current.drawCap, current.drawCap / 10, param == DRAW_CAP, up);
    return u;
  }

  function _assertUpdateHubSpokeCaps(IEngine.SpokeConfigUpdate memory u) internal {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    bool allowed =
      _isDirectionAllowed(current.addCap, u.addCap) &&
        _isDirectionAllowed(current.drawCap, u.drawCap);

    uint256 assetId = HUB.getAssetId(ASSET);
    IHub.SpokeConfig memory expected = IHub.SpokeConfig({
      addCap: u.addCap.toUint40(),
      drawCap: u.drawCap.toUint40(),
      riskPremiumThreshold: current.riskPremiumThreshold,
      active: current.active,
      halted: current.halted
    });
    if (allowed) {
      vm.expectEmit(address(HUB));
      emit IHub.UpdateSpokeConfig(assetId, address(MAIN_SPOKE), expected);
    } else {
      _expectDirectionRevert();
    }

    vm.prank(RISK_COUNCIL);
    steward.updateHubSpokeCaps(_toArray(u));
    if (!allowed) return;

    assertEq(_spokeConfig(HUB, MAIN_SPOKE, ASSET), expected);

    IDirectionalRiskSteward.HubSpokeAssetDebounce memory debounce = steward
      .getHubSpokeAssetDebounce(address(HUB), address(MAIN_SPOKE), ASSET);
    assertEq(debounce.addCap, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.drawCap, vm.getBlockTimestamp().toUint40());
  }
}

contract DirectionalRiskStewardHubSpokeCapsBothTest is
  DirectionalRiskStewardHubSpokeCapsTest,
  DirectionBoth
{}

contract DirectionalRiskStewardHubSpokeCapsReduceTest is
  DirectionalRiskStewardHubSpokeCapsTest,
  DirectionReduce
{}

contract DirectionalRiskStewardHubSpokeCapsIncreaseTest is
  DirectionalRiskStewardHubSpokeCapsTest,
  DirectionIncrease
{}
