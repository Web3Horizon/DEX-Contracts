// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDexerExchange} from "script/DeployDexerExchange.s.sol";
import {DexerExchange} from "src/DexerExchange.sol";

contract DexerExchangeTest is Test {
    address USER = makeAddr("user");
    DexerExchange dexerExchange;

    function setup() external {
        DeployDexerExchange deployDexerExchange = new DeployDexerExchange();

        (dexerExchange,) = deployDexerExchange.run();

        vm.deal(USER, STARTING_BALANCE);
    }
}
