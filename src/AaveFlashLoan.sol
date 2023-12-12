// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IFlashLoanSimpleReceiver, IPoolAddressesProvider, IPool} from "lib/aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import {CTokenInterfaces} from "lib/compound-protocol/contracts/CTokenInterfaces.sol";
import {swapRouter} from "lib/v3-periphery/contracts/SwapRouter.sol";
import {ISwapRouter} from "lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract AaveFlashLoan is IFlashLoanSimpleReceiver {
    address constant POOL_ADDRESSES_PROVIDER =
        0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant UNI_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;

    function flashLoanThenLiquidate(
        address CTokenBorrowed,
        address CTokenCollateral,
        address borrower,
        uint256 borrowBalance
    ) external {
        bytes memory liquidation = abi.encode(
            CTokenBorrowed,
            CTokenCollateral,
            borrower
        );
        POOL().flashLoanSimple(
            address(this),
            borrowToken,
            borrowBalance,
            liquidation,
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
        CTokenInterfaces(CTokenBorrowed).liquidateBorrow(
            borrower,
            amount * 10 ** 6,
            CTokenInterfaces(CTokenCollateral)
        );
        uint liquidateAmount = CTokenInterface(CTokenCollateral).redeem(
            address(this).balance
        );

        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: UNI_ADDRESS,
                tokenOut: USDC_ADDRESS,
                fee: 3000, // 0.3%
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: liquidateAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        // swap Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564
        uint256 amountOut = SwapRouter(
            0xE592427A0AEce92De3Edee1F18E0157C05861564
        ).exactInputSingle(swapParams);

        IERC20(USDC_ADDRESS).approve(address(POOL()), amount + premium);
    }

    function ADDRESSES_PROVIDER() public view returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER);
    }

    function POOL() public view returns (IPool) {
        return IPool(ADDRESSES_PROVIDER().getPool());
    }
}
