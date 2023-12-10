// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "../lib/forge-std/src/Test.sol";
import {Script, console2} from "../lib/forge-std/src/Script.sol";
import {MyScript} from "../script/CompoundV2.s.sol";
import "../lib/compound-protocol/contracts/Comptroller.sol";
import "../lib/compound-protocol/contracts/ComptrollerG7.sol";
import "../lib/compound-protocol/contracts/Unitroller.sol";
import "../lib/compound-protocol/contracts/CErc20Delegate.sol";
import "../lib/compound-protocol/contracts/CErc20Delegator.sol";
import "../lib/compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import "../lib/compound-protocol/contracts/SimplePriceOracle.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Token} from "../src/ERC20Token.sol";

contract CompoundTest is MyScript, Test {
    address public admin = makeAddr("admin");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    function setUp() public {
        vm.startPrank(admin);

        TokenA = new ERC20Token("Underlying Token", "UTKA");
        TokenB = new ERC20Token("Underlying Token", "UTKB");
        //oracle
        SimplePriceOracle_ = new SimplePriceOracle();
        //impl comptroller
        Comptroller_ = new Comptroller();
        //proxy comptroller
        Unitroller_ = new Unitroller();

        //proxy delegatecall to set address of comptroller
        Unitroller_._setPendingImplementation(address(Comptroller_));
        Comptroller_._become(Unitroller_);
        ComptrollerProxy_ = ComptrollerG7(address(Unitroller_));
        //Interest rate model
        WhitePaperInterestRateModel_ = new WhitePaperInterestRateModel(0, 0);

        //impl CErc20
        CErc20Delegate_ = new CErc20Delegate();
        //proxy CErc20
        cTokenA = new CErc20Delegator(
            address(TokenA),
            ComptrollerInterface(address(Unitroller_)),
            WhitePaperInterestRateModel_,
            1e18,
            "cToken of Underlying TokenA",
            "cUTKA",
            18,
            payable(admin),
            address(CErc20Delegate_),
            ""
        );

        cTokenB = new CErc20Delegator(
            address(TokenB),
            ComptrollerInterface(address(Unitroller_)),
            WhitePaperInterestRateModel_,
            1e18,
            "cToken of Underlying TokenB",
            "cUTKB",
            18,
            payable(admin),
            address(CErc20Delegate_),
            ""
        );
        //add cTokenA and cTokenB to market
        ComptrollerProxy_._supportMarket(CToken(address(cTokenA)));
        ComptrollerProxy_._supportMarket(CToken(address(cTokenB)));
        //set price oracle
        ComptrollerProxy_._setPriceOracle(SimplePriceOracle_);
        //set cTokenA and cTokenB price
        SimplePriceOracle_.setUnderlyingPrice(CToken(address(cTokenA)), 1e18);
        SimplePriceOracle_.setUnderlyingPrice(CToken(address(cTokenB)), 1e20);
        //set cTokenB collateral factor
        ComptrollerProxy_._setCollateralFactor(CToken(address(cTokenB)), 5e17);
        //set close factor
        ComptrollerProxy_._setCloseFactor(5e17);
        //set liquidation incentive
        ComptrollerProxy_._setLiquidationIncentive(1.1 * 1e18);

        deal(address(TokenA), user2, 1e21);
        deal(address(TokenB), user2, 1e21);
        deal(address(TokenA), user1, 1e20);
        deal(address(TokenB), user1, 1e20);
    }

    function test_mint_redeem() public {
        //test mint and redeem function
        vm.startPrank(user1);
        //approve cTokenA transfer TokenA to cTokenA
        TokenA.approve(address(cTokenA), type(uint256).max);
        cTokenA.mint(100 * 10 ** cTokenA.decimals());
        assertEq(cTokenA.balanceOf(user1), 100 * 10 ** cTokenA.decimals());
        assertEq(TokenA.balanceOf(user1), 0);

        cTokenA.redeem(100 * 10 ** cTokenA.decimals());
        assertEq(cTokenA.balanceOf(user1), 0);
        assertEq(TokenA.balanceOf(user1), 100 * 10 ** TokenA.decimals());

        vm.stopPrank();
    }

    function test_borrow_repay() public {
        //user2 add some TokenA to cTokenA contract
        vm.startPrank(user2);

        TokenA.approve(address(cTokenA), type(uint256).max);
        cTokenA.mint(2e20);

        vm.stopPrank();
        //user1 deposit TokenB
        vm.startPrank(user1);
        TokenB.approve(address(cTokenB), type(uint256).max);
        cTokenB.mint(1e18);
        assertEq(TokenB.balanceOf(user1), 1e20 - 1e18);
        //user1 use TokenB as collateral then borrow TokenA out
        address[] memory CTokens = new address[](1);
        CTokens[0] = address(cTokenB);
        ComptrollerProxy_.enterMarkets(CTokens);
        cTokenA.borrow(5e19);
        assertEq(TokenA.balanceOf(user1), 15e19);
        //user1 repay TokenA and get TokenB back
        TokenA.approve(address(cTokenA), type(uint256).max);
        cTokenA.repayBorrow(5e19);
        assertEq(TokenA.balanceOf(user1), 1e20);

        vm.stopPrank();
    }

    function test_change_collateral_factor_then_liquidate() public {
        vm.startPrank(user2);
        TokenA.approve(address(cTokenA), type(uint256).max);
        cTokenA.mint(2e20);
        vm.stopPrank();

        vm.startPrank(user1);
        TokenB.approve(address(cTokenB), type(uint256).max);
        cTokenB.mint(1e18);
        assertEq(TokenB.balanceOf(user1), 1e20 - 1e18);

        address[] memory CTokens = new address[](1);
        CTokens[0] = address(cTokenB);
        ComptrollerProxy_.enterMarkets(CTokens);

        cTokenA.borrow(5e19);
        assertEq(TokenA.balanceOf(user1), 15e19);

        vm.stopPrank();
        //admin set collateral factor to 20%
        vm.startPrank(admin);
        ComptrollerProxy_._setCollateralFactor(CToken(address(cTokenB)), 2e17);
        vm.stopPrank();
        //user2 check if there is shortfall happened on user1
        vm.startPrank(user2);
        TokenA.approve(address(cTokenA), type(uint256).max);
        (, , uint256 shortfall) = ComptrollerProxy_.getAccountLiquidity(user1);
        require(shortfall > 0, "not allowed to liquidate");
        //check user1 borrowamount of TokenA
        uint256 borrowAmount = cTokenA.borrowBalanceStored(user1);
        //user2 liquidate
        cTokenA.liquidateBorrow(
            user1,
            (borrowAmount * ComptrollerProxy_.closeFactorMantissa()) / 1e18,
            cTokenB
        );
        //check seizeTokens amount
        (, uint256 seizeTokens) = ComptrollerProxy_
            .liquidateCalculateSeizeTokens(
                address(cTokenA),
                address(cTokenB),
                (borrowAmount * ComptrollerProxy_.closeFactorMantissa()) / 1e18
            );
        //liquidator get amount need to minus protocol seize amount
        uint256 liquidatorGetAmount = (seizeTokens *
            (1e18 - cTokenA.protocolSeizeShareMantissa())) / 1e18;
        assertEq(cTokenB.balanceOf(user2), liquidatorGetAmount);

        vm.stopPrank();
    }

    function test_change_underlying_price_then_liquidate() public {
        vm.startPrank(user2);
        TokenA.approve(address(cTokenA), type(uint256).max);
        cTokenA.mint(2e20);
        vm.stopPrank();

        vm.startPrank(user1);
        TokenB.approve(address(cTokenB), type(uint256).max);
        cTokenB.mint(1e18);
        assertEq(TokenB.balanceOf(user1), 1e20 - 1e18);

        address[] memory CTokens = new address[](1);
        CTokens[0] = address(cTokenB);
        ComptrollerProxy_.enterMarkets(CTokens);

        cTokenA.borrow(5e19);
        assertEq(TokenA.balanceOf(user1), 15e19);

        vm.stopPrank();
        //admin set underlying price to 40USD
        vm.startPrank(admin);
        SimplePriceOracle_.setUnderlyingPrice(CToken(address(cTokenB)), 4e19);
        vm.stopPrank();

        vm.startPrank(user2);
        TokenA.approve(address(cTokenA), type(uint256).max);
        (, , uint256 shortfall) = ComptrollerProxy_.getAccountLiquidity(user1);
        require(shortfall > 0, "not allowed to liquidate");

        uint256 borrowAmount = cTokenA.borrowBalanceStored(user1);
        cTokenA.liquidateBorrow(
            user1,
            (borrowAmount * ComptrollerProxy_.closeFactorMantissa()) / 1e18,
            cTokenB
        );
        (, uint256 seizeTokens) = ComptrollerProxy_
            .liquidateCalculateSeizeTokens(
                address(cTokenA),
                address(cTokenB),
                (borrowAmount * ComptrollerProxy_.closeFactorMantissa()) / 1e18
            );
        uint256 liquidatorGetAmount = (seizeTokens *
            (1e18 - cTokenA.protocolSeizeShareMantissa())) / 1e18;
        assertEq(cTokenB.balanceOf(user2), liquidatorGetAmount);

        vm.stopPrank();
    }
}
