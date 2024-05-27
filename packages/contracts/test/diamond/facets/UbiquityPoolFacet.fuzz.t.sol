// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/console.sol";
import {DiamondTestSetup} from "../DiamondTestSetup.sol";
import {IDollarAmoMinter} from "../../../src/dollar/interfaces/IDollarAmoMinter.sol";
import {LibUbiquityPool} from "../../../src/dollar/libraries/LibUbiquityPool.sol";
import {MockChainLinkFeed} from "../../../src/dollar/mocks/MockChainLinkFeed.sol";
import {MockERC20} from "../../../src/dollar/mocks/MockERC20.sol";
import {MockCurveStableSwapNG} from "../../../src/dollar/mocks/MockCurveStableSwapNG.sol";
import {MockCurveTwocryptoOptimized} from "../../../src/dollar/mocks/MockCurveTwocryptoOptimized.sol";

contract UbiquityPoolFacetFuzzTest is DiamondTestSetup {
    // mock three tokens: collateral token, stable token, wrapped ETH token
    MockERC20 collateralToken;
    MockERC20 stableToken;
    MockERC20 wethToken;

    // mock three ChainLink price feeds, one for each token
    MockChainLinkFeed collateralTokenPriceFeed;
    MockChainLinkFeed ethUsdPriceFeed;
    MockChainLinkFeed stableUsdPriceFeed;

    // mock two curve pools Stablecoin/Dollar and Governance/WETH
    MockCurveStableSwapNG curveDollarPlainPool;
    MockCurveTwocryptoOptimized curveGovernanceEthPool;

    address user = address(1);

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);

        collateralToken = new MockERC20("COLLATERAL", "CLT", 18);
        wethToken = new MockERC20("WETH", "WETH", 18);
        stableToken = new MockERC20("STABLE", "STABLE", 18);

        collateralTokenPriceFeed = new MockChainLinkFeed();
        ethUsdPriceFeed = new MockChainLinkFeed();
        stableUsdPriceFeed = new MockChainLinkFeed();

        curveDollarPlainPool = new MockCurveStableSwapNG(
            address(stableToken),
            address(dollarToken)
        );

        curveGovernanceEthPool = new MockCurveTwocryptoOptimized(
            address(governanceToken),
            address(wethToken)
        );

        // add collateral token to the pool
        uint256 poolCeiling = 50_000e18; // max 50_000 of collateral tokens is allowed
        ubiquityPoolFacet.addCollateralToken(
            address(collateralToken),
            address(collateralTokenPriceFeed),
            poolCeiling
        );

        // set collateral price initial feed mock params
        collateralTokenPriceFeed.updateMockParams(
            1, // round id
            100_000_000, // answer, 100_000_000 = $1.00 (chainlink 8 decimals answer is converted to 6 decimals pool price)
            block.timestamp, // started at
            block.timestamp, // updated at
            1 // answered in round
        );

        // set ETH/USD price initial feed mock params
        ethUsdPriceFeed.updateMockParams(
            1, // round id
            2000_00000000, // answer, 2000_00000000 = $2000 (8 decimals)
            block.timestamp, // started at
            block.timestamp, // updated at
            1 // answered in round
        );

        // set stable/USD price feed initial mock params
        stableUsdPriceFeed.updateMockParams(
            1, // round id
            100_000_000, // answer, 100_000_000 = $1.00 (8 decimals)
            block.timestamp, // started at
            block.timestamp, // updated at
            1 // answered in round
        );

        // set ETH/Governance initial price to 20k in Curve pool mock (20k GOV == 1 ETH)
        curveGovernanceEthPool.updateMockParams(20_000e18);

        // set price feed for collateral token
        ubiquityPoolFacet.setCollateralChainLinkPriceFeed(
            address(collateralToken), // collateral token address
            address(collateralTokenPriceFeed), // price feed address
            1 days // price feed staleness threshold in seconds
        );

        // set price feed for ETH/USD pair
        ubiquityPoolFacet.setEthUsdChainLinkPriceFeed(
            address(ethUsdPriceFeed), // price feed address
            1 days // price feed staleness threshold in seconds
        );

        // set price feed for stable/USD pair
        ubiquityPoolFacet.setStableUsdChainLinkPriceFeed(
            address(stableUsdPriceFeed), // price feed address
            1 days // price feed staleness threshold in seconds
        );

        // enable collateral at index 0
        ubiquityPoolFacet.toggleCollateral(0);
        // set mint and redeem initial fees
        ubiquityPoolFacet.setFees(
            0, // collateral index
            10000, // 1% mint fee
            20000 // 2% redeem fee
        );
        // set redemption delay to 2 blocks
        ubiquityPoolFacet.setRedemptionDelayBlocks(2);
        // set mint price threshold to $1.01 and redeem price to $0.99
        ubiquityPoolFacet.setPriceThresholds(1010000, 990000);
        // set collateral ratio to 100%
        ubiquityPoolFacet.setCollateralRatio(1_000_000);
        // set Governance-ETH pool
        ubiquityPoolFacet.setGovernanceEthPoolAddress(
            address(curveGovernanceEthPool)
        );

        // set Curve plain pool in manager facet
        managerFacet.setStableSwapPlainPoolAddress(
            address(curveDollarPlainPool)
        );

        // stop being admin
        vm.stopPrank();

        // mint 2000 Governance tokens to the user
        deal(address(governanceToken), user, 2000e18);
        // mint 100 collateral tokens to the user
        collateralToken.mint(address(user), 100e18);
        // user approves the pool to transfer collateral
        vm.prank(user);
        collateralToken.approve(address(ubiquityPoolFacet), 100e18);
    }

    //========================
    // Dollar Mint fuzz tests
    //========================

    function testMintDollar_FuzzCollateralRatio(
        uint newCollateralRatio
    ) public {
        vm.assume(newCollateralRatio <= 1_000_000);
        vm.prank(admin);
        ubiquityPoolFacet.setPriceThresholds(
            1000000, // mint threshold
            990000 // redeem threshold
        );

        // fuzz collateral ratio
        vm.prank(admin);
        ubiquityPoolFacet.setCollateralRatio(newCollateralRatio);

        // balances before
        assertEq(collateralToken.balanceOf(address(ubiquityPoolFacet)), 0);
        assertEq(dollarToken.balanceOf(user), 0);
        assertEq(governanceToken.balanceOf(user), 2000e18);

        vm.prank(user);
        (
            uint256 totalDollarMint,
            uint256 collateralNeeded,
            uint256 governanceNeeded
        ) = ubiquityPoolFacet.mintDollar(
                0, // collateral index
                100e18, // Dollar amount
                99e18, // min amount of Dollars to mint
                100e18, // max collateral to send
                1100e18, // max Governance tokens to send
                false // force 1-to-1 mint (i.e. provide only collateral without Governance tokens)
            );

        assertEq(totalDollarMint, 99e18);
        assertEq(collateralNeeded, 0);
        assertEq(governanceNeeded, 1000000000000000000000); // 1000 = 100 Dollar * $0.1 Governance from oracle

        // balances after
        assertEq(collateralToken.balanceOf(address(ubiquityPoolFacet)), 0);
        assertEq(dollarToken.balanceOf(user), 99e18);
        assertEq(governanceToken.balanceOf(user), 2000e18 - governanceNeeded);
    }

    /**
     * @notice Fuzz Dollar minting scenario for Dollar price below threshold
     * @param dollarPriceUsd Ubiquity Dollar token price from Curve pool (Stable coin/Ubiquity Dollar)
     */
    function testMintDollar_FuzzDollarPriceUsdTooLow(
        uint256 dollarPriceUsd
    ) public {
        // Stable coin/USD ChainLink feed is mocked to $1.00
        // Mint price threshold set up to $1.01 == 1010000
        // Fuzz Dollar price in Curve plain pool (1 Stable coin / x Dollar)
        vm.assume(dollarPriceUsd < 1010000000000000000); // 1.01e18 , less than threshold
        curveDollarPlainPool.updateMockParams(dollarPriceUsd);
        vm.prank(user);
        vm.expectRevert("Dollar price too low");
        ubiquityPoolFacet.mintDollar(
            0, // collateral index
            100e18, // Dollar amount
            90e18, // min amount of Dollars to mint
            100e18, // max collateral to send
            0, // max Governance tokens to send
            false // force 1-to-1 mint (i.e. provide only collateral without Governance tokens)
        );
    }

    function testMintDollar_FuzzDollarAmountSlippage(
        uint256 dollarAmount
    ) public {
        vm.prank(admin);
        ubiquityPoolFacet.setPriceThresholds(
            1000000, // mint threshold
            990000 // redeem threshold
        );

        vm.prank(user);
        vm.expectRevert("Dollar slippage");
        ubiquityPoolFacet.mintDollar(
            0, // collateral index
            100e18, // Dollar amount
            100e18, // min amount of Dollars to mint
            100e18, // max collateral to send
            0, // max Governance tokens to send
            false // force 1-to-1 mint (i.e. provide only collateral without Governance tokens)
        );
    }

    function testMintDollar_FuzzCollateralAmountSlippage(
        uint256 collateralAmount
    ) public {
        vm.prank(admin);
        ubiquityPoolFacet.setPriceThresholds(
            1000000, // mint threshold
            990000 // redeem threshold
        );

        vm.prank(user);
        vm.expectRevert("Collateral slippage");
        ubiquityPoolFacet.mintDollar(
            0, // collateral index
            100e18, // Dollar amount
            90e18, // min amount of Dollars to mint
            10e18, // max collateral to send
            0, // max Governance tokens to send
            false // force 1-to-1 mint (i.e. provide only collateral without Governance tokens)
        );
    }

    function testMintDollar_FuzzGovernanceAmountSlippage(
        uint256 governanceAmount
    ) public {
        vm.prank(admin);
        ubiquityPoolFacet.setPriceThresholds(
            1000000, // mint threshold
            990000 // redeem threshold
        );

        // admin sets collateral ratio to 0%
        vm.prank(admin);
        ubiquityPoolFacet.setCollateralRatio(0);

        vm.prank(user);
        vm.expectRevert("Governance slippage");
        ubiquityPoolFacet.mintDollar(
            0, // collateral index
            100e18, // Dollar amount
            90e18, // min amount of Dollars to mint
            10e18, // max collateral to send
            0, // max Governance tokens to send
            false // force 1-to-1 mint (i.e. provide only collateral without Governance tokens)
        );
    }
}
