// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Comptroller} from "../lib/compound-protocol/contracts/Comptroller.sol";
import {Unitroller} from "../lib/compound-protocol/contracts/Unitroller.sol";
import {CErc20Delegate} from "../lib/compound-protocol/contracts/CErc20Delegate.sol";
import {CErc20Delegator} from "../lib/compound-protocol/contracts/CErc20Delegator.sol";
import {WhitePaperInterestRateModel} from "../lib/compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import {SimplePriceOracle} from "../lib/compound-protocol/contracts/SimplePriceOracle.sol";

contract Compound is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
    }
}
