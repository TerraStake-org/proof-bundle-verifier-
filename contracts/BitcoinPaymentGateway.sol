// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title BitcoinPaymentGateway V3 - Ultimate Flexibility
 * @author FastPath by Emiliano G Solazzi Nov 2025
 * @notice Smart contract for sending real Bitcoin transactions from ANY address
 * @dev Self-hosted implementation requiring user-operated FastPath RPC and relayer infrastructure.
 *      Contract maintains audit trail on-chain while actual Bitcoin transactions occur off-chain.
 *      Uses event-driven architecture where on-chain events trigger off-chain Bitcoin operations.
 *      Security model relies on Ledger hardware wallet signing via FastPath RPC.
 *      No custodial risk - user maintains full control of private keys and Bitcoin addresses.
 * 
 * KEY FEATURES:
 * - Send from ANY Bitcoin address (not locked to one treasury)
 * - Multi-wallet support (hot, cold, savings, spending, etc.)
 * - Business-ready (multiple wallets for different purposes)
 * - Full audit trail (all transactions logged on-chain)
 * - Ledger security maintained (hardware signing via FastPath RPC)
 * - Self-sovereign (no third parties, no custodians)
 */

contract BitcoinPaymentGateway {
    
    /// @notice Contract owner (can initiate payments)
    /// @dev Owner has privileged access to administrative functions including pause, relayer updates, and authorization management
    address public owner;
    
    /// @notice Off-chain relayer address (updates contract after Bitcoin tx)
    /// @dev Relayer is the only address authorized to fulfill payment requests and mark transactions complete
    address public relayer;
    
    /// @notice Payment request ID counter
    /// @dev Monotonically increasing counter used to generate unique identifiers for each payment request
    uint256 public requestCount;
    
    /// @notice Emergency pause state
    /// @dev When true, prevents new payment requests from being created. Does not affect fulfillment of existing requests
    bool public paused;
    
    /// @notice Payment request structure
    /// @dev Struct fields ordered for optimal storage packing: addresses, uint256s, bytes32, bool, then dynamic types
    ///      This minimizes storage slots and reduces gas costs for struct operations
    struct PaymentRequest {
        address requester;          // Who initiated the payment (20 bytes)
        uint256 amountSats;         // Amount in satoshis (32 bytes)
        uint256 timestamp;          // When request was created (32 bytes)
        bytes32 btcTxid;           // Bitcoin transaction ID once fulfilled (32 bytes)
        bool fulfilled;             // Whether Bitcoin tx was broadcast (1 byte)
        string fromBtcAddress;      // Source Bitcoin address - flexible multi-wallet support
        string toBtcAddress;        // Recipient Bitcoin address
        string memo;                // Optional memo/note for transaction tracking
    }
    
    /// @notice All payment requests
    /// @dev Maps request ID to complete payment details including Bitcoin addresses and transaction status
    mapping(uint256 requestId => PaymentRequest request) public requests;
    
    /// @notice Track total sent from each Bitcoin address
    /// @dev Maps keccak256 hash of Bitcoin address string to cumulative satoshis sent. Updated on request creation, reverted on failure
    mapping(bytes32 addressHash => uint256 totalSatoshis) public totalSentByAddress;
    
    /// @notice Track total sent to each Bitcoin address
    /// @dev Maps keccak256 hash of recipient Bitcoin address to cumulative satoshis received. Updated on request creation, reverted on failure
    mapping(bytes32 addressHash => uint256 totalSatoshis) public totalReceivedByAddress;
    
    /// @notice Authorized senders (optional whitelist)
    /// @dev Maps Ethereum addresses to authorization status. Authorized addresses can initiate Bitcoin payment requests
    mapping(address sender => bool isAuthorized) public authorizedSenders;
    
    /// @notice Bitcoin addresses you control (optional registry)
    /// @dev Maps keccak256 hash of Bitcoin address to registration status for tracking owned addresses
    mapping(bytes32 addressHash => bool isRegistered) public registeredBitcoinAddresses;
    
    /// @notice List of all registered Bitcoin addresses
    /// @dev Array maintains insertion order of registered addresses for enumeration. Used with registeredBitcoinAddresses mapping
    string[] public registeredAddressList;
    
    /// @notice Emitted when Bitcoin payment is requested
    /// @dev Off-chain relayer listens for this event to initiate Bitcoin transaction signing and broadcast
    /// @param requestId Unique identifier for this payment request
    /// @param fromBtcAddress Source Bitcoin address (indexed for filtering by sender)
    /// @param toBtcAddress Destination Bitcoin address (indexed for filtering by recipient)
    /// @param amountSats Amount in satoshis to transfer
    /// @param requester Ethereum address that initiated the request
    /// @param memo Optional note or description for the transaction
    event BitcoinPaymentRequested(
        uint256 indexed requestId,
        string indexed fromBtcAddress,
        string indexed toBtcAddress,
        uint256 amountSats,
        address requester,
        string memo
    );
    
    /// @notice Emitted when Bitcoin payment is completed
    /// @dev Confirms Bitcoin transaction was successfully broadcast to the network
    /// @param requestId Unique identifier linking to original payment request
    /// @param btcTxid Bitcoin transaction ID (indexed for easy lookup)
    /// @param fromBtcAddress Source Bitcoin address that sent funds
    /// @param toBtcAddress Destination Bitcoin address that received funds
    /// @param amountSats Amount in satoshis that was transferred
    event BitcoinPaymentCompleted(
        uint256 indexed requestId,
        bytes32 indexed btcTxid,
        string fromBtcAddress,
        string toBtcAddress,
        uint256 amountSats
    );
    
    /// @notice Emitted when payment fails
    /// @dev Relayer emits this when Bitcoin transaction cannot be completed
    /// @param requestId Unique identifier of failed payment request
    /// @param reason Human-readable explanation of failure cause
    event BitcoinPaymentFailed(
        uint256 indexed requestId,
        string reason
    );
    
    /// @notice Emitted with transaction signature proof for offline verification
    /// @dev Minimal data emitted for gas efficiency - users can reconstruct full verification
    ///      Mirrors VRF proof structure for consistency with decentralized verification patterns
    ///      Users fetch full Bitcoin transaction from blockchain using btcTxid and verify signature locally
    /// @param requestId Unique identifier linking proof to payment request (indexed for filtering)
    /// @param publicKey Public key that signed the transaction (uncompressed or compressed format)
    /// @param btcTxid Bitcoin transaction ID serving as the verification output (indexed for lookup)
    /// @param proof ECDSA signature components r+s concatenated (64 bytes total)
    event BitcoinTransactionProof(
        uint256 indexed requestId,
        bytes publicKey,
        bytes32 indexed btcTxid,
        bytes proof
    );
    
    /// @notice Emitted when Bitcoin address is registered
    /// @dev Helps track which Bitcoin addresses are controlled by this contract's operations
    /// @param btcAddress Bitcoin address being registered (bc1q..., 3..., or 1... format)
    /// @param label Human-readable description (e.g., "Hot Wallet", "Cold Storage")
    event BitcoinAddressRegistered(
        string btcAddress,
        string label
    );
    
    /// @notice Emitted when authorized sender is added/removed
    /// @dev Tracks changes to payment initiation permissions
    /// @param sender Ethereum address whose authorization status changed
    /// @param authorized True if sender was authorized, false if deauthorized
    event AuthorizedSenderUpdated(
        address indexed sender,
        bool authorized
    );
    
    /// @notice Emitted when contract is paused/unpaused
    /// @dev Pause state changes affect ability to create new payment requests
    /// @param paused True if contract was paused, false if unpaused
    event PauseStateChanged(bool paused);
    
    /// @notice Emitted when relayer address is updated
    /// @dev Tracks changes to the address authorized to fulfill payment requests
    /// @param oldRelayer Previous relayer address
    /// @param newRelayer New relayer address
    event RelayerUpdated(address indexed oldRelayer, address indexed newRelayer);
    
    /// @notice Emitted when contract ownership is transferred
    /// @dev Tracks ownership transfers for administrative control
    /// @param previousOwner Previous owner address
    /// @param newOwner New owner address
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    /// @notice Restricts function to owner only
    /// @dev Prevents unauthorized access to administrative functions. Reverts with "Not owner" if caller is not contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    /// @notice Restricts function to relayer only
    /// @dev Ensures only designated relayer can fulfill payments and update transaction status. Reverts with "Not relayer" if caller is not authorized relayer
    modifier onlyRelayer() {
        require(msg.sender == relayer, "Not relayer");
        _;
    }
    
    /// @notice Restricts function to owner or authorized senders
    /// @dev Allows contract owner and whitelisted addresses to initiate payment requests. Reverts with "Not authorized" if caller lacks permission
    modifier onlyAuthorized() {
        require(
            msg.sender == owner || authorizedSenders[msg.sender],
            "Not authorized"
        );
        _;
    }
    
    /// @notice Prevents execution when paused
    /// @dev Emergency circuit breaker to halt new payment requests during incidents. Does not affect existing request fulfillment. Reverts with "Contract paused" when pause is active
    modifier whenNotPaused() {
        require(!paused, "Contract paused");
        _;
    }
    
    /// @notice Initialize contract
    /// @dev Sets up contract with deployer as owner and specified relayer address. Contract starts in unpaused state
    /// @param _relayer Ethereum address authorized to fulfill Bitcoin payment requests and update transaction status
    constructor(address _relayer) {
        require(_relayer != address(0), "Zero relayer");
        
        relayer = _relayer;
        owner = msg.sender;
        paused = false;
    }
    
    /**
     * @notice Send Bitcoin from ANY address you control
     * @dev Creates on-chain payment request and emits BitcoinPaymentRequested event for off-chain relayer.
     *      Does not transfer actual Bitcoin - relayer monitors event and triggers Bitcoin network transaction.
     *      Updates totalSentByAddress and totalReceivedByAddress tracking mappings.
     *      Enforces minimum amount above Bitcoin dust limit (546 satoshis).
     * @param fromBtcAddress Source Bitcoin address you control (any format: bc1q..., 3..., 1..., bc1p...)
     * @param toBtcAddress Recipient Bitcoin address (any valid Bitcoin address format)
     * @param amountSats Amount to send in satoshis (must be >= 546 to avoid dust limit)
     * @param memo Optional note for transaction tracking (can be empty string)
     * @return requestId Unique identifier for this payment request, used to track fulfillment status
     */
    function sendBitcoin(
        string memory fromBtcAddress,
        string memory toBtcAddress,
        uint256 amountSats,
        string memory memo
    ) external onlyAuthorized whenNotPaused returns (uint256 requestId) {
        
        require(bytes(fromBtcAddress).length > 0, "Empty from address");
        require(bytes(toBtcAddress).length > 0, "Empty to address");
        require(amountSats > 0, "Zero amount");
        require(amountSats >= 546, "Below dust limit"); // Bitcoin dust limit
        
        // Create request
        requestId = requestCount++;
        
        PaymentRequest storage req = requests[requestId];
        req.requester = msg.sender;
        req.fromBtcAddress = fromBtcAddress;
        req.toBtcAddress = toBtcAddress;
        req.amountSats = amountSats;
        req.timestamp = block.timestamp;
        req.fulfilled = false;
        req.memo = memo;
        
        // Update tracking
        bytes32 fromHash = keccak256(bytes(fromBtcAddress));
        bytes32 toHash = keccak256(bytes(toBtcAddress));
        totalSentByAddress[fromHash] += amountSats;
        totalReceivedByAddress[toHash] += amountSats;
        
        // Emit event for off-chain relayer
        emit BitcoinPaymentRequested(
            requestId,
            fromBtcAddress,
            toBtcAddress,
            amountSats,
            msg.sender,
            memo
        );
    }
    
    /**
     * @notice Fulfill payment with signature proof for offline verification
     * @dev Called by relayer after Bitcoin transaction is broadcast to network.
     *      Emits both BitcoinPaymentCompleted and BitcoinTransactionProof events.
     *      Proof structure mirrors VRF pattern for consistent decentralized verification.
     *      Users can independently verify signature by fetching full Bitcoin tx from blockchain using btcTxid.
     *      Enforces proof length validation (64 bytes = 32 bytes r + 32 bytes s).
     * @param requestId Payment request identifier to mark as fulfilled
     * @param btcTxid Bitcoin transaction ID from network broadcast (serves as verification output)
     * @param publicKey Public key that signed the Bitcoin transaction (compressed or uncompressed format)
     * @param proof ECDSA signature components r and s concatenated (exactly 64 bytes)
     */
    function fulfillPayment(
        uint256 requestId, 
        bytes32 btcTxid,
        bytes memory publicKey,
        bytes memory proof
    ) external onlyRelayer {
        
        require(requestId < requestCount, "Invalid request");
        PaymentRequest storage req = requests[requestId];
        require(!req.fulfilled, "Already fulfilled");
        require(btcTxid != bytes32(0), "Invalid txid");
        require(proof.length == 64, "Invalid proof length"); // r(32) + s(32)
        
        req.fulfilled = true;
        req.btcTxid = btcTxid;
        
        emit BitcoinPaymentCompleted(
            requestId,
            btcTxid,
            req.fromBtcAddress,
            req.toBtcAddress,
            req.amountSats
        );
        
        emit BitcoinTransactionProof(
            requestId,
            publicKey,
            btcTxid,
            proof
        );
    }
    
    /**
     * @notice Mark payment as failed
     * @dev Called by relayer when Bitcoin transaction cannot be broadcast or is rejected by network.
     *      Reverts totalSentByAddress and totalReceivedByAddress tracking to maintain accurate accounting.
     *      Does not mark request as fulfilled, allowing potential retry if desired.
     * @param requestId Payment request identifier that failed
     * @param reason Human-readable explanation of failure (e.g., "Insufficient funds", "Invalid address")
     */
    function markPaymentFailed(uint256 requestId, string memory reason) 
        external onlyRelayer {
        
        require(requestId < requestCount, "Invalid request");
        PaymentRequest storage req = requests[requestId];
        require(!req.fulfilled, "Already fulfilled");
        
        // Revert tracking
        bytes32 fromHash = keccak256(bytes(req.fromBtcAddress));
        bytes32 toHash = keccak256(bytes(req.toBtcAddress));
        totalSentByAddress[fromHash] -= req.amountSats;
        totalReceivedByAddress[toHash] -= req.amountSats;
        
        emit BitcoinPaymentFailed(requestId, reason);
    }
    
    /**
     * @notice Register a Bitcoin address you control
     * @dev Optional address registry for tracking owned Bitcoin addresses.
     *      Prevents duplicate registration by checking registeredBitcoinAddresses mapping.
     *      Adds address to registeredAddressList array for enumeration.
     * @param btcAddress Bitcoin address to register (any format: bc1q..., 3..., 1..., bc1p...)
     * @param label Human-readable description for this address (e.g., "Hot Wallet", "Cold Storage", "Treasury")
     */
    function registerBitcoinAddress(string memory btcAddress, string memory label) 
        external onlyOwner {
        
        require(bytes(btcAddress).length > 0, "Empty address");
        bytes32 addrHash = keccak256(bytes(btcAddress));
        
        if (!registeredBitcoinAddresses[addrHash]) {
            registeredBitcoinAddresses[addrHash] = true;
            registeredAddressList.push(btcAddress);
        }
        
        emit BitcoinAddressRegistered(btcAddress, label);
    }
    
    /**
     * @notice Check if Bitcoin address is registered
     * @dev Computes keccak256 hash of address string to check registration mapping
     * @param btcAddress Bitcoin address to verify registration status
     * @return registered True if address exists in registeredBitcoinAddresses mapping
     */
    function isBitcoinAddressRegistered(string memory btcAddress) 
        external view returns (bool registered) {
        bytes32 addrHash = keccak256(bytes(btcAddress));
        return registeredBitcoinAddresses[addrHash];
    }
    
    /**
     * @notice Get all registered Bitcoin addresses
     * @dev Returns complete list from registeredAddressList array
     * @return addresses Array of all registered Bitcoin addresses in insertion order
     */
    function getRegisteredAddresses() 
        external view returns (string[] memory addresses) {
        return registeredAddressList;
    }
    
    /**
     * @notice Get payment request details
     * @dev Retrieves complete PaymentRequest struct from storage
     * @param requestId Request ID to query (must be less than requestCount)
     * @return request Complete payment request including addresses, amounts, status, and transaction ID
     */
    function getPaymentRequest(uint256 requestId) 
        external view returns (PaymentRequest memory request) {
        require(requestId < requestCount, "Invalid request");
        return requests[requestId];
    }
    
    /**
     * @notice Check if payment is complete
     * @dev Lightweight query returning only fulfillment status and transaction ID
     * @param requestId Request ID to check (must be less than requestCount)
     * @return fulfilled True if Bitcoin transaction was successfully broadcast
     * @return btcTxid Bitcoin transaction ID if fulfilled, bytes32(0) if pending
     */
    function getPaymentStatus(uint256 requestId) 
        external view returns (bool fulfilled, bytes32 btcTxid) {
        require(requestId < requestCount, "Invalid request");
        PaymentRequest storage req = requests[requestId];
        return (req.fulfilled, req.btcTxid);
    }
    
    /**
     * @notice Get total amount sent from a Bitcoin address
     * @dev Queries totalSentByAddress mapping using keccak256 hash of address string
     * @param btcAddress Bitcoin address to query (any format)
     * @return totalSats Cumulative satoshis sent from this address across all requests
     */
    function getTotalSentFrom(string memory btcAddress) 
        external view returns (uint256 totalSats) {
        bytes32 addrHash = keccak256(bytes(btcAddress));
        return totalSentByAddress[addrHash];
    }
    
    /**
     * @notice Get total amount received by a Bitcoin address
     * @dev Queries totalReceivedByAddress mapping using keccak256 hash of address string
     * @param btcAddress Bitcoin address to query (any format)
     * @return totalSats Cumulative satoshis received by this address across all requests
     */
    function getTotalReceivedBy(string memory btcAddress) 
        external view returns (uint256 totalSats) {
        bytes32 addrHash = keccak256(bytes(btcAddress));
        return totalReceivedByAddress[addrHash];
    }
    
    /**
     * @notice Get multiple payment requests at once
     * @dev Batch query function for efficient retrieval of consecutive payment requests.
     *      Automatically adjusts count if it would exceed available requests.
     *      Uses pre-computed index to avoid arithmetic within array access.
     * @param startId Starting request ID (must be less than requestCount)
     * @param count Maximum number of requests to fetch (actual count may be less if near end)
     * @return payments Array of payment requests from startId to min(startId+count, requestCount)
     */
    function getPaymentRequestBatch(uint256 startId, uint256 count) 
        external view returns (PaymentRequest[] memory payments) {
        
        require(startId < requestCount, "Invalid start");
        
        uint256 end = startId + count;
        if (end > requestCount) {
            end = requestCount;
        }
        
        uint256 actualCount = end - startId;
        payments = new PaymentRequest[](actualCount);
        
        for (uint256 i = 0; i < actualCount; i++) {
            uint256 requestIndex = startId + i;
            payments[i] = requests[requestIndex];
        }
    }
    
    /**
     * @notice Get recent payment requests
     * @dev Retrieves most recent payment requests in chronological order.
     *      Automatically adjusts count if it exceeds total available requests.
     *      Returns empty array if no requests exist.
     *      Computes index before array access to avoid inline arithmetic.
     * @param count Maximum number of recent requests to fetch
     * @return payments Array of most recent payment requests (oldest to newest)
     */
    function getRecentPayments(uint256 count) 
        external view returns (PaymentRequest[] memory payments) {
        
        if (count > requestCount) {
            count = requestCount;
        }
        
        if (count == 0) {
            return new PaymentRequest[](0);
        }
        
        payments = new PaymentRequest[](count);
        uint256 startId = requestCount - count;
        
        for (uint256 i = 0; i < count; i++) {
            uint256 requestIndex = startId + i;
            payments[i] = requests[requestIndex];
        }
    }
    
    /**
     * @notice Add or remove authorized sender
     * @dev Updates authorizedSenders mapping to grant or revoke payment initiation privileges.
     *      Emits AuthorizedSenderUpdated event for off-chain tracking.
     * @param sender Ethereum address to modify authorization for
     * @param authorized True to grant payment request permission, false to revoke
     */
    function setAuthorizedSender(address sender, bool authorized) 
        external onlyOwner {
        require(sender != address(0), "Zero address");
        authorizedSenders[sender] = authorized;
        emit AuthorizedSenderUpdated(sender, authorized);
    }
    
    /**
     * @notice Emergency pause (stops new payments)
     * @dev Sets paused flag to true, preventing new payment requests via whenNotPaused modifier.
     *      Does not affect fulfillment of existing requests or other contract functions.
     *      Use during security incidents or maintenance.
     */
    function pause() external onlyOwner {
        paused = true;
        emit PauseStateChanged(true);
    }
    
    /**
     * @notice Unpause contract
     * @dev Sets paused flag to false, re-enabling payment request creation.
     *      Call after resolving issues that required emergency pause.
     */
    function unpause() external onlyOwner {
        paused = false;
        emit PauseStateChanged(false);
    }
    
    /**
     * @notice Update relayer address
     * @dev Changes which address can fulfill payments and mark transactions complete.
     *      Use when rotating relayer infrastructure or changing operational addresses.
     *      Emits RelayerUpdated event for off-chain tracking.
     * @param newRelayer New Ethereum address for relayer role
     */
    function updateRelayer(address newRelayer) external onlyOwner {
        require(newRelayer != address(0), "Zero address");
        address oldRelayer = relayer;
        relayer = newRelayer;
        emit RelayerUpdated(oldRelayer, newRelayer);
    }
    
    /**
     * @notice Transfer ownership
     * @dev Transfers all owner privileges to new address including pause, relayer updates, and authorization management.
     *      Use caution - this is irreversible without cooperation from new owner.
     *      Emits OwnershipTransferred event for off-chain tracking.
     * @param newOwner New Ethereum address to become contract owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }
}
