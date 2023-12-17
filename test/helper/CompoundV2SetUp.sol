// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {MyScript} from "../../script/CompoundV2.s.sol";
import {Test} from "../../lib/forge-std/src/Test.sol";
import {Script, console2} from "../../lib/forge-std/src/Script.sol";
import "../../lib/compound-protocol/contracts/Comptroller.sol";
import "../../lib/compound-protocol/contracts/ComptrollerG7.sol";
import "../../lib/compound-protocol/contracts/Unitroller.sol";
import "../../lib/compound-protocol/contracts/CErc20Delegate.sol";
import "../../lib/compound-protocol/contracts/CErc20Delegator.sol";
import "../../lib/compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import "../../lib/compound-protocol/contracts/SimplePriceOracle.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Token} from "../../src/ERC20Token.sol";

contract CompoundV2SetUp is Test {
    address public admin = makeAddr("admin");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    ERC20 public tokenA = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ERC20 public tokenB = ERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);

    SimplePriceOracle SimplePriceOracle_;
    Comptroller Comptroller_;
    Unitroller Unitroller_;
    ComptrollerG7 ComptrollerProxy_;
    WhitePaperInterestRateModel WhitePaperInterestRateModel_;
    CErc20Delegate CErc20Delegate_;
    CErc20Delegator cTokenA;
    CErc20Delegator cTokenB;

    function setUp() public virtual {
        uint mainnetFork = vm.createFork(
            "https://mainnet.infura.io/v3/d5aad10125ce4463972de51361f5e5de"
        );

        vm.selectFork(mainnetFork);
        vm.rollFork(17_465_000);

        vm.startPrank(admin);

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
            address(tokenA),
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
            address(tokenB),
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
        SimplePriceOracle_.setUnderlyingPrice(
            CToken(address(cTokenA)),
            1 * 10 ** (36 - tokenA.decimals())
        );
        SimplePriceOracle_.setUnderlyingPrice(
            CToken(address(cTokenB)),
            5 * 10 ** (36 - tokenB.decimals())
        );
        //set cTokenB collateral factor
        ComptrollerProxy_._setCollateralFactor(CToken(address(cTokenB)), 5e17);
        //set close factor
        ComptrollerProxy_._setCloseFactor(5e17);
        //set liquidation incentive
        ComptrollerProxy_._setLiquidationIncentive(1.08 * 1e18);

        vm.stopPrank();
    }
}
