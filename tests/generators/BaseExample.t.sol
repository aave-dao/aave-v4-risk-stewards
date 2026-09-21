// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {EngineFlags} from 'aave-v4/config-engine/libraries/EngineFlags.sol';
import {IAaveV4ConfigEngine as IEngine} from 'aave-v4/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IAssetInterestRateStrategy} from 'aave-v4/hub/interfaces/IAssetInterestRateStrategy.sol';
import {ISpoke} from 'aave-v4/spoke/interfaces/ISpoke.sol';
import {IHub} from 'aave-v4/hub/interfaces/IHub.sol';
import {
  ITokenizationSpoke,
  ISpokeConfigurator,
  PositionManagers
} from 'aave-address-book/AaveV4.sol';
import {
  AaveV4Base,
  AaveV4BaseGetters,
  AaveV4BaseHubs,
  AaveV4BaseSpokes,
  AaveV4BaseAssets
} from 'aave-address-book/AaveV4Base.sol';
import {GovernanceV3Base} from 'aave-address-book/GovernanceV3Base.sol';
import {IAccessManagerEnumerable} from 'aave-v4/access/interfaces/IAccessManagerEnumerable.sol';
import {Roles} from 'aave-v4/deployments/utils/libraries/Roles.sol';

import {IERC20Metadata} from 'openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';

import {RiskSteward} from '../../src/RiskSteward.sol';
import {IRiskSteward} from '../../src/interfaces/IRiskSteward.sol';
import {RiskStewardsBase} from '../../scripts/RiskStewardsBase.s.sol';
import {BaseExample} from '../../scripts/examples/BaseExample.sol';

contract BaseTestPayload is RiskStewardsBase {
  IHub internal constant TEST_HUB = AaveV4BaseHubs.EQUITIES_HUB;
  ISpoke internal constant TEST_SPOKE = AaveV4BaseSpokes.MAG7_SPOKE;
  address internal constant TEST_ASSET = AaveV4BaseAssets.AAPLc_UNDERLYING;

  constructor(address steward) RiskStewardsBase(steward) {}

  function name() public pure override returns (string memory) {
    return 'base_example_test';
  }

  function _getHubs() internal pure override returns (IHub[] memory) {
    IHub[] memory hubs = new IHub[](1);
    hubs[0] = TEST_HUB;
    return hubs;
  }

  function _getSpokes() internal pure override returns (ISpoke[] memory) {
    ISpoke[] memory spokes = new ISpoke[](1);
    spokes[0] = TEST_SPOKE;
    return spokes;
  }

  function _getTokenizationSpokes() internal pure override returns (ITokenizationSpoke[] memory) {
    return new ITokenizationSpoke[](0);
  }

  function _getPositionManagers() internal pure override returns (PositionManagers memory) {
    return AaveV4BaseGetters.getPositionManagers();
  }

  function _accessManager() internal pure override returns (address) {
    return address(AaveV4Base.ACCESS_MANAGER);
  }

  function _spokeConfigurator() internal pure override returns (ISpokeConfigurator) {
    return AaveV4Base.SPOKE_CONFIGURATOR;
  }

  function hubAssetIrUpdates() public pure override returns (IEngine.AssetConfigUpdate[] memory) {
    IEngine.AssetConfigUpdate[] memory updates = new IEngine.AssetConfigUpdate[](1);
    updates[0] = IEngine.AssetConfigUpdate({
      hubConfigurator: AaveV4Base.HUB_CONFIGURATOR,
      hub: address(TEST_HUB),
      underlying: TEST_ASSET,
      liquidityFee: EngineFlags.KEEP_CURRENT,
      feeReceiver: EngineFlags.KEEP_CURRENT_ADDRESS,
      irStrategy: EngineFlags.KEEP_CURRENT_ADDRESS,
      irData: IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: EngineFlags.KEEP_CURRENT_UINT16,
        baseDrawnRate: 1_00,
        rateGrowthBeforeOptimal: EngineFlags.KEEP_CURRENT_UINT32,
        rateGrowthAfterOptimal: EngineFlags.KEEP_CURRENT_UINT32
      }),
      reinvestmentController: EngineFlags.KEEP_CURRENT_ADDRESS
    });
    return updates;
  }

  function hubSpokeCapsUpdates() public pure override returns (IEngine.SpokeConfigUpdate[] memory) {
    IEngine.SpokeConfigUpdate[] memory updates = new IEngine.SpokeConfigUpdate[](1);
    updates[0] = IEngine.SpokeConfigUpdate({
      hubConfigurator: AaveV4Base.HUB_CONFIGURATOR,
      hub: address(TEST_HUB),
      underlying: TEST_ASSET,
      spoke: address(TEST_SPOKE),
      addCap: 16_500,
      drawCap: EngineFlags.KEEP_CURRENT,
      riskPremiumThreshold: EngineFlags.KEEP_CURRENT,
      active: EngineFlags.KEEP_CURRENT,
      halted: EngineFlags.KEEP_CURRENT
    });
    return updates;
  }

  function reserveConfigUpdates()
    public
    pure
    override
    returns (IEngine.ReserveConfigUpdate[] memory)
  {
    return new IEngine.ReserveConfigUpdate[](0);
  }

  function dynamicReserveConfigUpdates()
    public
    view
    override
    returns (IEngine.DynamicReserveConfigUpdate[] memory)
  {
    IEngine.DynamicReserveConfigUpdate[] memory updates = new IEngine.DynamicReserveConfigUpdate[](
      1
    );
    updates[0] = IEngine.DynamicReserveConfigUpdate({
      spokeConfigurator: AaveV4Base.SPOKE_CONFIGURATOR,
      spoke: address(TEST_SPOKE),
      hub: address(TEST_HUB),
      underlying: TEST_ASSET,
      dynamicConfigKey: _latestDynamicConfigKey(),
      collateralFactor: 70_00,
      maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
      liquidationFee: EngineFlags.KEEP_CURRENT
    });
    return updates;
  }

  function dynamicReserveConfigAdditions()
    public
    view
    override
    returns (IEngine.DynamicReserveConfigAddition[] memory)
  {
    ISpoke.DynamicReserveConfig memory latest = TEST_SPOKE.getDynamicReserveConfig(
      _reserveId(),
      _latestDynamicConfigKey()
    );

    IEngine.DynamicReserveConfigAddition[]
      memory additions = new IEngine.DynamicReserveConfigAddition[](1);
    additions[0] = IEngine.DynamicReserveConfigAddition({
      spokeConfigurator: AaveV4Base.SPOKE_CONFIGURATOR,
      spoke: address(TEST_SPOKE),
      hub: address(TEST_HUB),
      underlying: TEST_ASSET,
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: latest.collateralFactor,
        maxLiquidationBonus: latest.maxLiquidationBonus,
        liquidationFee: latest.liquidationFee
      })
    });
    return additions;
  }

  function spokeLiquidationConfigUpdates()
    public
    pure
    override
    returns (IEngine.LiquidationConfigUpdate[] memory)
  {
    IEngine.LiquidationConfigUpdate[] memory updates = new IEngine.LiquidationConfigUpdate[](1);
    updates[0] = IEngine.LiquidationConfigUpdate({
      spokeConfigurator: AaveV4Base.SPOKE_CONFIGURATOR,
      spoke: address(TEST_SPOKE),
      targetHealthFactor: 1.2e18,
      healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
      liquidationBonusFactor: EngineFlags.KEEP_CURRENT
    });
    return updates;
  }

  function _reserveId() private view returns (uint256) {
    return TEST_SPOKE.getReserveId(address(TEST_HUB), TEST_HUB.getAssetId(TEST_ASSET));
  }

  function _latestDynamicConfigKey() private view returns (uint32) {
    return TEST_SPOKE.getReserve(_reserveId()).dynamicConfigKey;
  }
}

