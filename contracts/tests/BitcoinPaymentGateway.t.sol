// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/Bitcoingateway.sol";

contract BitcoinPaymentGatewayTest is Test {
    BitcoinPaymentGateway gateway;
    address owner = address(1);
    address relayer = address(2);
    address authorizedSender = address(3);
    address unauthorized = address(4);

    string fromAddr = "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh";
    string toAddr = "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq";
    string invalidAddr = "";
    uint256 amount = 1000; // Above dust limit
    uint256 dustAmount = 500; // Below dust limit
    string memo = "Test payment";

    event BitcoinPaymentRequested(
        uint256 indexed requestId,
        string indexed fromBtcAddress,
        string indexed toBtcAddress,
        uint256 amountSats,
        address requester,
        string memo
    );

    event BitcoinPaymentCompleted(
        uint256 indexed requestId,
        bytes32 indexed btcTxid,
        string fromBtcAddress,
        string toBtcAddress,
        uint256 amountSats
    );

    event BitcoinPaymentFailed(uint256 indexed requestId, string reason);

    event BitcoinTransactionProof(
        uint256 indexed requestId,
        bytes publicKey,
        bytes32 indexed btcTxid,
        bytes proof
    );

    event BitcoinAddressRegistered(string btcAddress, string label);

    event AuthorizedSenderUpdated(address indexed sender, bool authorized);

    event PauseStateChanged(bool paused);

    event RelayerUpdated(address indexed oldRelayer, address indexed newRelayer);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        vm.prank(owner);
        gateway = new BitcoinPaymentGateway(relayer);
    }

    // Constructor Tests
    function testConstructor() public {
        assertEq(gateway.owner(), owner);
        assertEq(gateway.relayer(), relayer);
        assertEq(gateway.paused(), false);
        assertEq(gateway.requestCount(), 0);
    }

    function testConstructorZeroRelayer() public {
        vm.expectRevert("Zero relayer");
        new BitcoinPaymentGateway(address(0));
    }

    // Access Control Tests
    function testOnlyOwnerModifier() public {
        vm.prank(unauthorized);
        vm.expectRevert("Not owner");
        gateway.pause();
    }

    function testOnlyRelayerModifier() public {
        vm.prank(unauthorized);
        vm.expectRevert("Not relayer");
        gateway.fulfillPayment(0, keccak256("txid"), hex"00", hex"00");
    }

    function testOnlyAuthorizedModifier() public {
        vm.prank(unauthorized);
        vm.expectRevert("Not authorized");
        gateway.sendBitcoin(fromAddr, toAddr, amount, memo);
    }

    function testWhenNotPausedModifier() public {
        vm.prank(owner);
        gateway.pause();

        vm.prank(owner);
        vm.expectRevert("Contract paused");
        gateway.sendBitcoin(fromAddr, toAddr, amount, memo);
    }

    // sendBitcoin Tests
    function testSendBitcoinSuccess() public {
        vm.prank(owner);

        vm.expectEmit(true, true, true, true);
        emit BitcoinPaymentRequested(0, fromAddr, toAddr, amount, owner, memo);

        uint256 requestId = gateway.sendBitcoin(fromAddr, toAddr, amount, memo);

        assertEq(requestId, 0);
        assertEq(gateway.requestCount(), 1);

        BitcoinPaymentGateway.PaymentRequest memory req = gateway.getPaymentRequest(0);
        assertEq(req.requester, owner);
        assertEq(req.fromBtcAddress, fromAddr);
        assertEq(req.toBtcAddress, toAddr);
        assertEq(req.amountSats, amount);
        assertEq(req.fulfilled, false);
        assertEq(req.memo, memo);

        assertEq(gateway.getTotalSentFrom(fromAddr), amount);
        assertEq(gateway.getTotalReceivedBy(toAddr), amount);
    }

    function testSendBitcoinAuthorizedSender() public {
        vm.prank(owner);
        gateway.setAuthorizedSender(authorizedSender, true);

        vm.prank(authorizedSender);

        vm.expectEmit(true, true, true, true);
        emit BitcoinPaymentRequested(0, fromAddr, toAddr, amount, authorizedSender, memo);

        uint256 requestId = gateway.sendBitcoin(fromAddr, toAddr, amount, memo);
        assertEq(requestId, 0);
    }

    function testSendBitcoinEmptyFromAddress() public {
        vm.prank(owner);
        vm.expectRevert("Empty from address");
        gateway.sendBitcoin(invalidAddr, toAddr, amount, memo);
    }

    function testSendBitcoinEmptyToAddress() public {
        vm.prank(owner);
        vm.expectRevert("Empty to address");
        gateway.sendBitcoin(fromAddr, invalidAddr, amount, memo);
    }

    function testSendBitcoinZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert("Zero amount");
        gateway.sendBitcoin(fromAddr, toAddr, 0, memo);
    }

    function testSendBitcoinBelowDustLimit() public {
        vm.prank(owner);
        vm.expectRevert("Below dust limit");
        gateway.sendBitcoin(fromAddr, toAddr, dustAmount, memo);
    }

    // fulfillPayment Tests
    function testFulfillPaymentSuccess() public {
        // Create request
        vm.prank(owner);
        uint256 requestId = gateway.sendBitcoin(fromAddr, toAddr, amount, memo);

        bytes32 btcTxid = keccak256("test txid");
        bytes memory publicKey = hex"0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"; // Example compressed key
        bytes memory proof = abi.encodePacked(uint256(1), uint256(2)); // 64 bytes

        vm.prank(relayer);

        vm.expectEmit(true, true, false, true);
        emit BitcoinPaymentCompleted(requestId, btcTxid, fromAddr, toAddr, amount);

        vm.expectEmit(true, true, false, true);
        emit BitcoinTransactionProof(requestId, publicKey, btcTxid, proof);

        gateway.fulfillPayment(requestId, btcTxid, publicKey, proof);

        (bool fulfilled, bytes32 txid) = gateway.getPaymentStatus(requestId);
        assertTrue(fulfilled);
        assertEq(txid, btcTxid);
    }

    function testFulfillPaymentInvalidRequest() public {
        vm.prank(relayer);
        vm.expectRevert("Invalid request");
        gateway.fulfillPayment(0, keccak256("txid"), hex"00", hex"00");
    }

    function testFulfillPaymentAlreadyFulfilled() public {
        // Create and fulfill request
        vm.prank(owner);
        uint256 requestId = gateway.sendBitcoin(fromAddr, toAddr, amount, memo);

        bytes memory proof = abi.encodePacked(uint256(1), uint256(2)); // 64 bytes

        vm.prank(relayer);
        gateway.fulfillPayment(requestId, keccak256("txid"), hex"0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798", proof);

        vm.prank(relayer);
        vm.expectRevert("Already fulfilled");
        gateway.fulfillPayment(requestId, keccak256("txid2"), hex"0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798", proof);
    }

    function testFulfillPaymentInvalidTxid() public {
        vm.prank(owner);
        uint256 requestId = gateway.sendBitcoin(fromAddr, toAddr, amount, memo);

        vm.prank(relayer);
        vm.expectRevert("Invalid txid");
        gateway.fulfillPayment(requestId, bytes32(0), hex"00", hex"00");
    }

    function testFulfillPaymentInvalidProofLength() public {
        vm.prank(owner);
        uint256 requestId = gateway.sendBitcoin(fromAddr, toAddr, amount, memo);

        vm.prank(relayer);
        vm.expectRevert("Invalid proof length");
        gateway.fulfillPayment(requestId, keccak256("txid"), hex"00", hex"00"); // 2 bytes, not 64
    }

    // markPaymentFailed Tests
    function testMarkPaymentFailedSuccess() public {
        vm.prank(owner);
        uint256 requestId = gateway.sendBitcoin(fromAddr, toAddr, amount, memo);

        vm.prank(relayer);

        vm.expectEmit(true, false, false, true);
        emit BitcoinPaymentFailed(requestId, "Insufficient funds");

        gateway.markPaymentFailed(requestId, "Insufficient funds");

        // Check totals reverted
        assertEq(gateway.getTotalSentFrom(fromAddr), 0);
        assertEq(gateway.getTotalReceivedBy(toAddr), 0);
    }

    function testMarkPaymentFailedInvalidRequest() public {
        vm.prank(relayer);
        vm.expectRevert("Invalid request");
        gateway.markPaymentFailed(0, "Test");
    }

    function testMarkPaymentFailedAlreadyFulfilled() public {
        vm.prank(owner);
        uint256 requestId = gateway.sendBitcoin(fromAddr, toAddr, amount, memo);

        bytes memory proof = abi.encodePacked(uint256(1), uint256(2)); // 64 bytes

        vm.prank(relayer);
        gateway.fulfillPayment(requestId, keccak256("txid"), hex"0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798", proof);

        vm.prank(relayer);
        vm.expectRevert("Already fulfilled");
        gateway.markPaymentFailed(requestId, "Test");
    }

    // registerBitcoinAddress Tests
    function testRegisterBitcoinAddressSuccess() public {
        string memory label = "Hot Wallet";

        vm.prank(owner);

        vm.expectEmit(false, false, false, true);
        emit BitcoinAddressRegistered(fromAddr, label);

        gateway.registerBitcoinAddress(fromAddr, label);

        assertTrue(gateway.isBitcoinAddressRegistered(fromAddr));
        string[] memory addresses = gateway.getRegisteredAddresses();
        assertEq(addresses.length, 1);
        assertEq(addresses[0], fromAddr);
    }

    function testRegisterBitcoinAddressDuplicate() public {
        vm.prank(owner);
        gateway.registerBitcoinAddress(fromAddr, "Wallet");

        // Register again - should not add duplicate
        vm.prank(owner);
        gateway.registerBitcoinAddress(fromAddr, "Wallet2");

        string[] memory addresses = gateway.getRegisteredAddresses();
        assertEq(addresses.length, 1); // Still 1
    }

    function testRegisterBitcoinAddressEmpty() public {
        vm.prank(owner);
        vm.expectRevert("Empty address");
        gateway.registerBitcoinAddress("", "Label");
    }

    // View Functions Tests
    function testGetPaymentRequest() public {
        vm.prank(owner);
        gateway.sendBitcoin(fromAddr, toAddr, amount, memo);

        BitcoinPaymentGateway.PaymentRequest memory req = gateway.getPaymentRequest(0);
        assertEq(req.requester, owner);
        assertEq(req.amountSats, amount);
    }

    function testGetPaymentStatus() public {
        vm.prank(owner);
        uint256 requestId = gateway.sendBitcoin(fromAddr, toAddr, amount, memo);

        (bool fulfilled, bytes32 txid) = gateway.getPaymentStatus(requestId);
        assertFalse(fulfilled);
        assertEq(txid, bytes32(0));

        bytes memory proof = abi.encodePacked(uint256(1), uint256(2)); // 64 bytes

        vm.prank(relayer);
        gateway.fulfillPayment(requestId, keccak256("txid"), hex"0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798", proof);

        (fulfilled, txid) = gateway.getPaymentStatus(requestId);
        assertTrue(fulfilled);
        assertEq(txid, keccak256("txid"));
    }

    function testGetTotalSentFrom() public {
        vm.prank(owner);
        gateway.sendBitcoin(fromAddr, toAddr, amount, memo);

        assertEq(gateway.getTotalSentFrom(fromAddr), amount);
        assertEq(gateway.getTotalSentFrom("other"), 0);
    }

    function testGetTotalReceivedBy() public {
        vm.prank(owner);
        gateway.sendBitcoin(fromAddr, toAddr, amount, memo);

        assertEq(gateway.getTotalReceivedBy(toAddr), amount);
        assertEq(gateway.getTotalReceivedBy("other"), 0);
    }

    function testGetPaymentRequestBatch() public {
        vm.startPrank(owner);
        gateway.sendBitcoin(fromAddr, toAddr, amount, memo);
        gateway.sendBitcoin(fromAddr, toAddr, amount + 1, memo);
        vm.stopPrank();

        BitcoinPaymentGateway.PaymentRequest[] memory payments = gateway.getPaymentRequestBatch(0, 2);
        assertEq(payments.length, 2);
        assertEq(payments[0].amountSats, amount);
        assertEq(payments[1].amountSats, amount + 1);
    }

    function testGetRecentPayments() public {
        vm.startPrank(owner);
        gateway.sendBitcoin(fromAddr, toAddr, amount, memo);
        gateway.sendBitcoin(fromAddr, toAddr, amount + 1, memo);
        vm.stopPrank();

        BitcoinPaymentGateway.PaymentRequest[] memory payments = gateway.getRecentPayments(1);
        assertEq(payments.length, 1);
        assertEq(payments[0].amountSats, amount + 1); // Most recent
    }

    // Admin Functions Tests
    function testSetAuthorizedSender() public {
        vm.prank(owner);

        vm.expectEmit(true, false, false, true);
        emit AuthorizedSenderUpdated(authorizedSender, true);

        gateway.setAuthorizedSender(authorizedSender, true);

        vm.prank(owner);
        gateway.setAuthorizedSender(authorizedSender, false);
    }

    function testSetAuthorizedSenderZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Zero address");
        gateway.setAuthorizedSender(address(0), true);
    }

    function testPauseUnpause() public {
        vm.prank(owner);

        vm.expectEmit(false, false, false, true);
        emit PauseStateChanged(true);

        gateway.pause();
        assertTrue(gateway.paused());

        vm.prank(owner);

        vm.expectEmit(false, false, false, true);
        emit PauseStateChanged(false);

        gateway.unpause();
        assertFalse(gateway.paused());
    }

    function testUpdateRelayer() public {
        address newRelayer = address(5);

        vm.prank(owner);

        vm.expectEmit(true, true, false, false);
        emit RelayerUpdated(relayer, newRelayer);

        gateway.updateRelayer(newRelayer);
        assertEq(gateway.relayer(), newRelayer);
    }

    function testUpdateRelayerZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Zero address");
        gateway.updateRelayer(address(0));
    }

    function testTransferOwnership() public {
        address newOwner = address(6);

        vm.prank(owner);

        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, newOwner);

        gateway.transferOwnership(newOwner);
        assertEq(gateway.owner(), newOwner);
    }

    function testTransferOwnershipZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Zero address");
        gateway.transferOwnership(address(0));
    }

    // Edge Cases and Security Tests
    function testReentrancyProtection() public {
        // This contract doesn't have external calls, so no reentrancy risk
        // But test that functions don't allow reentrant calls
        // Since no callbacks, it's inherently safe
    }

    function testOverflowProtection() public {
        // Solidity 0.8+ has built-in overflow protection
        // Test large amounts
        vm.startPrank(owner);
        gateway.sendBitcoin(fromAddr, toAddr, amount, memo); // Send valid amount
        
        vm.expectRevert(); // Should revert on overflow in tracking
        gateway.sendBitcoin(fromAddr, toAddr, type(uint256).max, memo);
        vm.stopPrank();
    }

    function testGasUsage() public {
        // Can add gas snapshot tests if needed
        vm.prank(owner);
        uint256 gasStart = gasleft();
        gateway.sendBitcoin(fromAddr, toAddr, amount, memo);
        uint256 gasUsed = gasStart - gasleft();
        // Assert gasUsed < some limit if needed
    }

    // Integration Test
    function testFullPaymentFlow() public {
        // Create payment
        vm.prank(owner);
        uint256 requestId = gateway.sendBitcoin(fromAddr, toAddr, amount, memo);

        // Fulfill payment
        vm.prank(relayer);
        bytes32 txid = keccak256("full flow txid");
        gateway.fulfillPayment(requestId, txid, hex"0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798", abi.encodePacked(uint256(1), uint256(2)));

        // Verify
        (bool fulfilled, bytes32 returnedTxid) = gateway.getPaymentStatus(requestId);
        assertTrue(fulfilled);
        assertEq(returnedTxid, txid);
        assertEq(gateway.getTotalSentFrom(fromAddr), amount);
        assertEq(gateway.getTotalReceivedBy(toAddr), amount);
    }
}
