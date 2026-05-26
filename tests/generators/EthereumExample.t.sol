// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {EngineFlags} from 'aave-v4/config-engine/libraries/EngineFlags.sol';
import {IAaveV4ConfigEngine as IEngine} from 'aave-v4/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IAssetInterestRateStrategy} from 'aave-v4/hub/interfaces/IAssetInterestRateStrategy.sol';
import {ISpoke} from 'aave-v4/spoke/interfaces/ISpoke.sol';
import {IHub} from 'aave-v4/hub/interfaces/IHub.sol';
import {ITokenizationSpoke} from 'aave-address-book/AaveV4.sol';
import {
  AaveV4Ethereum,
  AaveV4EthereumHubs,
  AaveV4EthereumSpokes,
  AaveV4EthereumAssets
} from 'aave-address-book/AaveV4Ethereum.sol';
import {IAccessManager} from 'aave-v4/dependencies/openzeppelin/IAccessManager.sol';

import {SafeCast} from 'openzeppelin-contracts/contracts/utils/math/SafeCast.sol';

import {RiskSteward} from '../../src/RiskSteward.sol';
import {IRiskSteward} from '../../src/interfaces/IRiskSteward.sol';
import {RiskStewardsBase} from '../../scripts/RiskStewardsBase.s.sol';
import {EthereumExample} from '../../scripts/examples/EthereumExample.sol';

/// @notice Fork-realistic payload used by the smoke test. Each override emits a tiny in-bounds
/// delta against the current state of WETH on MAIN_SPOKE so all six steward entrypoints fire.
/// The shape mirrors `EthereumExample` 1:1 — what differs is only the magnitudes of the values.
/// `EthereumExample` itself remains the author-facing demo with kitchen-sink values; tests assert
/// the run() pipeline, not the example's specific numbers.
contract TestPayload is RiskStewardsBase {
  IHub internal constant TEST_HUB = AaveV4EthereumHubs.CORE_HUB;
  ISpoke internal constant TEST_SPOKE = AaveV4EthereumSpokes.MAIN_SPOKE;
  address internal constant TEST_ASSET = AaveV4EthereumAssets.WETH_UNDERLYING;

  constructor(
    address steward,
    ISpoke[] memory spokes,
    IHub[] memory hubs,
    ITokenizationSpoke[] memory tokenizationSpokes
  ) RiskStewardsBase(steward, spokes, hubs, tokenizationSpokes) {}

  function name() public pure override returns (string memory) {
    return 'ethereum_example_test';
  }

  function hubAssetIrUpdates()
    public
    pure
    override
    returns (IEngine.AssetConfigUpdate[] memory updates)
  {
    updates = new IEngine.AssetConfigUpdate[](1);
    updates[0] = IEngine.AssetConfigUpdate({
      hubConfigurator: AaveV4Ethereum.HUB_CONFIGURATOR,
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
  }

  function hubSpokeCapsUpdates()
    public
    pure
    override
    returns (IEngine.SpokeConfigUpdate[] memory updates)
  {
    updates = new IEngine.SpokeConfigUpdate[](1);
    updates[0] = IEngine.SpokeConfigUpdate({
      hubConfigurator: AaveV4Ethereum.HUB_CONFIGURATOR,
      hub: address(TEST_HUB),
      underlying: TEST_ASSET,
      spoke: address(TEST_SPOKE),
      addCap: 20_000,
      drawCap: 1_700,
      riskPremiumThreshold: EngineFlags.KEEP_CURRENT,
      active: EngineFlags.KEEP_CURRENT,
      halted: EngineFlags.KEEP_CURRENT
    });
  }

  /// @dev WETH `collateralRisk` is currently 0 on MAIN_SPOKE; relative bounds reject any change
  /// from 0, so this category stays empty in the smoke test.
  function reserveConfigUpdates()
    public
    pure
    override
    returns (IEngine.ReserveConfigUpdate[] memory updates)
  {
    updates = new IEngine.ReserveConfigUpdate[](0);
  }

  function dynamicReserveConfigUpdates()
    public
    pure
    override
    returns (IEngine.DynamicReserveConfigUpdate[] memory updates)
  {
    updates = new IEngine.DynamicReserveConfigUpdate[](1);
    updates[0] = IEngine.DynamicReserveConfigUpdate({
      spokeConfigurator: AaveV4Ethereum.SPOKE_CONFIGURATOR,
      spoke: address(TEST_SPOKE),
      hub: address(TEST_HUB),
      underlying: TEST_ASSET,
      dynamicConfigKey: 0,
      collateralFactor: 80_00,
      maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
      liquidationFee: EngineFlags.KEEP_CURRENT
    });
  }

  function dynamicReserveConfigAdditions()
    public
    view
    override
    returns (IEngine.DynamicReserveConfigAddition[] memory additions)
  {
    // Read the latest existing dynamic config so the addition can reuse its `liquidationFee`
    // (the steward refuses to change `liquidationFee` between keys).
    uint256 assetId = TEST_HUB.getAssetId(TEST_ASSET);
    uint256 reserveId = TEST_SPOKE.getReserveId(address(TEST_HUB), assetId);
    uint32 latestKey = TEST_SPOKE.getReserve(reserveId).dynamicConfigKey;
    ISpoke.DynamicReserveConfig memory latest = TEST_SPOKE.getDynamicReserveConfig(
      reserveId,
      latestKey
    );

    additions = new IEngine.DynamicReserveConfigAddition[](1);
    additions[0] = IEngine.DynamicReserveConfigAddition({
      spokeConfigurator: AaveV4Ethereum.SPOKE_CONFIGURATOR,
      spoke: address(TEST_SPOKE),
      hub: address(TEST_HUB),
      underlying: TEST_ASSET,
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: latest.collateralFactor,
        maxLiquidationBonus: latest.maxLiquidationBonus,
        liquidationFee: latest.liquidationFee
      })
    });
  }

  function spokeLiquidationConfigUpdates()
    public
    pure
    override
    returns (IEngine.LiquidationConfigUpdate[] memory updates)
  {
    updates = new IEngine.LiquidationConfigUpdate[](1);
    updates[0] = IEngine.LiquidationConfigUpdate({
      spokeConfigurator: AaveV4Ethereum.SPOKE_CONFIGURATOR,
      spoke: address(TEST_SPOKE),
      targetHealthFactor: 1.05e18,
      healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
      liquidationBonusFactor: EngineFlags.KEEP_CURRENT
    });
  }
}

