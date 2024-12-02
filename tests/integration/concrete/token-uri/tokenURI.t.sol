// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC721Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import { Shared_Integration_Concrete_Test } from "../Concrete.t.sol";

contract TokenURI_Integration_Concrete_Test is Shared_Integration_Concrete_Test {
    function test_RevertGiven_NFTNotExist() external {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, nullStreamId));
        flow.tokenURI({ streamId: nullStreamId });
    }

    function test_GivenNFTExists() external view {
        // It should return the correct token URI
        string memory actualURI = flow.tokenURI({ streamId: defaultStreamId });
        // solhint-disable max-line-length,quotes
        string memory expectedURI =
            "data:application/json;base64,eyJkZXNjcmlwdGlvbiI6ICJUaGlzIE5GVCByZXByZXNlbnRzIGEgcGF5bWVudCBzdHJlYW0gaW4gU2FibGllciBGbG93IiwiZXh0ZXJuYWxfdXJsIjogImh0dHBzOi8vc2FibGllci5jb20iLCJuYW1lIjogIlNhYmxpZXIgRmxvdyIsImltYWdlIjogImRhdGE6aW1hZ2Uvc3ZnK3htbDtiYXNlNjQsUEhOMlp5QjNhV1IwYUQwaU5UQXdJaUJvWldsbmFIUTlJalV3TUNJZ2MzUjViR1U5SW1KaFkydG5jbTkxYm1RdFkyOXNiM0k2SUNNeE5ERTJNVVk3SWlCNGJXeHVjejBpYUhSMGNEb3ZMM2QzZHk1M015NXZjbWN2TWpBd01DOXpkbWNpSUhacFpYZENiM2c5SWpJd0lDMDBNREFnTWpBd0lERXdNREFpUGp4d1lYUm9JR2xrUFNKTWIyZHZJaUJtYVd4c1BTSWpabVptSWlCbWFXeHNMVzl3WVdOcGRIazlJakVpSUdROUltMHhNek11TlRVNUxERXlOQzR3TXpSakxTNHdNVE1zTWk0ME1USXRNUzR3TlRrc05DNDRORGd0TWk0NU1qTXNOaTQwTURJdE1pNDFOVGdzTVM0NE1Ua3ROUzR4Tmpnc015NDBNemt0Tnk0NE9EZ3NOQzQ1T1RZdE1UUXVORFFzT0M0eU5qSXRNekV1TURRM0xERXlMalUyTlMwME55NDJOelFzTVRJdU5UWTVMVGd1T0RVNExqQXpOaTB4Tnk0NE16Z3RNUzR5TnpJdE1qWXVNekk0TFRNdU5qWXpMVGt1T0RBMkxUSXVOelkyTFRFNUxqQTROeTAzTGpFeE15MHlOeTQxTmpJdE1USXVOemM0TFRFekxqZzBNaTA0TGpBeU5TdzVMalEyT0MweU9DNDJNRFlzTVRZdU1UVXpMVE0xTGpJMk5XZ3dZekl1TURNMUxURXVPRE00TERRdU1qVXlMVE11TlRRMkxEWXVORFl6TFRVdU1qSTBhREJqTmk0ME1qa3ROUzQyTlRVc01UWXVNakU0TFRJdU9ETTFMREl3TGpNMU9DdzBMakUzTERRdU1UUXpMRFV1TURVM0xEZ3VPREUyTERrdU5qUTVMREV6TGpreUxERXpMamN6TkdndU1ETTNZelV1TnpNMkxEWXVORFl4TERFMUxqTTFOeTB5TGpJMU15dzVMak00TFRndU5EZ3NNQ3d3TFRNdU5URTFMVE11TlRFMUxUTXVOVEUxTFRNdU5URTFMVEV4TGpRNUxURXhMalEzT0MwMU1pNDJOVFl0TlRJdU5qWTBMVFkwTGpnek55MDJOQzQ0TXpkc0xqQTBPUzB1TURNM1l5MHhMamN5TlMweExqWXdOaTB5TGpjeE9TMHpMamcwTnkweUxqYzFNUzAyTGpJd05HZ3dZeTB1TURRMkxUSXVNemMxTERFdU1EWXlMVFF1TlRneUxESXVOekkyTFRZdU1qSTVhREJzTGpFNE5TMHVNVFE0YURCakxqQTVPUzB1TURZeUxDNHlNakl0TGpFME9Dd3VNemN0TGpJMU9XZ3dZekl1TURZdE1TNHpOaklzTXk0NU5URXRNaTQyTWpFc05pNHdORFF0TXk0NE5ESkROVGN1TnpZekxUTXVORGN6TERrM0xqYzJMVEl1TXpReExERXlPQzQyTXpjc01UZ3VNek15WXpFMkxqWTNNU3c1TGprME5pMHlOaTR6TkRRc05UUXVPREV6TFRNNExqWTFNU3cwTUM0eE9Ua3ROaTR5T1RrdE5pNHdPVFl0TVRndU1EWXpMVEUzTGpjME15MHhPUzQyTmpndE1UZ3VPREV4TFRZdU1ERTJMVFF1TURRM0xURXpMakEyTVN3MExqYzNOaTAzTGpjMU1pdzVMamMxTVd3Mk9DNHlOVFFzTmpndU16Y3hZekV1TnpJMExERXVOakF4TERJdU56RTBMRE11T0RRc01pNDNNemdzTmk0eE9USmFJaUIwY21GdWMyWnZjbTA5SW5OallXeGxLREV1TlN3Z01TNDFLU0lnTHo0OEwzTjJaejQ9In0=";
        assertEq(actualURI, expectedURI, "tokenURI");
    }
}
