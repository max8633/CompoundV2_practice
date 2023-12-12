// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {MyScript} from "script/CompoundV2.s.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {Script, console2} from "lib/forge-std/src/Script.sol";
import {CompoundV2SetUp} from "test/helper/CompoundV2SetUp.sol";
import {AaveFlashLoan} from "src/AaveFlashLoan.sol";

contract FlashLoanTest is MyScript, Test, CompoundV2SetUp {
    uint256 mainnetFork;
    AaveFlashLoan aaveFlashLoan;

    function setUp() public override {
        super.setUp();
        aaveFlashLoan = new aaveFlashLoan();

        mainnetFork = vm.createFork(
            "https://mainnet.infura.io/v3/d5aad10125ce4463972de51361f5e5de"
        );
        vm.selectFork(mainnetFork);

        deal(address(tokenA), user2, 1e22);
        deal(address(tokenB), user2, 1e22);
    }

    function test_flash_loan_liquidate_with_AAVEv3() public {
        vm.startPrank(user1);

        tokenA.approve(address(cTokenA), type(uint256).max);
        cTokenA.mint(1e21);
        assertEq(cTokenA.balanceOf(user1), 1e21);

        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cTokenA);
        ComptrollerProxy_.enterMarkets(cTokens);
        cTokenB.borrow(2.5e21);
        assertEq(cTokenB.balanceOf(user1), 2.5e21);

        vm.stopPrank();

        vm.startPrank(admin);
        SimplePriceOracle_.setUnderlyingPrice(CToken(addressc(TokenB)), 4e18);
        vm.stopPrank();

        vm.startPrank(user2);
        aaveFlashLoan.flashLoanThenLiquidate(
            address(tokenA),
            address(tokenB),
            user1,
            cTokenB.borrowBalanceStored(user1)
        );

        uint256 liquidatorGetAmount = tokenA.balanceOf(address(aaveFlashLoan));
        console2.log(liquidatorGetAmount);
    }
}
