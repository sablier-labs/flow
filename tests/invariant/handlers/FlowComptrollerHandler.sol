// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ISablierFlow } from "src/interfaces/ISablierFlow.sol";
import { FlowStore } from "./../stores/FlowStore.sol";
import { BaseHandler } from "./BaseHandler.sol";

contract FlowComptrollerHandler is BaseHandler {
    IERC20 internal currentToken;

    /*//////////////////////////////////////////////////////////////////////////
                                     MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Since all comptroller-related functions are rarely called compared to core flow functionalities,
    /// we limit the number of calls to 10.
    modifier limitNumberOfCalls(string memory name) {
        vm.assume(totalCalls[name] < 10);
        _;
    }

    modifier useFuzzedToken(uint256 tokenIndex) {
        IERC20[] memory tokens = flowStore.getTokens();
        vm.assume(tokenIndex < tokens.length);
        currentToken = tokens[tokenIndex];
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(FlowStore flowStore_, ISablierFlow flow_) BaseHandler(flowStore_, flow_) { }

    /*//////////////////////////////////////////////////////////////////////////
                                 SABLIER-FLOW-STATE
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Function to increase the flow contract balance for the fuzzed token.
    function randomTransfer(uint256 tokenIndex, uint256 amount) external useFuzzedToken(tokenIndex) {
        vm.assume(amount > 0 && amount < 100e18);
        amount *= 10 ** IERC20Metadata(address(currentToken)).decimals();

        deal({ token: address(currentToken), to: address(flow), give: currentToken.balanceOf(address(flow)) + amount });
    }

    function recover(uint256 tokenIndex)
        external
        limitNumberOfCalls("recover")
        instrument(0, "recover")
        useFuzzedToken(tokenIndex)
    {
        vm.assume(currentToken.balanceOf(address(flow)) > flow.aggregateAmount(currentToken));

        setMsgSender(address(flow.comptroller()));

        flow.recover(currentToken, address(comptroller));
    }
}
