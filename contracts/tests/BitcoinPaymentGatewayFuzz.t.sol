// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/Bitcoingateway.sol";

contract BitcoinPaymentGatewayFuzzTest is Test {
    BitcoinPaymentGateway gateway;
    address owner = address(1);
    address relayer = address(2);
    
    string fromAddr = "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh";
    string toAddr = "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq";
    string memo = "Test payment";
    uint256 dustLimit = 546;

    function setUp() public {
        vm.prank(owner);
        gateway = new BitcoinPaymentGateway(relayer);
    }

    // 1. Fuzz Testing - Amount Tracking
    function testFuzz_AmountTracking(uint256 amount) public {
        // Test realistic Bitcoin amounts (up to 21M BTC)
        // 21,000,000 BTC * 100,000,000 sats/BTC = 2,100,000,000,000,000 sats
        uint256 maxSats = 21_000_000 * 100_000_000;
        vm.assume(amount >= dustLimit && amount <= maxSats);
        
        vm.prank(owner);
        gateway.sendBitcoin(fromAddr, toAddr, amount, memo);
        
        assertEq(gateway.getTotalSentFrom(fromAddr), amount);
        assertEq(gateway.getTotalReceivedBy(toAddr), amount);
    }

    function testFuzz_AmountTracking_Uint256Max(uint256 amount) public {
        // Test full uint256 range to ensure no overflow in tracking logic
        // We use type(uint256).max / 2 to allow for at least 2 transactions without overflow
        vm.assume(amount >= dustLimit && amount < type(uint256).max / 2);
        
        vm.prank(owner);
        gateway.sendBitcoin(fromAddr, toAddr, amount, memo);
        
        assertEq(gateway.getTotalSentFrom(fromAddr), amount);
    }

    // 2. Edge Case Signatures - Malformed Witness Data
    function testFuzz_FulfillPaymentInvalidProofLength(uint256 length) public {
        vm.assume(length != 64 && length < 1000); // Limit length to avoid OOG
        
        vm.prank(owner);
        uint256 requestId = gateway.sendBitcoin(fromAddr, toAddr, 1000, memo);
        
        bytes memory proof = new bytes(length);
        
        vm.prank(relayer);
        vm.expectRevert("Invalid proof length");
        gateway.fulfillPayment(requestId, keccak256("txid"), hex"02", proof);
    }

    function testFulfillPayment_ExplicitEdgeCases() public {
        vm.prank(owner);
        uint256 requestId = gateway.sendBitcoin(fromAddr, toAddr, 1000, memo);
        
        vm.startPrank(relayer);
        
        // 0 bytes
        vm.expectRevert("Invalid proof length");
        gateway.fulfillPayment(requestId, keccak256("txid"), hex"02", new bytes(0));

        // 63 bytes
        vm.expectRevert("Invalid proof length");
        gateway.fulfillPayment(requestId, keccak256("txid"), hex"02", new bytes(63));

        // 65 bytes
        vm.expectRevert("Invalid proof length");
        gateway.fulfillPayment(requestId, keccak256("txid"), hex"02", new bytes(65));

        // 129 bytes
        vm.expectRevert("Invalid proof length");
        gateway.fulfillPayment(requestId, keccak256("txid"), hex"02", new bytes(129));
        
        vm.stopPrank();
    }

    // 3. Griefing Attacks - Relayer Spam
    function testRelayerGriefing_MarkPaymentFailedLoop() public {
        // Create many requests - increased to 100 to stress gas
        uint256 numRequests = 100;
        for(uint256 i = 0; i < numRequests; i++) {
            vm.prank(owner);
            gateway.sendBitcoin(fromAddr, toAddr, 1000, memo);
        }
        
        // Relayer marks them all failed
        vm.startPrank(relayer);
        uint256 startGas = gasleft();
        for(uint256 i = 0; i < numRequests; i++) {
            gateway.markPaymentFailed(i, "Failed");
        }
        uint256 gasUsed = startGas - gasleft();
        vm.stopPrank();
        
        // Verify totals reverted
        assertEq(gateway.getTotalSentFrom(fromAddr), 0);
        
        // Log gas used per failure (approximate)
        console.log("Gas used for 100 failures:", gasUsed);
        console.log("Average gas per failure:", gasUsed / numRequests);
    }
    
    // 4. Time-based Scenarios - Timestamp check
    function testTimestampRecording() public {
        vm.warp(1600000000);
        
        vm.prank(owner);
        uint256 requestId = gateway.sendBitcoin(fromAddr, toAddr, 1000, memo);
        
        BitcoinPaymentGateway.PaymentRequest memory req = gateway.getPaymentRequest(requestId);
        assertEq(req.timestamp, 1600000000);
    }

    // 5. Concurrent Fulfillment Simulation
    function testConcurrentFulfillment() public {
        vm.prank(owner);
        uint256 requestId = gateway.sendBitcoin(fromAddr, toAddr, 1000, memo);
        
        bytes memory proof = abi.encodePacked(uint256(1), uint256(2)); // 64 bytes
        bytes32 txid = keccak256("txid");

        vm.startPrank(relayer);
        
        // First fulfillment succeeds
        gateway.fulfillPayment(requestId, txid, hex"02", proof);
        
        // Second fulfillment (simulating concurrent/race condition) fails
        vm.expectRevert("Already fulfilled");
        gateway.fulfillPayment(requestId, txid, hex"02", proof);
        
        vm.stopPrank();
    }

    // 6. Reorg / Double Fulfillment with Different TxID
    function testReorgDoubleFulfillment() public {
        vm.prank(owner);
        uint256 requestId = gateway.sendBitcoin(fromAddr, toAddr, 1000, memo);
        
        bytes memory proof = abi.encodePacked(uint256(1), uint256(2)); // 64 bytes
        bytes32 txid1 = keccak256("txid1");
        bytes32 txid2 = keccak256("txid2"); // Different txid due to reorg/malleability

        vm.startPrank(relayer);
        
        // First fulfillment succeeds
        gateway.fulfillPayment(requestId, txid1, hex"02", proof);
        
        // Second fulfillment with DIFFERENT txid fails
        vm.expectRevert("Already fulfilled");
        gateway.fulfillPayment(requestId, txid2, hex"02", proof);
        
        vm.stopPrank();
    }
}
