// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Ownable2Step} from 'aave-v4/dependencies/openzeppelin/Ownable2Step.sol';

import {MiscEthereum} from 'aave-address-book/MiscEthereum.sol';

import {RiskSteward} from 'src/RiskSteward.sol';
import {ReduceRiskStewardWrapper} from 'src/ReduceRiskStewardWrapper.sol';
import {IRiskSteward} from 'src/interfaces/IRiskSteward.sol';
import {DeployEthereum} from 'scripts/deploy/DeployReduceRiskStewardWrapper.s.sol';

/// @dev Runs the Sentora deploy script against the live Sentora configurators.
contract DeployReduceRiskStewardWrapperSentoraTest is Test {
  address internal deployer;
  RiskSteward internal steward;
  ReduceRiskStewardWrapper internal wrapper;

  function setUp() public {
    // first block after the Sentora market deploy
    vm.createSelectFork(vm.rpcUrl('mainnet'), 26190814);
    DeployEthereum script = new DeployEthereum();
    (, deployer, ) = vm.readCallers();
    uint256 nonce = vm.getNonce(deployer);
    script.run();
    steward = RiskSteward(vm.computeCreateAddress(deployer, nonce));
    wrapper = ReduceRiskStewardWrapper(vm.computeCreateAddress(deployer, nonce + 1));
  }

  function test_wiring() public view {
    assertEq(steward.RISK_COUNCIL(), address(wrapper));
    assertEq(address(wrapper.RISK_STEWARD()), address(steward));
    assertEq(wrapper.RISK_COUNCIL(), 0x37409c868BA42B91ff7E7b64D5BC020897444fAf);
    assertEq(Ownable2Step(address(steward)).owner(), deployer);
    assertEq(Ownable2Step(address(steward)).pendingOwner(), MiscEthereum.V4_SECURITY_COUNCIL);
  }

  function test_configurators() public view {
    IRiskSteward.Config memory config = steward.getConfig();
    assertEq(address(config.hub.configurator), 0xa0eD3ECC19ab04BD0e6417023824cC4930d77b70);
    assertEq(address(config.spoke.configurator), 0x93bd198d4F64798157233142769159329b3cBbce);
  }

  function test_bounds() public view {
    IRiskSteward.Config memory config = steward.getConfig();

    _assertParam(config.hub.cap.addCap, 300_00, true);
    _assertParam(config.hub.cap.drawCap, 300_00, true);
    _assertParam(config.spoke.dynamicAdd.collateralFactor, 100_00, false);
    _assertParam(config.spoke.dynamicAdd.maxLiquidationBonus, 50_00, false);

    _assertParam(config.hub.rate.optimalUsageRatio, 0, false);
    _assertParam(config.hub.rate.baseDrawnRate, 0, false);
    _assertParam(config.hub.rate.rateGrowthBeforeOptimal, 0, false);
    _assertParam(config.hub.rate.rateGrowthAfterOptimal, 0, false);
    _assertParam(config.spoke.collateralRisk, 0, false);
    _assertParam(config.spoke.dynamicUpdate.collateralFactor, 0, false);
    _assertParam(config.spoke.dynamicUpdate.maxLiquidationBonus, 0, false);
    _assertParam(config.spoke.liquidation.targetHealthFactor, 0, true);
    _assertParam(config.spoke.liquidation.healthFactorForMaxBonus, 0, true);
    _assertParam(config.spoke.liquidation.liquidationBonusFactor, 0, false);
    _assertParam(config.oracle.priceCapLst, 0, true);
    _assertParam(config.oracle.priceCapStable, 0, true);
    _assertParam(config.oracle.discountRatePendle, 0, false);
  }

  function _assertParam(
    IRiskSteward.RiskParamConfig memory param,
    uint256 maxPercentChange,
    bool isChangeRelative
  ) internal pure {
    assertEq(param.minDelay, 0, 'minDelay');
    assertEq(param.maxPercentChange, maxPercentChange, 'maxPercentChange');
    assertEq(param.isChangeRelative, isChangeRelative, 'isChangeRelative');
  }
}
