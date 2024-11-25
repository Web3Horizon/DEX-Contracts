// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DexerExchange} from "src/DexerExchange.sol";
import {DexerToken} from "src/DexerToken.sol";

import {Script} from "forge-std/Script.sol";

contract DeployDexerExchange is Script {
    uint256 public constant INITIAL_SUPPLY = 1000e18;

    function run() external returns (DexerExchange, DexerToken) {
        vm.startBroadcast();
        DexerToken dexerToken = new DexerToken(INITIAL_SUPPLY);
        address dexerTokenAddress = address(dexerToken);
        DexerExchange dexerExchange = new DexerExchange(dexerTokenAddress);
        vm.stopBroadcast();

        return (dexerExchange, dexerToken);
    }
}
