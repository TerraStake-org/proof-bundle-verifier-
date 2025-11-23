Ran 40 tests for test/Bitcoingateway.t.sol:BitcoinPaymentGatewayTest
[PASS] testConstructor() (gas: 22206)
[PASS] testConstructorZeroRelayer() (gas: 40976)
[PASS] testFulfillPaymentAlreadyFulfilled() (gas: 400935)
[PASS] testFulfillPaymentInvalidProofLength() (gas: 343189)
[PASS] testFulfillPaymentInvalidRequest() (gas: 18363)
[PASS] testFulfillPaymentInvalidTxid() (gas: 343103)
[PASS] testFulfillPaymentSuccess() (gas: 409944)
[PASS] testFullPaymentFlow() (gas: 404279)
[PASS] testGasUsage() (gas: 334071)
[PASS] testGetPaymentRequest() (gas: 346640)
[PASS] testGetPaymentRequestBatch() (gas: 599999)
[PASS] testGetPaymentStatus() (gas: 400086)
[PASS] testGetRecentPayments() (gas: 587555)
[PASS] testGetTotalReceivedBy() (gas: 341431)
[PASS] testGetTotalSentFrom() (gas: 341520)
[PASS] testMarkPaymentFailedAlreadyFulfilled() (gas: 399518)
[PASS] testMarkPaymentFailedInvalidRequest() (gas: 17223)
[PASS] testMarkPaymentFailedSuccess() (gas: 316082)
[PASS] testOnlyAuthorizedModifier() (gas: 37035)
[PASS] testOnlyOwnerModifier() (gas: 13705)
[PASS] testOnlyRelayerModifier() (gas: 16329)
[PASS] testOverflowProtection() (gas: 568134)
[PASS] testPauseUnpause() (gas: 32349)
[PASS] testReentrancyProtection() (gas: 254)
[PASS] testRegisterBitcoinAddressDuplicate() (gas: 149091)
[PASS] testRegisterBitcoinAddressEmpty() (gas: 15644)
[PASS] testRegisterBitcoinAddressSuccess() (gas: 151335)
[PASS] testSendBitcoinAuthorizedSender() (gas: 369502)
[PASS] testSendBitcoinBelowDustLimit() (gas: 37083)
[PASS] testSendBitcoinEmptyFromAddress() (gas: 32514)
[PASS] testSendBitcoinEmptyToAddress() (gas: 32561)
[PASS] testSendBitcoinSuccess() (gas: 367516)
[PASS] testSendBitcoinZeroAmount() (gas: 35083)
[PASS] testSetAuthorizedSender() (gas: 33072)
[PASS] testSetAuthorizedSenderZeroAddress() (gas: 14495)
[PASS] testTransferOwnership() (gas: 22022)
[PASS] testTransferOwnershipZeroAddress() (gas: 14173)
[PASS] testUpdateRelayer() (gas: 25983)
[PASS] testUpdateRelayerZeroAddress() (gas: 14239)
[PASS] testWhenNotPausedModifier() (gas: 59903)
Suite result: ok. 40 passed; 0 failed; 0 skipped; finished in 2.85ms (14.18ms CPU time)

Ran 4 tests for test/BitcoingatewayFuzz.t.sol:BitcoinPaymentGatewayFuzzTest
[PASS] testFuzz_AmountTracking(uint256) (runs: 256, μ: 341018, ~: 341018)
[PASS] testFuzz_FulfillPaymentInvalidProofLength(uint256) (runs: 256, μ: 342320, ~: 342253)
[PASS] testRelayerGriefing_MarkPaymentFailedLoop() (gas: 2532291)
[PASS] testTimestampRecording() (gas: 344886)
Suite result: ok. 4 passed; 0 failed; 0 skipped; finished in 36.06ms (66.30ms CPU time)

Ran 2 test suites in 39.42ms (38.91ms CPU time): 44 tests passed, 0 failed, 0 skipped (44 total tests)
Ran 8 tests for test/BitcoingatewayFuzz.t.sol:BitcoinPaymentGatewayFuzzTest
[PASS] testConcurrentFulfillment() (gas: 398337)
[PASS] testFulfillPayment_ExplicitEdgeCases() (gas: 362688)
[PASS] testFuzz_AmountTracking(uint256) (runs: 256, μ: 340877, ~: 340877)
[PASS] testFuzz_AmountTracking_Uint256Max(uint256) (runs: 256, μ: 337942, ~: 337942)
[PASS] testFuzz_FulfillPaymentInvalidProofLength(uint256) (runs: 256, μ: 342285, ~: 342249)
[PASS] testRelayerGriefing_MarkPaymentFailedLoop() (gas: 24775335)
[PASS] testReorgDoubleFulfillment() (gas: 398285)
[PASS] testTimestampRecording() (gas: 344908)
Suite result: ok. 8 passed; 0 failed; 0 skipped; finished in 37.35ms (104.36ms CPU time)

Ran 1 test suite in 41.71ms (37.35ms CPU time): 8 tests passed, 0 failed, 0 skipped (8 total tests)
Ran 3 tests for test/BitcoingatewayInvariants.t.sol:BitcoinPaymentGatewayInvariantTest
[PASS] invariant_pausedState() (runs: 256, calls: 128000, reverts: 0)

