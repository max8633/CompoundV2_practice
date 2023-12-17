// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {MyScript} from "../script/CompoundV2.s.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {Script, console2} from "../lib/forge-std/src/Script.sol";
import {AaveFlashLoan} from "../src/AaveFlashLoan.sol";
import {CErc20Interface, CTokenInterface} from "../lib/compound-protocol/contracts/CTokeninterfaces.sol";
import {CToken} from "../lib/compound-protocol/contracts/CToken.sol";
import {CompoundV2SetUp} from "test/helper/CompoundV2SetUp.sol";

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}

contract FlashLoanTest is CompoundV2SetUp {
    AaveFlashLoan aaveFlashLoan;

    function setUp() public override {
        super.setUp();

        aaveFlashLoan = new AaveFlashLoan();

        deal(address(tokenA), admin, 1e25);
        deal(address(tokenB), admin, 1e25);

        deal(address(tokenB), user1, 1e21);

        deal(address(tokenA), user2, 1e22);
        deal(address(tokenB), user2, 1e22);
    }

    function addToken() public {
        vm.startPrank(admin);

        tokenA.approve(address(cTokenA), type(uint256).max);
        tokenB.approve(address(cTokenB), type(uint256).max);

        cTokenA.mint(1e25);
        cTokenB.mint(1e25);

        vm.stopPrank();
    }

    function test_aave_pool_amount() public {
        uint256 aaveAmount = tokenA.balanceOf(
            address(aaveFlashLoan.ADDRESSES_PROVIDER())
        );
        console2.log(aaveAmount);
    }

    function test_flash_loan_liquidate_with_AAVEv3() public {
        addToken();

        vm.startPrank(user1);

        tokenB.approve(address(cTokenB), type(uint256).max);
        cTokenB.mint(1000 * 10 ** tokenB.decimals());
        assertEq(cTokenB.balanceOf(user1), 1000 * 10 ** tokenB.decimals());

        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cTokenB);
        ComptrollerProxy_.enterMarkets(cTokens);

        cTokenA.borrow(2500 * 10 ** tokenA.decimals());
        assertEq(tokenA.balanceOf(user1), 2500 * 10 ** tokenA.decimals());

        vm.stopPrank();

        vm.startPrank(admin);
        SimplePriceOracle_.setUnderlyingPrice(
            CToken(address(cTokenB)),
            4 * 10 ** (36 - tokenB.decimals())
        );
        vm.stopPrank();

        vm.startPrank(user2);

        aaveFlashLoan.flashLoanThenLiquidate(
            address(tokenA),
            address(cTokenA),
            address(cTokenB),
            user1,
            (cTokenA.borrowBalanceStored(user1) *
                ComptrollerProxy_.closeFactorMantissa()) / 1e18
        );

        uint256 liquidatorGetAmount = tokenA.balanceOf(address(aaveFlashLoan));
        assertGt(liquidatorGetAmount, 63 * 10 * tokenA.decimals());
    }
}
