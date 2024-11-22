// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployDexerExchange} from "script/DeployDexerExchange.s.sol";
import {DexerExchange} from "src/DexerExchange.sol";
import {DexerToken} from "src/DexerToken.sol";

contract DexerExchangeTest is Test {
    uint256 public constant STARTING_BALANCE = 100 ether;
    address USER = makeAddr("user");
    DexerExchange dexerExchange;
    DexerToken dexerToken;

    function setUp() external {
        DeployDexerExchange deployDexerExchange = new DeployDexerExchange();

        (dexerExchange, dexerToken) = deployDexerExchange.run();

        // Fund user with ETH
        vm.deal(USER, STARTING_BALANCE);
        vm.deal(dexerExchange.i_owner(), STARTING_BALANCE);

        // Transfer some DexerToken from owner to user for testing
        vm.startPrank(dexerExchange.i_owner());
        dexerToken.transfer(USER, 100 ether);
        vm.stopPrank();

        // Approve spending of dexer token for the exchange on USER's behalf
        vm.startPrank(USER);
        dexerToken.approve(address(dexerExchange), 10 ether);
        vm.stopPrank();
        // Approve spending of dexer token for the exchange on USER's behalf
        vm.startPrank(dexerExchange.i_owner());
        dexerToken.approve(address(dexerExchange), 10 ether);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIER
    //////////////////////////////////////////////////////////////*/
    modifier withLiquidity() {
        uint256 ethAmount = 1 ether;
        uint256 tokenAmount = 10 ether;
        // Add liquidity as USER
        vm.startPrank(USER);
        dexerExchange.addLiquidity{value: ethAmount}({dexerTokenAmount: tokenAmount});
        vm.stopPrank();

        // Add liquidity as i_owner
        vm.startPrank(dexerExchange.i_owner());
        dexerExchange.addLiquidity{value: ethAmount}({dexerTokenAmount: tokenAmount});
        vm.stopPrank();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             ADD LIQUIDITY
    //////////////////////////////////////////////////////////////*/
    function testAddLiquidityEmptyReserve() public {
        uint256 ethAmount = 1 ether;
        uint256 tokenAmount = 10 ether;

        // Add liquidity
        vm.startPrank(USER);
        uint256 lpTokensMinted = dexerExchange.addLiquidity{value: ethAmount}({dexerTokenAmount: tokenAmount});
        vm.stopPrank();

        // Balances and reserves after adding liquidity
        uint256 ethReserveAfter = address(dexerExchange).balance;
        uint256 tokenReserveAfter = dexerExchange.getTokenReserveBalance();
        uint256 totalLPTokenSupplyAfter = dexerExchange.totalSupply();
        uint256 userLPTokenBalanceAfter = dexerExchange.balanceOf(USER);

        // Assert LP tokens are minted and transferred in the correct proportion
        assertEq(totalLPTokenSupplyAfter, ethAmount, "LP total supply should match the deposited ETH amount");
        assertEq(lpTokensMinted, userLPTokenBalanceAfter, "LP tokens should be minted for the USER");
        // Assert Reserves are updated correctly
        assertEq(ethReserveAfter, ethAmount, "Eth reserves should be updated");
        assertEq(tokenReserveAfter, tokenAmount, "Token reserves should be updated");
    }

    function testAddLiquidity() public withLiquidity {
        // Initial states
        uint256 ethReserveBefore = address(dexerExchange).balance;
        uint256 tokenReserveBefore = dexerExchange.getTokenReserveBalance();
        uint256 totalLPTokenSupplyBefore = dexerExchange.totalSupply();
        uint256 userLPTokenBalanceBefore = dexerExchange.balanceOf(USER);

        // Tokens to add
        uint256 ethAmount = 1 ether;
        uint256 tokenAmount = 10 ether;

        // Add liquidity
        vm.startPrank(USER);
        dexerToken.approve(address(dexerExchange), 10 ether);
        uint256 lpTokensMinted = dexerExchange.addLiquidity{value: ethAmount}({dexerTokenAmount: tokenAmount});
        vm.stopPrank();

        // Balances and reserves after adding liquidity
        uint256 ethReserveAfter = address(dexerExchange).balance;
        uint256 tokenReserveAfter = dexerExchange.getTokenReserveBalance();
        uint256 totalLPTokenSupplyAfter = dexerExchange.totalSupply();
        uint256 userLPTokenBalanceAfter = dexerExchange.balanceOf(USER);

        // Assert LP tokens are minted and transferred in the correct proportion
        assertEq(
            totalLPTokenSupplyAfter,
            (lpTokensMinted + totalLPTokenSupplyBefore),
            "LP total supply should be updated correctly"
        );
        assertEq(
            userLPTokenBalanceAfter,
            (lpTokensMinted + userLPTokenBalanceBefore),
            "LP tokens should be minted for the USER"
        );

        // Assert Reserves are updated correctly
        assertEq(ethReserveAfter, (ethAmount + ethReserveBefore), "Eth reserves should be updated");
        assertEq(tokenReserveAfter, (tokenAmount + tokenReserveBefore), "Token reserves should be updated");
    }

    function testAddLiquidityUpdatesContractReserves() public {
        uint256 ethAmount = 1 ether;
        uint256 tokenAmount = 10 ether;

        // Add liquidity
        vm.startPrank(USER);
        dexerExchange.addLiquidity{value: ethAmount}({dexerTokenAmount: tokenAmount});
        vm.stopPrank();

        // Assert ETH and token balances of the exchange contract
        assertEq(address(dexerExchange).balance, ethAmount);
        assertEq(dexerExchange.getTokenReserveBalance(), tokenAmount);
    }

    function testAddLiquidityMintsCorrectAmountOfLPToken() public {
        uint256 ethAmount = 1 ether;
        uint256 tokenAmount = 10 ether;

        vm.startPrank(USER);
        dexerExchange.addLiquidity{value: ethAmount}({dexerTokenAmount: tokenAmount});
        vm.stopPrank();

        // Assert total supply of LP tokens and that the USER received the LP tokens
        assertEq(ethAmount, dexerExchange.totalSupply());
        assertEq(ethAmount, dexerExchange.balanceOf(USER));
    }

    function testAddInitialLiquidityRevertsForInsufficientETH() public {
        uint256 ethAmount = 0.0001 ether; // Required >0.001 ether
        uint256 tokenAmount = 10 ether;

        vm.startPrank(USER);
        vm.expectRevert();
        dexerExchange.addLiquidity{value: ethAmount}({dexerTokenAmount: tokenAmount});
        vm.stopPrank();
    }

    function testAddInitialLiquidityRevertsForInsufficientToken() public {
        uint256 ethAmount = 1 ether;
        uint256 tokenAmount = 0.0001 ether; // Required >0.001 ether

        vm.startPrank(USER);
        vm.expectRevert();
        dexerExchange.addLiquidity{value: ethAmount}({dexerTokenAmount: tokenAmount});
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                             REMOVE LIQUIDITY
    //////////////////////////////////////////////////////////////*/

    function testRemoveLiquidity() public withLiquidity {
        // Initial states
        uint256 ethReserveBefore = address(dexerExchange).balance;
        uint256 tokenReserveBefore = dexerExchange.getTokenReserveBalance();
        uint256 totalLPTokenSupplyBefore = dexerExchange.totalSupply();
        uint256 userLPTokenBalanceBefore = dexerExchange.balanceOf(USER);

        // Amount of LP tokens to remove (50% of USER's balance)
        uint256 amountOfLPTokensToReturn = userLPTokenBalanceBefore / 2;

        // Remove liquidity
        vm.startPrank(USER);
        (uint256 ethReturned, uint256 tokensReturned) =
            dexerExchange.removeLiquidity({amountOfLPTokens: amountOfLPTokensToReturn});
        vm.stopPrank();

        // Balances and reserves after liquidity removal
        uint256 ethReserveAfter = address(dexerExchange).balance;
        uint256 tokenReserveAfter = dexerExchange.getTokenReserveBalance();
        uint256 totalLPTokenSupplyAfter = dexerExchange.totalSupply();
        uint256 userLPTokenBalanceAfter = dexerExchange.balanceOf(USER);

        // Asert LP tokens are transferred from USER
        assertEq(
            userLPTokenBalanceAfter,
            userLPTokenBalanceBefore - amountOfLPTokensToReturn,
            "USER's LP balance should decrease"
        );

        // Assert LP tokens are burnt
        assertEq(
            totalLPTokenSupplyAfter,
            totalLPTokenSupplyBefore - amountOfLPTokensToReturn,
            "Total LP token supply should decrease"
        );

        // Assert reservers have decreased proportionally
        assertEq(ethReserveAfter, ethReserveBefore - ethReturned, "Eth reserve should decrease proportionally");
        assertEq(tokenReserveAfter, tokenReserveBefore - tokensReturned, "Token reserve should decrease proportionally");

        // Assert returned amounts are proportional
        assertEq(
            ethReturned,
            (amountOfLPTokensToReturn * ethReserveBefore) / totalLPTokenSupplyBefore,
            "Returned ETH should be proportional"
        );

        assertEq(
            tokensReturned,
            (amountOfLPTokensToReturn * tokenReserveBefore) / totalLPTokenSupplyBefore,
            "Returned tokens should be proportional"
        );
    }

    function testRemoveLiquidityReducesReservesProportionally() public withLiquidity {
        // Initial states
        uint256 ethReserveBefore = address(dexerExchange).balance;
        uint256 tokenReserveBefore = dexerExchange.getTokenReserveBalance();
        uint256 userLPTokenBalanceBefore = dexerExchange.balanceOf(USER);

        // Amount of LP tokens to remove (50% of USER's balance)
        uint256 amountOfLPTokensToReturn = userLPTokenBalanceBefore / 2;

        // Remove liquidity
        vm.startPrank(USER);
        (uint256 ethReturned, uint256 tokensReturned) =
            dexerExchange.removeLiquidity({amountOfLPTokens: amountOfLPTokensToReturn});
        vm.stopPrank();

        // Balances and reserves after liquidity removal
        uint256 ethReserveAfter = address(dexerExchange).balance;
        uint256 tokenReserveAfter = dexerExchange.getTokenReserveBalance();

        // Assert reservers have decreased proportionally
        assertEq(ethReserveAfter, ethReserveBefore - ethReturned, "Eth reserve should decrease proportionally");
        assertEq(tokenReserveAfter, tokenReserveBefore - tokensReturned, "Token reserve should decrease proportionally");
    }

    function testRemoveLiquidityBurnsLPToken() public withLiquidity {
        // Initial balances
        uint256 userLPTokenBalanceBefore = dexerExchange.balanceOf(USER);
        uint256 totalLPTokenSupplyBefore = dexerExchange.totalSupply();

        uint256 amountOfLPTokensToReturn = userLPTokenBalanceBefore / 2; // 50% of total supply and users balance

        // remove liquidity
        vm.startPrank(USER);
        dexerExchange.removeLiquidity({amountOfLPTokens: amountOfLPTokensToReturn});
        vm.stopPrank();

        // Balances after liquidity removed
        uint256 totalLPTokenSupplyAfter = dexerExchange.totalSupply();
        uint256 userLPTokenBalanceAfter = dexerExchange.balanceOf(USER);

        // Assert that the LP tokens were transferred from the USER
        assertEq(
            userLPTokenBalanceAfter,
            (userLPTokenBalanceBefore - amountOfLPTokensToReturn),
            "USER's LP token balance should decrease"
        );

        // Assert that the LP tokens were burnt
        assertEq(
            totalLPTokenSupplyAfter,
            (totalLPTokenSupplyBefore - amountOfLPTokensToReturn),
            "Total LP token supply should decrease"
        );
    }

    function testRemoveLiquidityReturnsCorrectEthAndToken() public withLiquidity {
        uint256 ethReserveBefore = address(dexerExchange).balance;
        uint256 tokenReserveBefore = dexerExchange.getTokenReserveBalance();
        uint256 totalLPTokenSupplyBefore = dexerExchange.totalSupply();
        uint256 userLPTokenBalanceBefore = dexerExchange.balanceOf(USER);

        uint256 amountOfLPTokensToReturn = userLPTokenBalanceBefore / 2; // 50% of total supply and users balance

        // Remove liquidity
        vm.startPrank(USER);
        (uint256 ethReturned, uint256 tokenReturned) =
            dexerExchange.removeLiquidity({amountOfLPTokens: amountOfLPTokensToReturn});
        vm.stopPrank();

        // Expected ETH and tokens to be returned
        uint256 expectedEthReturned = (amountOfLPTokensToReturn * ethReserveBefore) / totalLPTokenSupplyBefore;
        uint256 expectedTokenReturned = (amountOfLPTokensToReturn * tokenReserveBefore) / totalLPTokenSupplyBefore;

        // Assert ETH and tokens returned were as expected
        assertEq(ethReturned, expectedEthReturned, "Returned ETH should be proportional");
        assertEq(tokenReturned, expectedTokenReturned, "Returned token should be proportional");
    }

    function testRemoveLiquidityRevertsIfAmountIsZero() public withLiquidity {
        vm.startPrank(USER);
        vm.expectRevert();
        dexerExchange.removeLiquidity({amountOfLPTokens: 0});
        vm.stopPrank();
    }

    function testRemoveLiquidityRevertsIfAmountExceedsUserBalance() public withLiquidity {
        uint256 userLPTokenBalance = dexerExchange.balanceOf(USER);

        vm.startPrank(USER);
        vm.expectRevert();
        dexerExchange.removeLiquidity({amountOfLPTokens: userLPTokenBalance + 1});
        vm.stopPrank();
    }

    function testRemoveLiquiditySmallAmount() public withLiquidity {
        uint256 ethReserveBefore = address(dexerExchange).balance;
        uint256 tokenReserveBefore = dexerExchange.getTokenReserveBalance();
        uint256 totalLPTokenSupplyBefore = dexerExchange.totalSupply();

        uint256 amountOfLPTokensToReturn = 1; // Very small amount 1 = 0.000000000000000001 (1e-18 in human-readable form)

        // Remove liquidity
        vm.startPrank(USER);
        (uint256 ethReturned, uint256 tokenReturned) =
            dexerExchange.removeLiquidity({amountOfLPTokens: amountOfLPTokensToReturn});
        vm.stopPrank();

        // Expected ETH and tokens to be returned
        uint256 expectedEthReturned = (amountOfLPTokensToReturn * ethReserveBefore) / totalLPTokenSupplyBefore;
        uint256 expectedTokenReturned = (amountOfLPTokensToReturn * tokenReserveBefore) / totalLPTokenSupplyBefore;

        // Assert ETH and tokens returned were as expected
        assertEq(ethReturned, expectedEthReturned, "Returned ETH should be proportional");
        assertEq(tokenReturned, expectedTokenReturned, "Returned token should be proportional");
    }

    function testRemoveLiquidityDepletesReserves() public {
        uint256 ethAmount = 1 ether;
        uint256 tokenAmount = 10 ether;
        // Add liquidity as USER
        vm.startPrank(USER);
        dexerExchange.addLiquidity{value: ethAmount}({dexerTokenAmount: tokenAmount});
        vm.stopPrank();

        uint256 totalLPTokenSupplyBefore = dexerExchange.totalSupply(); // All liquidity

        // Remove liquidity
        vm.startPrank(USER);
        dexerExchange.removeLiquidity({amountOfLPTokens: totalLPTokenSupplyBefore});
        vm.stopPrank();

        uint256 ethReserveAfter = address(dexerExchange).balance;
        uint256 tokenReserveAfter = dexerExchange.getTokenReserveBalance();

        // Expect reserves to be empty after removing all liquidity
        assertEq(ethReserveAfter, 0, "ETH reserve should be empty");
        assertEq(tokenReserveAfter, 0, "Token reserve should be empty");
    }

    /*//////////////////////////////////////////////////////////////
                             SWAP ETH -> TOKEN
    //////////////////////////////////////////////////////////////*/
    function testEthToDexerTokenSwap() public withLiquidity {
        // States before
        uint256 tokenReserveBefore = dexerExchange.getTokenReserveBalance();
        uint256 ethReserveBefore = address(dexerExchange).balance;
        uint256 userEthBalanceBefore = USER.balance;
        uint256 userTokenBalanceBefore = dexerToken.balanceOf(USER);

        uint256 ethAmount = 1 ether; // Amount of eth to swap
        uint256 expectedTokensAmount = dexerExchange.getOutputAmountFromSwap({
            inputAmount: ethAmount,
            inputReserve: ethReserveBefore,
            outputReserve: tokenReserveBefore
        });

        // Make the swap
        vm.startPrank(USER);
        dexerExchange.ethToDexerTokenSwap{value: ethAmount}({minTokensToReceive: expectedTokensAmount});
        vm.stopPrank();

        // States after swap
        uint256 tokenReserveAfter = dexerExchange.getTokenReserveBalance();
        uint256 ethReserveAfter = address(dexerExchange).balance;
        uint256 userEthBalanceAfter = USER.balance;
        uint256 userTokenBalanceAfter = dexerToken.balanceOf(USER);

        // Assert reserves
        assertEq(ethReserveAfter, (ethReserveBefore + ethAmount), "ETH reserve should update");
        require(tokenReserveAfter >= (tokenReserveBefore - expectedTokensAmount), "Token reserve should update");

        // User balances
        assertEq(userEthBalanceAfter, (userEthBalanceBefore - ethAmount), "USER ETH balance should update");
        require(
            userTokenBalanceAfter >= (userTokenBalanceBefore + expectedTokensAmount), "USER token balance should update"
        );
    }

    function testEthToTokenSwapRevertsForInsufficientETHSent() public withLiquidity {
        uint256 ethAmount = 0; // Amount of eth to swap. Required: 0.001 ether
        uint256 minTokensToReceive = 0;
        // Make the swap
        vm.startPrank(USER);
        vm.expectRevert();
        dexerExchange.ethToDexerTokenSwap{value: ethAmount}({minTokensToReceive: minTokensToReceive});
        vm.stopPrank();
    }

    function testEthToTokenSwapRevertsIfBelowMinTokens() public withLiquidity {
        uint256 ethAmount = 1 ether;
        uint256 minTokensToReceive = 20 ether; // Very high number

        // Make the swap
        vm.startPrank(USER);
        vm.expectRevert();
        dexerExchange.ethToDexerTokenSwap{value: ethAmount}({minTokensToReceive: minTokensToReceive});
        vm.stopPrank();
    }

    function testEthToDexerTokenSwapPreservesConstantProduct() public withLiquidity {
        uint256 ethAmount = 80 ether;
        uint256 minTokensToReceive = 0;
        uint256 tokenReserveBefore = dexerExchange.getTokenReserveBalance();
        uint256 ethReserveBefore = address(dexerExchange).balance;

        uint256 kBefore = ethReserveBefore * tokenReserveBefore;

        // Make the swap
        vm.startPrank(USER);
        dexerExchange.ethToDexerTokenSwap{value: ethAmount}({minTokensToReceive: minTokensToReceive});
        vm.stopPrank();

        // States after
        uint256 tokenReserveAfter = dexerExchange.getTokenReserveBalance();
        uint256 ethReserveAfter = address(dexerExchange).balance;

        uint256 kAfter = tokenReserveAfter * ethReserveAfter;

        assertApproxEqRel(kBefore, kAfter, 1e16, "K should remain approximately constant");
    }

    function testEthToDexerTokenSwapRevertsIfZeroTokenReserve() public {
        uint256 ethAmount = 1 ether;
        uint256 minTokensToReceive = 0;

        // Make the swap
        vm.startPrank(USER);
        vm.expectRevert();
        dexerExchange.ethToDexerTokenSwap{value: ethAmount}({minTokensToReceive: minTokensToReceive});
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                             SWAP ETH -> TOKEN
    //////////////////////////////////////////////////////////////*/
    function testDexerTokenToEthSwap() public withLiquidity {
        // States before
        uint256 tokenReserveBefore = dexerExchange.getTokenReserveBalance();
        uint256 ethReserveBefore = address(dexerExchange).balance;
        uint256 userEthBalanceBefore = USER.balance;
        uint256 userTokenBalanceBefore = dexerToken.balanceOf(USER);

        uint256 tokenAmount = 1 ether; // Amount of eth to swap
        uint256 expectedEthAmount = dexerExchange.getOutputAmountFromSwap({
            inputAmount: tokenAmount,
            inputReserve: tokenReserveBefore,
            outputReserve: ethReserveBefore
        });

        // Make the swap
        vm.startPrank(USER);
        dexerToken.approve(address(dexerExchange), 10 ether);
        dexerExchange.dexerTokenToEthSwap({tokensToSwap: tokenAmount, minEthToReceive: expectedEthAmount});
        vm.stopPrank();

        // States after swap
        uint256 tokenReserveAfter = dexerExchange.getTokenReserveBalance();
        uint256 ethReserveAfter = address(dexerExchange).balance;
        uint256 userEthBalanceAfter = USER.balance;
        uint256 userTokenBalanceAfter = dexerToken.balanceOf(USER);

        // Assert reserves
        assertEq(ethReserveAfter, (ethReserveBefore - expectedEthAmount), "ETH reserve should update");
        require(tokenReserveAfter >= (tokenReserveBefore + tokenAmount), "Token reserve should update");

        // User balances
        assertEq(userEthBalanceAfter, (userEthBalanceBefore + expectedEthAmount), "USER ETH balance should update");
        require(userTokenBalanceAfter >= (userTokenBalanceBefore - tokenAmount), "USER token balance should update");
    }

    function testTokenToEthSwapRevertsForInsufficientDXRSent() public withLiquidity {
        uint256 tokenAmount = 0; // Amount of eth to swap. Required: 0.001 ether
        uint256 minEthToReceive = 0;
        // Make the swap
        vm.startPrank(USER);
        vm.expectRevert();
        dexerExchange.dexerTokenToEthSwap({tokensToSwap: tokenAmount, minEthToReceive: minEthToReceive});
        vm.stopPrank();
    }

    function testTokenToEthSwapRevertsIfBelowMinTokens() public withLiquidity {
        uint256 tokenAmount = 1;
        uint256 minEthToReceive = 20 ether; // Very high amount

        // Make the swap
        vm.startPrank(USER);
        dexerToken.approve(address(dexerExchange), 10 ether);
        vm.expectRevert();
        dexerExchange.dexerTokenToEthSwap({tokensToSwap: tokenAmount, minEthToReceive: minEthToReceive});
        vm.stopPrank();
    }

    function testTokenToEthSwapPreservesConstantProduct() public withLiquidity {
        uint256 tokenAmount = 10 ether;
        uint256 minEthToReceive = 0;
        uint256 tokenReserveBefore = dexerExchange.getTokenReserveBalance();
        uint256 ethReserveBefore = address(dexerExchange).balance;

        uint256 kBefore = ethReserveBefore * tokenReserveBefore;

        // Make the swap
        vm.startPrank(USER);
        dexerToken.approve(address(dexerExchange), 10 ether);
        dexerExchange.dexerTokenToEthSwap({tokensToSwap: tokenAmount, minEthToReceive: minEthToReceive});
        vm.stopPrank();

        // States after
        uint256 tokenReserveAfter = dexerExchange.getTokenReserveBalance();
        uint256 ethReserveAfter = address(dexerExchange).balance;

        uint256 kAfter = tokenReserveAfter * ethReserveAfter;

        assertApproxEqRel(kBefore, kAfter, 1e16, "K should remain approximately constant");
    }

    function testTokenToEthSwapRevertsIfZeroTokenReserve() public {
        uint256 tokenAmount = 10 ether;
        uint256 minEthToReceive = 0;

        // Make the swap
        vm.startPrank(USER);
        dexerToken.approve(address(dexerExchange), 10 ether);
        vm.expectRevert();
        dexerExchange.dexerTokenToEthSwap({tokensToSwap: tokenAmount, minEthToReceive: minEthToReceive});
        vm.stopPrank();
    }
}
