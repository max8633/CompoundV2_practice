// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "../lib/forge-std/src/Script.sol";
import "../lib/compound-protocol/contracts/Comptroller.sol";
import "../lib/compound-protocol/contracts/ComptrollerG7.sol";
import "../lib/compound-protocol/contracts/Unitroller.sol";
import "../lib/compound-protocol/contracts/CErc20Delegate.sol";
import "../lib/compound-protocol/contracts/CErc20Delegator.sol";
import "../lib/compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import "../lib/compound-protocol/contracts/SimplePriceOracle.sol";
import "../lib/compound-protocol/contracts/ComptrollerInterface.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Token} from "../src/ERC20Token.sol";

contract MyScript is Script {
    ERC20 public TokenA;
    ERC20 public TokenB;
    SimplePriceOracle SimplePriceOracle_;
    Comptroller Comptroller_;
    Unitroller Unitroller_;
    ComptrollerG7 ComptrollerProxy_;
    WhitePaperInterestRateModel WhitePaperInterestRateModel_;
    CErc20Delegate CErc20Delegate_;
    CErc20Delegator cTokenA;
    CErc20Delegator cTokenB;

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

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
            payable(0x702CA8967B88eb11596Bc0C6D747BD5f00b3430a),
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
            payable(0x702CA8967B88eb11596Bc0C6D747BD5f00b3430a),
            address(CErc20Delegate_),
            ""
        );

        ComptrollerProxy_._supportMarket(CToken(address(cTokenA)));
        ComptrollerProxy_._supportMarket(CToken(address(cTokenB)));
        //set price oracle
        ComptrollerProxy_._setPriceOracle(SimplePriceOracle_);

        SimplePriceOracle_.setUnderlyingPrice(CToken(address(cTokenA)), 1e18);
        SimplePriceOracle_.setUnderlyingPrice(CToken(address(cTokenB)), 1e20);

        ComptrollerProxy_._setCollateralFactor(CToken(address(cTokenB)), 5e17);

        ComptrollerProxy_._setCloseFactor(5e17);

        ComptrollerProxy_._setLiquidationIncentive(1.1 * 1e18);

        vm.stopBroadcast();
    }
}
