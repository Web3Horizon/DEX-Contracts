// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
/*
  Contract elements should be laid out in the following order:

    Pragma statements

    Import statements

    Events

    Errors

    Interfaces

    Libraries

    Contracts

Inside each contract, library or interface, use the following order:

    Type declarations

    State variables

    Events

    Errors

    Modifiers

    Functions
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DexerExchange is ERC20 {
    /* ****Type declarations**** */

    /* State variables */
    address public immutable i_owner;
    address public dexerTokenAddress;

    /* ****Events**** */

    /* ****Errors**** */

    /* ****Modifiers**** */

    // Functions
    constructor(address _dexerTokenAddress) ERC20("Dexer LP Token", "DXRLP") {
        require(_dexerTokenAddress != address(0), "Token address passed is a null address");
        dexerTokenAddress = _dexerTokenAddress;
        // Set the owner
        i_owner = msg.sender;
    }

    /**
     * @dev Add Liquidity to the pool.
     * @param amount The amount of Dexer token to add as liquidity.
     * @return The amount of LP tokens minted.
     */
    function addLiquidity(uint256 amount) public payable returns (uint256) {
        uint256 lpTokensToMint;
        uint256 ethReserveBalance = address(this).balance;
        uint256 dexerTokenReserveBalance = getTokenReserveBalance();
        ERC20 dexerToken = ERC20(dexerTokenAddress);

        /* If the reserve is empty we can take any token amount because there is no ratio */

        if (dexerTokenReserveBalance == 0) {
            // Tranfer tokens from user to contract
            dexerToken.transferFrom(msg.sender, address(this), amount);
            // lpTokensToMint is the eth balance here because this is the first time user is adding liquidity to the contract
            lpTokensToMint = ethReserveBalance;
            // Mint LP tokens to the user
            _mint(msg.sender, lpTokensToMint);
        } else {
            /* If the reserve is not empty, calculate the amount of LP tokens to be minted */
            uint256 ethReserveBalancePriorToFunctionCall = ethReserveBalance - msg.value;
            uint256 dexerTokenAmountRequired =
                (msg.value * dexerTokenReserveBalance) / (ethReserveBalancePriorToFunctionCall);

            // Check if the user has sent enough dexerToken
            require(amount >= dexerTokenAmountRequired, "Insufficient amount of tokens provided");

            // Transfer tokens from user to contract
            dexerToken.transferFrom(msg.sender, address(this), dexerTokenAmountRequired);

            /*
            The amount of LP tokens sent to the user should be propotional to the ether added by the user
            Ratio => (LP Tokens to be sent to the user (liquidity) / total supply of LP tokens in the contract) = (ETH sent by the user) / (ETH reserve in the contract)
            liquidity = (total supply of LP tokens in contract * (ETH sent by the user)) / (ETH reserve in the contract)
          */

            lpTokensToMint = (totalSupply() * msg.value) / ethReserveBalancePriorToFunctionCall; // totalSupply() is provided by ERC20
            _mint(msg.sender, lpTokensToMint);
        }
        return lpTokensToMint;
    }

    /**
     * @dev Remove liquidity from the pool.
     * @param amountOfLPTokens The amount of LP tokens to burn.
     * @return The amount of ETH and Dexer tokens returned to the user.
     */
    function removeLiquidity(uint256 amountOfLPTokens) public returns (uint256, uint256) {
        // Check that the user wants to remove >0 LP tokens
        require(amountOfLPTokens > 0, "Insufficient amount of LP tokens provided");

        uint256 ethReserveBalance = address(this).balance;
        uint256 lpTokenTotalSupply = totalSupply(); // totalSupply() is provided by ERC20

        // Calculate how much tokens to return to the user from the LP
        uint256 ethToReturn = (ethReserveBalance * amountOfLPTokens) / lpTokenTotalSupply;
        uint256 dexerTokenToReturn = (getTokenReserveBalance() * amountOfLPTokens) / lpTokenTotalSupply;

        // Burn the LP tokens provided from the user
        _burn(msg.sender, amountOfLPTokens);

        // Return tokens to the user
        payable(msg.sender).transfer(ethToReturn); // Eth
        ERC20(dexerTokenAddress).transfer(msg.sender, dexerTokenToReturn); // dexerToken

        return (ethToReturn, dexerTokenToReturn);
    }

    /**
     * @dev Swap ETH for Dexer tokens.
     * @param minTokensToReceive The minimum amount of Dexer tokens expected to be received from the swap.
     */
    function ethToDexerTokenSwap(uint256 minTokensToReceive) public payable {
        uint256 tokenReserveBalance = getTokenReserveBalance();
        uint256 tokensToReceive = getOutputAmountFromSwap({
            inputAmount: msg.value,
            inputReserve: address(this).balance - msg.value,
            outputReserve: tokenReserveBalance
        });

        require(tokensToReceive >= minTokensToReceive, "Tokens received are less than minimum expected");

        ERC20(dexerTokenAddress).transfer(msg.sender, tokensToReceive);
    }

    /**
     * @dev Swap Dexer tokens for ETH.
     * @param tokensToSwap The amount of Dexer tokens provided for the swap.
     * @param minEthToReceive The minimum amount of ETH expected to be received from the swap.
     */
    function dexerTokenToEthSwap(uint256 tokensToSwap, uint256 minEthToReceive) public {
        uint256 tokenReserveBalance = getTokenReserveBalance();
        uint256 ethToReceive = getOutputAmountFromSwap({
            inputAmount: tokensToSwap,
            inputReserve: tokenReserveBalance,
            outputReserve: address(this).balance
        });

        require(ethToReceive >= minEthToReceive, "ETH received is less than minimum expected");

        ERC20(dexerTokenAddress).transferFrom(msg.sender, address(this), tokensToSwap);

        payable(msg.sender).transfer(ethToReceive);
    }

    /**
     * @dev Calculates the amount of output tokens the user will receive for a given input amount,
     *      based on the constant product formula: (x + Δx) * (y - Δy) = k
     *      Therefore our formula is: (x + Δx) * (y - Δy) = x * y
     *      Final formula: Δy = (y * Δx) / (x + Δx)
     *      A 1% fee is applied to the input amount.
     * @param inputAmount The amount of input tokens the user wants to swap.
     * @param inputReserve The current reserve of the input token in the liquidity pool.
     * @param outputReserve The current reserve of the output token in the liquidity pool.
     * @return The amount of output tokens the user will receive.
     */
    function getOutputAmountFromSwap(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve)
        public
        pure
        returns (uint256)
    {
        require(inputReserve > 0 && outputReserve > 0, "Reserves must be greater than 0");

        // Charging a 1% fee so we mulitple by 99 here, later we divide by 100
        uint256 inputAmountWithFee = inputAmount * 99;

        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 100) + inputAmountWithFee;

        return numerator / denominator;
    }

    /* ****Getters**** */

    /**
     * @dev Get the Dexer token reserve balance.
     * @return The Dexer token balance in the pool.
     */
    function getTokenReserveBalance() public view returns (uint256) {
        return ERC20(dexerTokenAddress).balanceOf(address(this));
    }
}