contract BaseExampleTest is Test {
  using SafeCast for uint256;

  address internal immutable RISK_COUNCIL = makeAddr('RISK_COUNCIL');
  address internal constant OWNER = GovernanceV3Base.EXECUTOR_LVL_1;

  IHub internal constant HUB = AaveV4BaseHubs.EQUITIES_HUB;
  ISpoke internal constant SPOKE = AaveV4BaseSpokes.MAG7_SPOKE;
  address internal constant ASSET = AaveV4BaseAssets.AAPLc_UNDERLYING;

  RiskSteward internal steward;
  BaseTestPayload internal payload;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('base'), 51604825);

    steward = new RiskSteward(RISK_COUNCIL, OWNER);

    vm.prank(OWNER);
    steward.setConfig(_config());

    IAccessManagerEnumerable accessManager = AaveV4Base.ACCESS_MANAGER;
    address accessAdmin = accessManager.getRoleMember(Roles.ACCESS_MANAGER_ADMIN_ROLE, 0);
    vm.startPrank(accessAdmin);
    accessManager.grantRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, address(steward), 0);
    accessManager.grantRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, address(steward), 0);
    vm.stopPrank();

    payload = new BaseTestPayload(address(steward));
  }

  /// @dev Writes `reports/base_example_test_{before,after}.json` and the diff. Every asset symbol
  /// in there comes from a `symbol()` call on the underlying, and the seven equities are B20
  /// tokens the stock EVM cannot execute, so stock forge would write `<unknown>` for them. Skip
  /// rather than commit a degraded report.
  function test_run_executesAllCategoriesAndBumpsDebounces() public {
    _requireB20Semantics();
    payload.run({broadcastToSafe: false, generateDiffReport: true, skipTimelock: true});

    uint40 expectedTimestamp = vm.getBlockTimestamp().toUint40();

    IRiskSteward.HubAssetDebounce memory hubAssetDebounce = steward.getHubAssetDebounce(
      address(HUB),
      ASSET
    );
    assertEq(hubAssetDebounce.baseDrawnRate, expectedTimestamp, 'baseDrawnRate debounce bumped');
    assertEq(hubAssetDebounce.optimalUsageRatio, 0, 'optimalUsageRatio left at sentinel');

    IRiskSteward.HubSpokeAssetDebounce memory capsDebounce = steward.getHubSpokeAssetDebounce(
      address(HUB),
      address(SPOKE),
      ASSET
    );
    assertEq(capsDebounce.addCap, expectedTimestamp, 'addCap debounce bumped');
    assertEq(capsDebounce.drawCap, 0, 'drawCap left at sentinel');

    IRiskSteward.SpokeDynamicDebounce memory dynamicDebounce = steward.getSpokeDynamicDebounce(
      address(SPOKE),
      address(HUB),
      ASSET
    );
    assertEq(
      dynamicDebounce.collateralFactor,
      expectedTimestamp,
      'collateralFactor debounce bumped'
    );

    IRiskSteward.SpokeLiquidationDebounce memory liquidationDebounce = steward
      .getSpokeLiquidationDebounce(address(SPOKE));
    assertEq(
      liquidationDebounce.targetHealthFactor,
      expectedTimestamp,
      'targetHealthFactor debounce bumped'
    );
    assertEq(
      liquidationDebounce.healthFactorForMaxBonus,
      0,
      'healthFactorForMaxBonus left at sentinel'
    );
  }

  function test_updateHubAssetIRs_revertsWith_InvalidCaller() public {
    BaseExample example = new BaseExample();
    IEngine.AssetConfigUpdate[] memory updates = example.hubAssetIrUpdates();
    vm.expectRevert(IRiskSteward.InvalidCaller.selector);
    steward.updateHubAssetIRs(updates);
  }

  function test_baseExampleProducesAllSixCategories() public {
    BaseExample example = new BaseExample();
    assertEq(example.hubAssetIrUpdates().length, 2, 'hubAssetIrUpdates');
    assertEq(example.hubSpokeCapsUpdates().length, 2, 'hubSpokeCapsUpdates');
    assertEq(example.reserveConfigUpdates().length, 1, 'reserveConfigUpdates');
    assertEq(example.dynamicReserveConfigUpdates().length, 1, 'dynamicReserveConfigUpdates');
    assertEq(example.dynamicReserveConfigAdditions().length, 1, 'dynamicReserveConfigAdditions');
    assertEq(example.spokeLiquidationConfigUpdates().length, 1, 'spokeLiquidationConfigUpdates');
  }

  /// @dev Under stock forge any call into a B20 token hits the invalid opcode 0xef and reverts;
  /// under base-anvil's forge the node-native token answers. Probe with a view call and skip
  /// rather than pass. See the `test-base` CI job.
  function _requireB20Semantics() internal {
    (bool ok, ) = ASSET.staticcall(abi.encodeCall(IERC20Metadata.decimals, ()));
    vm.skip(!ok, 'requires base-anvil forge for the B20 equity tokens');
  }

  function _config() internal pure returns (IRiskSteward.Config memory) {
    IRiskSteward.RiskParamConfig memory wideAbs = IRiskSteward.RiskParamConfig({
      minDelay: 0,
      maxPercentChange: 100_00,
      isChangeRelative: false
    });
    IRiskSteward.RiskParamConfig memory wideRel = IRiskSteward.RiskParamConfig({
      minDelay: 0,
      maxPercentChange: 100_00,
      isChangeRelative: true
    });
    return
      IRiskSteward.Config({
        hub: IRiskSteward.HubConfig({
          configurator: AaveV4Base.HUB_CONFIGURATOR,
          rate: IRiskSteward.HubRateConfig({
            optimalUsageRatio: wideAbs,
            baseDrawnRate: wideAbs,
            rateGrowthBeforeOptimal: wideAbs,
            rateGrowthAfterOptimal: wideAbs
          }),
          cap: IRiskSteward.HubCapConfig({addCap: wideRel, drawCap: wideRel})
        }),
        spoke: IRiskSteward.SpokeConfig({
          configurator: AaveV4Base.SPOKE_CONFIGURATOR,
          collateralRisk: wideAbs,
          dynamicUpdate: IRiskSteward.SpokeDynamicConfig({
            collateralFactor: wideAbs,
            maxLiquidationBonus: wideAbs
          }),
          dynamicAdd: IRiskSteward.SpokeDynamicConfig({
            collateralFactor: wideAbs,
            maxLiquidationBonus: wideAbs
          }),
          liquidation: IRiskSteward.SpokeLiquidationConfig({
            targetHealthFactor: wideRel,
            healthFactorForMaxBonus: wideRel,
            liquidationBonusFactor: wideAbs
          })
        }),
        oracle: IRiskSteward.OracleConfig({
          priceCapLst: wideRel,
          priceCapStable: wideRel,
          discountRatePendle: wideAbs
        })
      });
  }
}
