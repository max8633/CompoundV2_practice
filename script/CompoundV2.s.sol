// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../lib/compound-protocol/contracts/Comptroller.sol";
import "../lib/compound-protocol/contracts/Unitroller.sol";
import "../lib/compound-protocol/contracts/CErc20Delegate.sol";
import "../lib/compound-protocol/contracts/CErc20Delegator.sol";
import "../lib/compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import "../lib/compound-protocol/contracts/SimplePriceOracle.sol";
import {ERC20Token} from "../src/ERC20Token.sol";

contract MyScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        //underlying erc20 token
        ERC20Token UnderlyingERC20Token = new ERC20Token(
            "Underlying ERC20 Token",
            "ULT"
        );
        //oracle
        SimplePriceOracle SimplePriceOracle = new SimplePriceOracle();
        //impl comptroller
        Comptroller Comptroller = new Comptroller();
        //set price oracle
        Comptroller._setPriceOracle(SimplePriceOracle);
        //proxy comptroller
        Unitroller Unitroller = new Unitroller();

        //proxy delegatecall to set address of comptroller
        Unitroller._setPendingImplementation(address(Comptroller));
        Comptroller._become(Unitroller);
        //Interest rate model
        WhitePaperInterestRateModel WhitePaperInterestRateModel = new WhitePaperInterestRateModel(
                0,
                0
            );

        //impl CErc20
        CErc20Delegate CErc20Delegate = new CErc20Delegate();
        //proxy CErc20
        CErc20Delegator CErc20Delegator = new CErc20Delegator(
            address(UnderlyingERC20Token),
            Unitroller,
            WhitePaperInterestRateModel,
            1e18,
            "cToken of Underlying ERC20 Token",
            "cULT",
            18,
            payable(msg.sender),
            address(CErc20Delegate),
            abi.encodeWithSignature(
                "initialize(address,address,address,uint256,string,string,uint8)",
                address(UnderlyingERC20Token),
                Comptroller,
                WhitePaperInterestRateModel,
                5,
                "cToken of Underlying ERC20 Token",
                "cULT",
                18
            )
        );

        vm.stopBroadcast();
    }
}
