// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './DirectionalRiskSteward.Base.t.sol';

import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';

import {IChainlinkAggregator} from 'aave-price-feeds/interfaces/IChainlinkAggregator.sol';
import {IStETH} from 'aave-price-feeds/interfaces/IStETH.sol';
import {PriceCapAdapterStable} from 'aave-price-feeds/contracts/PriceCapAdapterStable.sol';
import {PendlePriceCapAdapter} from 'aave-price-feeds/contracts/PendlePriceCapAdapter.sol';
import {WstETHPriceCapAdapter} from 'aave-price-feeds/contracts/lst-adapters/WstETHPriceCapAdapter.sol';

abstract contract DirectionalRiskStewardPriceCapsTest is DirectionalRiskStewardTestBase {
  using SafeCast for uint256;
  using SafeCast for int256;

  address internal constant WETH_USD_AGG = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
  address internal constant USDT_USD_AGG = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;
  address internal constant STETH_RATIO_PROVIDER = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

  uint48 internal constant SNAPSHOT_DELAY = 1 days;
  uint16 internal constant WSTETH_MAX_YEARLY_GROWTH_BPS = 11_64;

  WstETHPriceCapAdapter internal wstEthAdapter;
  PriceCapAdapterStable internal stableAdapter;
  PendlePriceCapAdapter internal pendleAdapter;

  uint104 internal currentRatio;

  function setUp() public override {
    super.setUp();

    vm.prank(GovernanceV3Ethereum.EXECUTOR_LVL_1);
    AaveV3Ethereum.ACL_MANAGER.addRiskAdmin(address(steward));

    currentRatio = IStETH(STETH_RATIO_PROVIDER).getPooledEthByShares(1e18).toUint104();
    wstEthAdapter = new WstETHPriceCapAdapter(
      IPriceCapAdapter.CapAdapterParams({
        aclManager: AaveV3Ethereum.ACL_MANAGER,
        baseAggregatorAddress: WETH_USD_AGG,
        ratioProviderAddress: STETH_RATIO_PROVIDER,
        pairDescription: 'Capped wstETH / USD',
        minimumSnapshotDelay: SNAPSHOT_DELAY,
        priceCapParams: IPriceCapAdapter.PriceCapUpdateParams({
          snapshotRatio: currentRatio - 2,
          snapshotTimestamp: uint48(vm.getBlockTimestamp() - SNAPSHOT_DELAY * 10),
          maxYearlyRatioGrowthPercent: WSTETH_MAX_YEARLY_GROWTH_BPS
        })
      })
    );

    stableAdapter = new PriceCapAdapterStable(
      IPriceCapAdapterStable.CapAdapterStableParams({
        assetToUsdAggregator: IChainlinkAggregator(USDT_USD_AGG),
        aclManager: AaveV3Ethereum.ACL_MANAGER,
        adapterDescription: 'Capped USDT / USD',
        priceCap: int256(1.04 * 1e8)
      })
    );

    // assetToUsdAggregator is per-PT and not in the address book — read it from the deployed
    // v3 Pendle oracle for the same PT.
    IPendlePriceCapAdapter livePendle = IPendlePriceCapAdapter(
      AaveV3EthereumAssets.PT_srUSDe_25JUN2026_ORACLE
    );
    pendleAdapter = new PendlePriceCapAdapter(
      IPendlePriceCapAdapter.PendlePriceCapAdapterParams({
        assetToUsdAggregator: address(livePendle.ASSET_TO_USD_AGGREGATOR()),
        pendlePrincipalToken: AaveV3EthereumAssets.PT_srUSDe_25JUN2026_UNDERLYING,
        maxDiscountRatePerYear: 1e18,
        discountRatePerYear: 0.2e18,
        aclManager: address(AaveV3Ethereum.ACL_MANAGER),
        description: 'PT-srUSDe-25JUN2026 Adapter'
      })
    );

    vm.label(address(wstEthAdapter), 'WSTETH_CAPO');
    vm.label(address(stableAdapter), 'USDT_STABLE_CAPO');
    vm.label(address(pendleAdapter), 'PT_srUSDe_25JUN2026_CAPO');

    assertFalse(wstEthAdapter.isCapped(), 'wstEthAdapter starts uncapped');
    assertFalse(stableAdapter.isCapped(), 'stableAdapter starts uncapped');
  }

  function test_updateLstPriceCap() public {
    uint256 maxYearlyGrowthBefore = wstEthAdapter.getMaxYearlyGrowthRatePercent();
    IDirectionalRiskSteward.PriceCapLstUpdate memory p = IDirectionalRiskSteward.PriceCapLstUpdate({
      oracle: address(wstEthAdapter),
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(vm.getBlockTimestamp() - 2 * SNAPSHOT_DELAY),
        snapshotRatio: currentRatio - 2,
        maxYearlyRatioGrowthPercent: ((maxYearlyGrowthBefore * 110) / 100).toUint16() // +10%
      })
    });
    _assertUpdateLstPriceCap(p);

    skip(5 days + 1);
    uint256 maxAfter = wstEthAdapter.getMaxYearlyGrowthRatePercent();
    p = IDirectionalRiskSteward.PriceCapLstUpdate({
      oracle: address(wstEthAdapter),
      priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
        snapshotTimestamp: uint48(vm.getBlockTimestamp() - SNAPSHOT_DELAY),
        snapshotRatio: currentRatio - 1,
        maxYearlyRatioGrowthPercent: ((maxAfter * 91) / 100).toUint16() // ~-9%
      })
    });
    _assertUpdateLstPriceCap(p);
  }

  function test_updateLstPriceCaps_revertsWith_NoZeroUpdates() public {
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.NoZeroUpdates.selector);
    steward.updateLstPriceCaps(new IDirectionalRiskSteward.PriceCapLstUpdate[](0));
  }

  function test_updateLstPriceCaps_revertsWith_InvalidCaller() public {
    IDirectionalRiskSteward.PriceCapLstUpdate[] memory p = _toArray(_baseLstUpdate());
    vm.expectRevert(IDirectionalRiskSteward.InvalidCaller.selector);
    steward.updateLstPriceCaps(p);
  }

  function test_updateLstPriceCaps_zeroSnapshotRatio_revertsWith_InvalidUpdateToZero() public {
    IDirectionalRiskSteward.PriceCapLstUpdate memory p = _baseLstUpdate();
    p.priceCapUpdateParams.snapshotRatio = 0;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.InvalidUpdateToZero.selector);
    steward.updateLstPriceCaps(_toArray(p));
  }

  function test_updateLstPriceCaps_zeroSnapshotTimestamp_revertsWith_InvalidUpdateToZero() public {
    IDirectionalRiskSteward.PriceCapLstUpdate memory p = _baseLstUpdate();
    p.priceCapUpdateParams.snapshotTimestamp = 0;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.InvalidUpdateToZero.selector);
    steward.updateLstPriceCaps(_toArray(p));
  }

  function test_updateLstPriceCaps_zeroMaxYearlyGrowth_revertsWith_InvalidUpdateToZero() public {
    IDirectionalRiskSteward.PriceCapLstUpdate memory p = _baseLstUpdate();
    p.priceCapUpdateParams.maxYearlyRatioGrowthPercent = 0;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.InvalidUpdateToZero.selector);
    steward.updateLstPriceCaps(_toArray(p));
  }

  function test_updateLstPriceCaps_snapshotRatioAboveCurrent_revertsWith_UpdateNotInRange() public {
    IDirectionalRiskSteward.PriceCapLstUpdate memory p = _baseLstUpdate();
    p.priceCapUpdateParams.snapshotRatio = currentRatio + 1;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.UpdateNotInRange.selector);
    steward.updateLstPriceCaps(_toArray(p));
  }

  function test_updateLstPriceCaps_maxGrowthOutOfRange_revertsWith_UpdateNotInRange() public {
    uint256 maxYearlyGrowthBefore = wstEthAdapter.getMaxYearlyGrowthRatePercent();
    IDirectionalRiskSteward.PriceCapLstUpdate memory p = _baseLstUpdate();
    p.priceCapUpdateParams.maxYearlyRatioGrowthPercent = ((maxYearlyGrowthBefore * 120) / 100)
      .toUint16(); // +20% > 10% bound
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.UpdateNotInRange.selector);
    steward.updateLstPriceCaps(_toArray(p));
  }

  function test_updateLstPriceCaps_isCappedAfterUpdate_revertsWith_InvalidPriceCapUpdate() public {
    uint256 maxYearlyGrowthBefore = wstEthAdapter.getMaxYearlyGrowthRatePercent();
    IDirectionalRiskSteward.PriceCapLstUpdate memory p = _baseLstUpdate();
    // snapshotRatio = currentRatio / 2 makes the cap fall below the latest ratio → isCapped() true
    p.priceCapUpdateParams.snapshotRatio = currentRatio / 2;
    p.priceCapUpdateParams.maxYearlyRatioGrowthPercent = _allowedValue(
      (maxYearlyGrowthBefore * 110) / 100,
      (maxYearlyGrowthBefore * 95) / 100
    ).toUint16();
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.InvalidPriceCapUpdate.selector);
    steward.updateLstPriceCaps(_toArray(p));
  }

  function test_updateLstPriceCaps_revertsWith_DebounceNotRespected() public {
    IDirectionalRiskSteward.PriceCapLstUpdate memory p = _baseLstUpdate();
    vm.prank(RISK_COUNCIL);
    steward.updateLstPriceCaps(_toArray(p));

    // bump snapshotTimestamp so the adapter wouldn't reject; the steward's debounce fires first.
    p.priceCapUpdateParams.snapshotTimestamp = uint48(vm.getBlockTimestamp() - SNAPSHOT_DELAY);
    p.priceCapUpdateParams.snapshotRatio = currentRatio - 3;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.DebounceNotRespected.selector);
    steward.updateLstPriceCaps(_toArray(p));
  }

  function _baseLstUpdate()
    internal
    view
    returns (IDirectionalRiskSteward.PriceCapLstUpdate memory)
  {
    uint256 maxYearlyGrowthBefore = wstEthAdapter.getMaxYearlyGrowthRatePercent();
    return
      IDirectionalRiskSteward.PriceCapLstUpdate({
        oracle: address(wstEthAdapter),
        priceCapUpdateParams: IPriceCapAdapter.PriceCapUpdateParams({
          snapshotTimestamp: uint48(vm.getBlockTimestamp() - 2 * SNAPSHOT_DELAY),
          snapshotRatio: currentRatio - 2,
          maxYearlyRatioGrowthPercent: _allowedValue(
            (maxYearlyGrowthBefore * 105) / 100,
            (maxYearlyGrowthBefore * 95) / 100
          ).toUint16()
        })
      });
  }

  function test_updateStablePriceCaps() public {
    int256 priceCapBefore = stableAdapter.getPriceCap();
    IDirectionalRiskSteward.PriceCapStableUpdate memory p = IDirectionalRiskSteward
      .PriceCapStableUpdate({
        oracle: address(stableAdapter),
        priceCap: (priceCapBefore.toUint256() * 105) / 100 // +5%
      });
    _assertUpdateStablePriceCap(p);

    skip(5 days + 1);
    int256 priceCapAfter = stableAdapter.getPriceCap();
    p.priceCap = (priceCapAfter.toUint256() * 98) / 100; // -2%, stays above the USDT price
    _assertUpdateStablePriceCap(p);
  }

  function test_updateStablePriceCaps_revertsWith_NoZeroUpdates() public {
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.NoZeroUpdates.selector);
    steward.updateStablePriceCaps(new IDirectionalRiskSteward.PriceCapStableUpdate[](0));
  }

  function test_updateStablePriceCaps_revertsWith_InvalidCaller() public {
    IDirectionalRiskSteward.PriceCapStableUpdate[] memory p = _toArray(_baseStableUpdate());
    vm.expectRevert(IDirectionalRiskSteward.InvalidCaller.selector);
    steward.updateStablePriceCaps(p);
  }

  function test_updateStablePriceCaps_zeroPriceCap_revertsWith_InvalidUpdateToZero() public {
    IDirectionalRiskSteward.PriceCapStableUpdate memory p = _baseStableUpdate();
    p.priceCap = 0;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.InvalidUpdateToZero.selector);
    steward.updateStablePriceCaps(_toArray(p));
  }

  function test_updateStablePriceCaps_outOfRange_revertsWith_UpdateNotInRange() public {
    uint256 priceCapBefore = stableAdapter.getPriceCap().toUint256();
    IDirectionalRiskSteward.PriceCapStableUpdate memory p = _baseStableUpdate();
    p.priceCap = (priceCapBefore * 120) / 100; // +20% > 10% bound
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.UpdateNotInRange.selector);
    steward.updateStablePriceCaps(_toArray(p));
  }

  function test_updateStablePriceCaps_revertsWith_DebounceNotRespected() public {
    IDirectionalRiskSteward.PriceCapStableUpdate memory p = _baseStableUpdate();
    vm.prank(RISK_COUNCIL);
    steward.updateStablePriceCaps(_toArray(p));
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.DebounceNotRespected.selector);
    steward.updateStablePriceCaps(_toArray(p));
  }

  function _baseStableUpdate()
    internal
    view
    returns (IDirectionalRiskSteward.PriceCapStableUpdate memory)
  {
    uint256 priceCapBefore = stableAdapter.getPriceCap().toUint256();
    return
      IDirectionalRiskSteward.PriceCapStableUpdate({
        oracle: address(stableAdapter),
        priceCap: _allowedValue((priceCapBefore * 105) / 100, (priceCapBefore * 98) / 100)
      });
  }

  function test_updatePendleDiscountRates() public {
    uint256 currentDiscount = pendleAdapter.discountRatePerYear();
    IDirectionalRiskSteward.DiscountRatePendleUpdate memory p = IDirectionalRiskSteward
      .DiscountRatePendleUpdate({
        oracle: address(pendleAdapter),
        discountRate: currentDiscount + 0.05e18 // +5% absolute, within 10% absolute bound
      });
    _assertUpdatePendleDiscountRate(p);

    skip(5 days + 1);
    uint256 discountAfter = pendleAdapter.discountRatePerYear();
    p.discountRate = discountAfter - 0.05e18;
    _assertUpdatePendleDiscountRate(p);
  }

  function test_updatePendleDiscountRates_revertsWith_NoZeroUpdates() public {
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.NoZeroUpdates.selector);
    steward.updatePendleDiscountRates(new IDirectionalRiskSteward.DiscountRatePendleUpdate[](0));
  }

  function test_updatePendleDiscountRates_revertsWith_InvalidCaller() public {
    IDirectionalRiskSteward.DiscountRatePendleUpdate[] memory p = _toArray(_basePendleUpdate());
    vm.expectRevert(IDirectionalRiskSteward.InvalidCaller.selector);
    steward.updatePendleDiscountRates(p);
  }

  function test_updatePendleDiscountRates_zeroRate_revertsWith_InvalidUpdateToZero() public {
    IDirectionalRiskSteward.DiscountRatePendleUpdate memory p = _basePendleUpdate();
    p.discountRate = 0;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.InvalidUpdateToZero.selector);
    steward.updatePendleDiscountRates(_toArray(p));
  }

  function test_updatePendleDiscountRates_outOfRange_revertsWith_UpdateNotInRange() public {
    uint256 currentDiscount = pendleAdapter.discountRatePerYear();
    IDirectionalRiskSteward.DiscountRatePendleUpdate memory p = _basePendleUpdate();
    p.discountRate = currentDiscount + 0.11e18; // +11% > 10% absolute bound
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.UpdateNotInRange.selector);
    steward.updatePendleDiscountRates(_toArray(p));
  }

  function test_updatePendleDiscountRates_revertsWith_DebounceNotRespected() public {
    IDirectionalRiskSteward.DiscountRatePendleUpdate memory p = _basePendleUpdate();
    vm.prank(RISK_COUNCIL);
    steward.updatePendleDiscountRates(_toArray(p));
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IDirectionalRiskSteward.DebounceNotRespected.selector);
    steward.updatePendleDiscountRates(_toArray(p));
  }

  function _basePendleUpdate()
    internal
    view
    returns (IDirectionalRiskSteward.DiscountRatePendleUpdate memory)
  {
    return
      IDirectionalRiskSteward.DiscountRatePendleUpdate({
        oracle: address(pendleAdapter),
        discountRate: _allowedValue(
          pendleAdapter.discountRatePerYear() + 0.05e18,
          pendleAdapter.discountRatePerYear() - 0.05e18
        )
      });
  }

  function test_updateLstPriceCaps_whenOracleRestricted_revertsWith_RestrictedAddress() public {
    IDirectionalRiskSteward.PriceCapLstUpdate[] memory p = _toArray(_baseLstUpdate());
    vm.prank(OWNER);
    steward.setAddressRestricted(address(wstEthAdapter), true);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(
      abi.encodeWithSelector(
        IDirectionalRiskSteward.RestrictedAddress.selector,
        address(wstEthAdapter)
      )
    );
    steward.updateLstPriceCaps(p);
  }

  function test_updateStablePriceCaps_whenOracleRestricted_revertsWith_RestrictedAddress() public {
    IDirectionalRiskSteward.PriceCapStableUpdate[] memory p = _toArray(_baseStableUpdate());
    vm.prank(OWNER);
    steward.setAddressRestricted(address(stableAdapter), true);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(
      abi.encodeWithSelector(
        IDirectionalRiskSteward.RestrictedAddress.selector,
        address(stableAdapter)
      )
    );
    steward.updateStablePriceCaps(p);
  }

  function test_updatePendleDiscountRates_whenOracleRestricted_revertsWith_RestrictedAddress()
    public
  {
    IDirectionalRiskSteward.DiscountRatePendleUpdate[] memory p = _toArray(_basePendleUpdate());
    vm.prank(OWNER);
    steward.setAddressRestricted(address(pendleAdapter), true);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(
      abi.encodeWithSelector(
        IDirectionalRiskSteward.RestrictedAddress.selector,
        address(pendleAdapter)
      )
    );
    steward.updatePendleDiscountRates(p);
  }

  function test_setConfig_revertsWith_InvalidParamConfig_whenLstAbsolute() public {
    IDirectionalRiskSteward.Config memory cfg = _defaultConfig();
    cfg.oracle.priceCapLst.isChangeRelative = false;
    vm.prank(OWNER);
    vm.expectRevert(IDirectionalRiskSteward.InvalidParamConfig.selector);
    steward.setConfig(cfg);
  }

  function test_setConfig_revertsWith_InvalidParamConfig_whenStableAbsolute() public {
    IDirectionalRiskSteward.Config memory cfg = _defaultConfig();
    cfg.oracle.priceCapStable.isChangeRelative = false;
    vm.prank(OWNER);
    vm.expectRevert(IDirectionalRiskSteward.InvalidParamConfig.selector);
    steward.setConfig(cfg);
  }

  function test_setConfig_revertsWith_InvalidParamConfig_whenPendleRelative() public {
    IDirectionalRiskSteward.Config memory cfg = _defaultConfig();
    cfg.oracle.discountRatePendle.isChangeRelative = true;
    vm.prank(OWNER);
    vm.expectRevert(IDirectionalRiskSteward.InvalidParamConfig.selector);
    steward.setConfig(cfg);
  }

  function _assertUpdateLstPriceCap(IDirectionalRiskSteward.PriceCapLstUpdate memory p) internal {
    bool allowed = _isDirectionAllowed(
      wstEthAdapter.getMaxYearlyGrowthRatePercent(),
      p.priceCapUpdateParams.maxYearlyRatioGrowthPercent
    );
    if (!allowed) _expectDirectionRevert();
    vm.prank(RISK_COUNCIL);
    steward.updateLstPriceCaps(_toArray(p));
    if (!allowed) return;

    assertEq(wstEthAdapter, p);
    assertEq(steward.getOracleDebounce(address(wstEthAdapter)), vm.getBlockTimestamp().toUint40());
  }

  function _assertUpdateStablePriceCap(
    IDirectionalRiskSteward.PriceCapStableUpdate memory p
  ) internal {
    bool allowed = _isDirectionAllowed(stableAdapter.getPriceCap().toUint256(), p.priceCap);
    if (!allowed) _expectDirectionRevert();
    vm.prank(RISK_COUNCIL);
    steward.updateStablePriceCaps(_toArray(p));
    if (!allowed) return;

    assertEq(stableAdapter, p);
    assertEq(steward.getOracleDebounce(address(stableAdapter)), vm.getBlockTimestamp().toUint40());
  }

  function _assertUpdatePendleDiscountRate(
    IDirectionalRiskSteward.DiscountRatePendleUpdate memory p
  ) internal {
    bool allowed = _isDirectionAllowed(pendleAdapter.discountRatePerYear(), p.discountRate);
    if (!allowed) _expectDirectionRevert();
    vm.prank(RISK_COUNCIL);
    steward.updatePendleDiscountRates(_toArray(p));
    if (!allowed) return;

    assertEq(pendleAdapter, p);
    assertEq(steward.getOracleDebounce(address(pendleAdapter)), vm.getBlockTimestamp().toUint40());
  }
}

contract DirectionalRiskStewardPriceCapsBothTest is DirectionalRiskStewardPriceCapsTest {
  function _direction() internal pure override returns (IDirectionalRiskSteward.Direction) {
    return IDirectionalRiskSteward.Direction.BOTH;
  }
}

contract DirectionalRiskStewardPriceCapsReduceTest is DirectionalRiskStewardPriceCapsTest {
  function _direction() internal pure override returns (IDirectionalRiskSteward.Direction) {
    return IDirectionalRiskSteward.Direction.REDUCE;
  }
}

contract DirectionalRiskStewardPriceCapsIncreaseTest is DirectionalRiskStewardPriceCapsTest {
  function _direction() internal pure override returns (IDirectionalRiskSteward.Direction) {
    return IDirectionalRiskSteward.Direction.INCREASE;
  }
}
