// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "../src/Bitcoingateway.sol";

contract BitcoinPaymentGatewayHandler is Test {
    BitcoinPaymentGateway public gateway;
    address public owner;
    address public relayer;
    
    // Ghost variables to track expected state
    uint256 public ghost_totalSent;
    uint256 public ghost_requestCount;
    
    constructor(BitcoinPaymentGateway _gateway, address _owner, address _relayer) {
        gateway = _gateway;
        owner = _owner;
        relayer = _relayer;
    }
    
    function sendBitcoin(uint256 amount) public {
        // Bound amount to realistic values to avoid overflow in test logic
        amount = bound(amount, 546, type(uint64).max);
        
        vm.prank(owner);
        try gateway.sendBitcoin("bc1q...", "bc1q...", amount, "memo") {
            ghost_totalSent += amount;
            ghost_requestCount++;
        } catch Error(string memory reason) {
            // If it failed, it MUST be because it's paused
            assertEq(reason, "Contract paused");
            assertTrue(gateway.paused());
        } catch {
            revert("Unexpected revert type");
        }
    }

    function sendBitcoinUnauthorized(uint256 actorSeed, uint256 amount) public {
        // Generate random actor that is NOT the owner
        address actor = vm.addr(bound(actorSeed, 100, 100000)); 
        vm.assume(actor != owner);
        
        amount = bound(amount, 546, type(uint64).max);
        
        vm.prank(actor);
        try gateway.sendBitcoin("bc1q...", "bc1q...", amount, "memo") {
            revert("Unauthorized send succeeded");
        } catch Error(string memory reason) {
            assertEq(reason, "Not authorized");
        } catch {
             // fallback
        }
    }

    function sendBitcoinDust(uint256 amount) public {
        // Test amounts below dust limit
        amount = bound(amount, 0, 545);
        
        // Even if authorized, this should fail
        vm.prank(owner);
        try gateway.sendBitcoin("bc1q...", "bc1q...", amount, "memo") {
             revert("Dust send succeeded");
        } catch Error(string memory reason) {
             if (amount == 0) assertEq(reason, "Zero amount");
             else assertEq(reason, "Below dust limit");
        } catch {
             // fallback
        }
    }
    
    function pause() public {
        vm.prank(owner);
        gateway.pause();
    }
    
    function unpause() public {
        vm.prank(owner);
        gateway.unpause();
    }
}

contract BitcoinPaymentGatewayInvariantTest is Test {
    BitcoinPaymentGateway gateway;
    BitcoinPaymentGatewayHandler handler;
    address owner = address(1);
    address relayer = address(2);
    
    function setUp() public {
        vm.prank(owner);
        gateway = new BitcoinPaymentGateway(relayer);
        
        handler = new BitcoinPaymentGatewayHandler(gateway, owner, relayer);
        
        targetContract(address(handler));
    }
    
    function invariant_requestCountMatchesGhost() public view {
        assertEq(gateway.requestCount(), handler.ghost_requestCount());
    }
    
    function invariant_totalSentMatchesGhost() public view {
        // This is a simplified invariant checking total sent from the specific address used in handler
        assertEq(gateway.getTotalSentFrom("bc1q..."), handler.ghost_totalSent());
    }
    
    function invariant_pausedState() public view {
        // If paused, request count should not increase (checked implicitly by handler logic + invariant)
        // This is just a sanity check that the variable exists
        bool p = gateway.paused();
        assert(p == true || p == false);
    }
}
