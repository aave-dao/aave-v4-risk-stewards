// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './DirectionalRiskSteward.Base.t.sol';

contract DirectionalRiskStewardDirectionTest is DirectionBoth {
  function test_both_allowsIncreaseAndDecrease() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = (uint256(current.addCap) * 110) / 100;
    u.drawCap = (uint256(current.drawCap) * 90) / 100;

    vm.prank(RISK_COUNCIL);
    steward.updateHubSpokeCaps(_toArray(u));

    assertEq(_spokeConfig(HUB, MAIN_SPOKE, ASSET).addCap, u.addCap);
    assertEq(_spokeConfig(HUB, MAIN_SPOKE, ASSET).drawCap, u.drawCap);
  }

  function test_reduce_allowsDecrease() public {
    _setAddCapDirection(IDirectionalRiskSteward.Direction.REDUCE);
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = (uint256(current.addCap) * 90) / 100;

    vm.prank(RISK_COUNCIL);
    steward.updateHubSpokeCaps(_toArray(u));

    assertEq(_spokeConfig(HUB, MAIN_SPOKE, ASSET).addCap, u.addCap);
  }

  function test_reduce_allowsUnchanged() public {
    _setAddCapDirection(IDirectionalRiskSteward.Direction.REDUCE);
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = current.addCap;

    vm.prank(RISK_COUNCIL);
    steward.updateHubSpokeCaps(_toArray(u));

    assertEq(_spokeConfig(HUB, MAIN_SPOKE, ASSET).addCap, current.addCap);
  }

  function test_reverts_reduce_onIncrease() public {
    _setAddCapDirection(IDirectionalRiskSteward.Direction.REDUCE);
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = uint256(current.addCap) + 1;

    vm.expectRevert(IDirectionalRiskSteward.UpdateDirectionNotAllowed.selector);
    vm.prank(RISK_COUNCIL);
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_increase_allowsIncrease() public {
    _setAddCapDirection(IDirectionalRiskSteward.Direction.INCREASE);
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = (uint256(current.addCap) * 110) / 100;

    vm.prank(RISK_COUNCIL);
    steward.updateHubSpokeCaps(_toArray(u));

    assertEq(_spokeConfig(HUB, MAIN_SPOKE, ASSET).addCap, u.addCap);
  }

  function test_reverts_increase_onDecrease() public {
    _setAddCapDirection(IDirectionalRiskSteward.Direction.INCREASE);
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = uint256(current.addCap) - 1;

    vm.expectRevert(IDirectionalRiskSteward.UpdateDirectionNotAllowed.selector);
    vm.prank(RISK_COUNCIL);
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_direction_isPerParam() public {
    _setAddCapDirection(IDirectionalRiskSteward.Direction.REDUCE);
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.drawCap = (uint256(current.drawCap) * 110) / 100;

    vm.prank(RISK_COUNCIL);
    steward.updateHubSpokeCaps(_toArray(u));

    assertEq(_spokeConfig(HUB, MAIN_SPOKE, ASSET).drawCap, u.drawCap);
  }

  function test_reverts_reduce_onAbsoluteParamIncrease() public {
    IDirectionalRiskSteward.Config memory config = steward.getConfig();
    config.hub.rate.optimalUsageRatio.direction = IDirectionalRiskSteward.Direction.REDUCE;
    vm.prank(OWNER);
    steward.setConfig(config);

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = _interestRateData(HUB, ASSET).optimalUsageRatio + 1;

    vm.expectRevert(IDirectionalRiskSteward.UpdateDirectionNotAllowed.selector);
    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(_toArray(u));
  }

  function _setAddCapDirection(IDirectionalRiskSteward.Direction direction) internal {
    IDirectionalRiskSteward.Config memory config = steward.getConfig();
    config.hub.cap.addCap.direction = direction;
    vm.prank(OWNER);
    steward.setConfig(config);
  }
}