contract EthereumExampleTest is Test {
  using SafeCast for uint256;

  address internal constant RISK_COUNCIL = address(0xc0c0c000);
  address internal constant OWNER = address(0x011e7);

  IHub internal constant HUB = AaveV4EthereumHubs.CORE_HUB;
  ISpoke internal constant SPOKE = AaveV4EthereumSpokes.MAIN_SPOKE;
  address internal constant ASSET = AaveV4EthereumAssets.WETH_UNDERLYING;

  RiskSteward internal steward;
  TestPayload internal payload;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 25171813);

    steward = new RiskSteward(RISK_COUNCIL, OWNER);

    vm.startPrank(OWNER);
    steward.setHubConfig(address(HUB), _hubConfig());
    steward.setSpokeConfig(address(SPOKE), _spokeConfig());
    vm.stopPrank();

    // Allow the steward to call HubConfigurator + SpokeConfigurator (AccessManaged `restricted`).
    // Match by 4-byte selector only so every (caller, target, selector) tuple is mocked.
    vm.mockCall(
      address(AaveV4Ethereum.ACCESS_MANAGER),
      abi.encodePacked(IAccessManager.canCall.selector),
      abi.encode(true, uint32(0))
    );

    ISpoke[] memory spokes = new ISpoke[](1);
    spokes[0] = SPOKE;
    IHub[] memory hubs = new IHub[](1);
    hubs[0] = HUB;
    ITokenizationSpoke[] memory tSpokes = new ITokenizationSpoke[](0);

    payload = new TestPayload(address(steward), spokes, hubs, tSpokes);
  }

  /// @notice End-to-end run: invoking `run()` impersonates the council, calls every non-empty
  /// category on the steward, and bumps the per-param debounce timestamps. Diff reporting and
  /// Safe broadcast are off; only the simulation pipeline is exercised here.
  function test_run_executesAllCategoriesAndBumpsDebounces() public {
    payload.run({broadcastToSafe: false, generateDiffReport: false, skipTimelock: true});

    uint40 expectedTimestamp = vm.getBlockTimestamp().toUint40();

    // Hub asset IR: only baseDrawnRate changed.
    IRiskSteward.HubAssetDebounce memory hubAssetDebounce = steward.getHubAssetDebounce(
      address(HUB),
      ASSET
    );
    assertEq(hubAssetDebounce.baseDrawnRate, expectedTimestamp, 'baseDrawnRate debounce bumped');
    assertEq(hubAssetDebounce.optimalUsageRatio, 0, 'optimalUsageRatio left at sentinel');
    assertEq(
      hubAssetDebounce.rateGrowthBeforeOptimal,
      0,
      'rateGrowthBeforeOptimal left at sentinel'
    );
    assertEq(hubAssetDebounce.rateGrowthAfterOptimal, 0, 'rateGrowthAfterOptimal left at sentinel');

    // Hub-spoke caps: both addCap and drawCap touched.
    IRiskSteward.HubSpokeAssetDebounce memory capsDebounce = steward.getHubSpokeAssetDebounce(
      address(HUB),
      address(SPOKE),
      ASSET
    );
    assertEq(capsDebounce.addCap, expectedTimestamp, 'addCap debounce bumped');
    assertEq(capsDebounce.drawCap, expectedTimestamp, 'drawCap debounce bumped');

    // Reserve config skipped — see TestPayload.reserveConfigUpdates comment.

    // Spoke dynamic update on key 0: only collateralFactor.
    IRiskSteward.SpokeDynamicDebounce memory dynamicDebounce = steward.getSpokeDynamicDebounce(
      address(SPOKE),
      address(HUB),
      ASSET,
      0
    );
    assertEq(
      dynamicDebounce.collateralFactor,
      expectedTimestamp,
      'collateralFactor debounce bumped'
    );
    assertEq(
      dynamicDebounce.maxLiquidationBonus,
      0,
      'maxLiquidationBonus on key 0 left at sentinel'
    );

    // Spoke dynamic addition writes to latestKey + 1 — read the new latest key from the spoke.
    uint256 assetId = HUB.getAssetId(ASSET);
    uint256 reserveId = SPOKE.getReserveId(address(HUB), assetId);
    uint32 newKey = SPOKE.getReserve(reserveId).dynamicConfigKey;
    IRiskSteward.SpokeDynamicDebounce memory addedDebounce = steward.getSpokeDynamicDebounce(
      address(SPOKE),
      address(HUB),
      ASSET,
      newKey
    );
    assertEq(
      addedDebounce.collateralFactor,
      expectedTimestamp,
      'addition collateralFactor debounce bumped'
    );
    assertEq(
      addedDebounce.maxLiquidationBonus,
      expectedTimestamp,
      'addition maxLiquidationBonus debounce bumped'
    );

    // Spoke liquidation: only targetHealthFactor.
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
    assertEq(
      liquidationDebounce.liquidationBonusFactor,
      0,
      'liquidationBonusFactor left at sentinel'
    );
  }

  /// @notice A caller that isn't the council can't reach the steward — `run()` works only because
  /// it impersonates `RISK_COUNCIL` via `vm.prank`.
  function test_updateHubAssetIRs_revertsWith_InvalidCaller() public {
    EthereumExample example = new EthereumExample();
    IEngine.AssetConfigUpdate[] memory updates = example.hubAssetIrUpdates();
    vm.expectRevert(IRiskSteward.InvalidCaller.selector);
    steward.updateHubAssetIRs(updates);
  }

  /// @notice The author-facing `EthereumExample` compiles and returns non-empty arrays for each
  /// of the six categories. Guards against accidental no-op overrides slipping into the demo.
  function test_ethereumExampleProducesAllSixCategories() public {
    EthereumExample example = new EthereumExample();
    assertEq(example.hubAssetIrUpdates().length, 1, 'hubAssetIrUpdates');
    assertEq(example.hubSpokeCapsUpdates().length, 1, 'hubSpokeCapsUpdates');
    assertEq(example.reserveConfigUpdates().length, 1, 'reserveConfigUpdates');
    assertEq(example.dynamicReserveConfigUpdates().length, 1, 'dynamicReserveConfigUpdates');
    assertEq(example.dynamicReserveConfigAdditions().length, 1, 'dynamicReserveConfigAdditions');
    assertEq(example.spokeLiquidationConfigUpdates().length, 1, 'spokeLiquidationConfigUpdates');
  }

  // ------------------------------------------------------------------
  // Permissive configs — wide enough to admit every TestPayload delta.
  // ------------------------------------------------------------------

  function _hubConfig() internal pure returns (IRiskSteward.HubConfig memory) {
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
      IRiskSteward.HubConfig({
        hubConfigurator: AaveV4Ethereum.HUB_CONFIGURATOR,
        rate: IRiskSteward.HubRateConfig({
          optimalUsageRatio: wideAbs,
          baseDrawnRate: wideAbs,
          rateGrowthBeforeOptimal: wideAbs,
          rateGrowthAfterOptimal: wideAbs
        }),
        cap: IRiskSteward.HubCapConfig({addCap: wideRel, drawCap: wideRel})
      });
  }

  function _spokeConfig() internal pure returns (IRiskSteward.SpokeConfig memory) {
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
      IRiskSteward.SpokeConfig({
        spokeConfigurator: AaveV4Ethereum.SPOKE_CONFIGURATOR,
        collateralRisk: wideRel,
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
      });
  }
}
