// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2} from "../lib/forge-std/src/Script.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IFlashLoanSimpleReceiver, IPoolAddressesProvider, IPool} from "../lib/aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {CErc20Interface, CTokenInterface} from "../lib/compound-protocol/contracts/CTokeninterfaces.sol";
import {CToken} from "lib/compound-protocol/contracts/CToken.sol";

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

contract AaveFlashLoan is IFlashLoanSimpleReceiver {
    address constant POOL_ADDRESSES_PROVIDER =
        0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant UNI_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;

    IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 uni = IERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);

    function flashLoanThenLiquidate(
        address borrowedUnderlying,
        address CTokenBorrowed,
        address CTokenCollateral,
        address borrower,
        uint256 borrowBalance
    ) external {
        bytes memory liquidateInfo = abi.encode(
            CTokenBorrowed,
            CTokenCollateral,
            borrower
        );

        POOL().flashLoanSimple(
            address(this),
            borrowedUnderlying,
            borrowBalance,
            liquidateInfo,
            0
        );
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        (
            address CTokenBorrowed,
            address CTokenCollateral,
            address borrower
        ) = abi.decode(params, (address, address, address));

        IERC20(USDC_ADDRESS).approve(CTokenBorrowed, type(uint256).max);

        CErc20Interface(CTokenBorrowed).liquidateBorrow(
            borrower,
            amount,
            CTokenInterface(CTokenCollateral)
        );

        CErc20Interface(CTokenCollateral).redeem(
            CTokenInterface(CTokenCollateral).balanceOf(address(this))
        );

        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: UNI_ADDRESS,
                tokenOut: USDC_ADDRESS,
                fee: 3000, // 0.3%
                recipient: address(this),
                deadline: block.timestamp + 100,
                amountIn: uni.balanceOf(address(this)),
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        uni.approve(
            0xE592427A0AEce92De3Edee1F18E0157C05861564,
            type(uint256).max
        );

        IERC20(USDC_ADDRESS).approve(address(POOL()), amount + premium);

        uint256 amountOut = ISwapRouter(
            0xE592427A0AEce92De3Edee1F18E0157C05861564
        ).exactInputSingle(swapParams);

        return true;
    }

    function ADDRESSES_PROVIDER() public view returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER);
    }

    function POOL() public view returns (IPool) {
        return IPool(ADDRESSES_PROVIDER().getPool());
    }
}