╭------------------------------+-------------+-------+---------+----------╮
| Contract                     | Selector    | Calls | Reverts | Discards |
+=========================================================================+
| BitcoinPaymentGatewayHandler | pause       | 42621 | 0       | 0        |
|------------------------------+-------------+-------+---------+----------|
| BitcoinPaymentGatewayHandler | sendBitcoin | 42577 | 0       | 0        |
|------------------------------+-------------+-------+---------+----------|
| BitcoinPaymentGatewayHandler | unpause     | 42802 | 0       | 0        |
╰------------------------------+-------------+-------+---------+----------╯

[PASS] invariant_requestCountMatchesGhost() (runs: 256, calls: 128000, reverts: 0)

╭------------------------------+-------------+-------+---------+----------╮
| Contract                     | Selector    | Calls | Reverts | Discards |
+=========================================================================+
| BitcoinPaymentGatewayHandler | pause       | 42300 | 0       | 0        |
|------------------------------+-------------+-------+---------+----------|
| BitcoinPaymentGatewayHandler | sendBitcoin | 42897 | 0       | 0        |
|------------------------------+-------------+-------+---------+----------|
| BitcoinPaymentGatewayHandler | unpause     | 42803 | 0       | 0        |
╰------------------------------+-------------+-------+---------+----------╯

[PASS] invariant_totalSentMatchesGhost() (runs: 256, calls: 128000, reverts: 0)

╭------------------------------+-------------+-------+---------+----------╮
| Contract                     | Selector    | Calls | Reverts | Discards |
+=========================================================================+
| BitcoinPaymentGatewayHandler | pause       | 42610 | 0       | 0        |
|------------------------------+-------------+-------+---------+----------|
| BitcoinPaymentGatewayHandler | sendBitcoin | 42447 | 0       | 0        |
|------------------------------+-------------+-------+---------+----------|
| BitcoinPaymentGatewayHandler | unpause     | 42943 | 0       | 0        |
╰------------------------------+-------------+-------+---------+----------╯

Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 18.69s (53.39s CPU time)

Ran 1 test suite in 18.70s (18.69s CPU time): 3 tests passed, 0 failed, 0 skipped (3 total tests)

Ran 3 tests for test/BitcoingatewayInvariants.t.sol:BitcoinPaymentGatewayInvariantTest
[PASS] invariant_pausedState() (runs: 256, calls: 128000, reverts: 12703)

╭------------------------------+-------------------------+-------+---------+----------╮
| Contract                     | Selector                | Calls | Reverts | Discards |
+=====================================================================================+
| BitcoinPaymentGatewayHandler | pause                   | 25756 | 0       | 0        |
|------------------------------+-------------------------+-------+---------+----------|
| BitcoinPaymentGatewayHandler | sendBitcoin             | 25566 | 0       | 0        |
|------------------------------+-------------------------+-------+---------+----------|
| BitcoinPaymentGatewayHandler | sendBitcoinDust         | 25550 | 12703   | 0        |
|------------------------------+-------------------------+-------+---------+----------|
| BitcoinPaymentGatewayHandler | sendBitcoinUnauthorized | 25627 | 0       | 0        |
|------------------------------+-------------------------+-------+---------+----------|
| BitcoinPaymentGatewayHandler | unpause                 | 25501 | 0       | 0        |
╰------------------------------+-------------------------+-------+---------+----------╯

[PASS] invariant_requestCountMatchesGhost() (runs: 256, calls: 128000, reverts: 12882)

╭------------------------------+-------------------------+-------+---------+----------╮
| Contract                     | Selector                | Calls | Reverts | Discards |
+=====================================================================================+
| BitcoinPaymentGatewayHandler | pause                   | 25501 | 0       | 0        |
|------------------------------+-------------------------+-------+---------+----------|
| BitcoinPaymentGatewayHandler | sendBitcoin             | 25834 | 0       | 0        |
|------------------------------+-------------------------+-------+---------+----------|
| BitcoinPaymentGatewayHandler | sendBitcoinDust         | 25654 | 12882   | 0        |
|------------------------------+-------------------------+-------+---------+----------|
| BitcoinPaymentGatewayHandler | sendBitcoinUnauthorized | 25490 | 0       | 0        |
|------------------------------+-------------------------+-------+---------+----------|
| BitcoinPaymentGatewayHandler | unpause                 | 25521 | 0       | 0        |
╰------------------------------+-------------------------+-------+---------+----------╯

[PASS] invariant_totalSentMatchesGhost() (runs: 256, calls: 128000, reverts: 12623)

╭------------------------------+-------------------------+-------+---------+----------╮
| Contract                     | Selector                | Calls | Reverts | Discards |
+=====================================================================================+
| BitcoinPaymentGatewayHandler | pause                   | 25589 | 0       | 0        |
|------------------------------+-------------------------+-------+---------+----------|
| BitcoinPaymentGatewayHandler | sendBitcoin             | 25466 | 0       | 0        |
|------------------------------+-------------------------+-------+---------+----------|
| BitcoinPaymentGatewayHandler | sendBitcoinDust         | 25497 | 12623   | 0        |
|------------------------------+-------------------------+-------+---------+----------|
| BitcoinPaymentGatewayHandler | sendBitcoinUnauthorized | 25761 | 0       | 0        |
|------------------------------+-------------------------+-------+---------+----------|
| BitcoinPaymentGatewayHandler | unpause                 | 25687 | 0       | 0        |
╰------------------------------+-------------------------+-------+---------+----------╯

Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 18.15s (53.49s CPU time)

Ran 1 test suite in 18.16s (18.15s CPU time): 3 tests passed, 0 failed, 0 skipped (3 total tests)
