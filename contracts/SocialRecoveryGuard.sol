// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SocialRecoveryGuard
 * @notice Multi-guardian social recovery module and transaction guard for ERC-4337 smart contract wallets and Safe multisigs.
 * @dev Enforces guardian approval threshold, timelock delay, and emergency owner cancellation.
 */
contract SocialRecoveryGuard {
    struct RecoveryRequest {
        address proposedNewOwner;
        uint256 approvalCount;
        uint256 executionTime;
        bool executed;
        bool canceled;
    }

    address public immutable wallet;
    uint256 public immutable recoveryTimelock;
    uint256 public threshold;
    uint256 public guardianCount;

    mapping(address => bool) public isGuardian;
    mapping(uint256 => RecoveryRequest) public recoveryRequests;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public nextRecoveryId;

    event GuardianAdded(address indexed guardian);
    event GuardianRemoved(address indexed guardian);
    event ThresholdChanged(uint256 newThreshold);
    event RecoveryInitiated(uint256 indexed recoveryId, address indexed proposedOwner, uint256 executeAfter);
    event RecoveryVoted(uint256 indexed recoveryId, address indexed guardian, uint256 currentApprovals);
    event RecoveryExecuted(uint256 indexed recoveryId, address indexed newOwner);
    event RecoveryCanceled(uint256 indexed recoveryId);

    modifier onlyWallet() {
        require(msg.sender == wallet, "SocialRecoveryGuard: Caller must be wallet");
        _;
    }

    modifier onlyGuardian() {
        require(isGuardian[msg.sender], "SocialRecoveryGuard: Caller must be guardian");
        _;
    }

    constructor(
        address _wallet,
        address[] memory _initialGuardians,
        uint256 _threshold,
        uint256 _timelock
    ) {
        require(_wallet != address(0), "Invalid wallet address");
        require(_threshold > 0 && _threshold <= _initialGuardians.length, "Invalid threshold");

        wallet = _wallet;
        recoveryTimelock = _timelock;
        threshold = _threshold;

        for (uint256 i = 0; i < _initialGuardians.length; i++) {
            address g = _initialGuardians[i];
            require(g != address(0) && !isGuardian[g], "Invalid or duplicate guardian");
            isGuardian[g] = true;
            emit GuardianAdded(g);
        }
        guardianCount = _initialGuardians.length;
    }

    /**
     * @notice Initiates a recovery request to replace compromised wallet credentials.
     * @param proposedOwner New address to be assigned ownership of the wallet.
     */
    function initiateRecovery(address proposedOwner) external onlyGuardian returns (uint256 recoveryId) {
        require(proposedOwner != address(0) && proposedOwner != wallet, "Invalid new owner");

        recoveryId = nextRecoveryId++;
        RecoveryRequest storage req = recoveryRequests[recoveryId];
        req.proposedNewOwner = proposedOwner;
        req.approvalCount = 1;
        req.executionTime = block.timestamp + recoveryTimelock;
        hasVoted[recoveryId][msg.sender] = true;

        emit RecoveryInitiated(recoveryId, proposedOwner, req.executionTime);
        emit RecoveryVoted(recoveryId, msg.sender, 1);
    }

    /**
     * @notice Allows another guardian to confirm an active recovery proposal.
     */
    function voteRecovery(uint256 recoveryId) external onlyGuardian {
        RecoveryRequest storage req = recoveryRequests[recoveryId];
        require(!req.executed, "Recovery already executed");
        require(!req.canceled, "Recovery was canceled");
        require(!hasVoted[recoveryId][msg.sender], "Guardian already voted");

        hasVoted[recoveryId][msg.sender] = true;
        req.approvalCount++;

        emit RecoveryVoted(recoveryId, msg.sender, req.approvalCount);
    }

    /**
     * @notice Executes the recovery and updates ownership after threshold reached and timelock expired.
     */
    function executeRecovery(uint256 recoveryId) external {
        RecoveryRequest storage req = recoveryRequests[recoveryId];
        require(!req.executed, "Recovery already executed");
        require(!req.canceled, "Recovery was canceled");
        require(req.approvalCount >= threshold, "Threshold not reached");
        require(block.timestamp >= req.executionTime, "Timelock not elapsed");

        req.executed = true;

        // Perform external call to wallet contract interface
        (bool success, ) = wallet.call(
            abi.encodeWithSignature("setOwner(address)", req.proposedNewOwner)
        );
        require(success, "Wallet ownership transfer failed");

        emit RecoveryExecuted(recoveryId, req.proposedNewOwner);
    }

    /**
     * @notice Allows original wallet owner to cancel malicious or mistaken recovery proposals during timelock.
     */
    function cancelRecovery(uint256 recoveryId) external onlyWallet {
        RecoveryRequest storage req = recoveryRequests[recoveryId];
        require(!req.executed, "Recovery already executed");
        require(!req.canceled, "Recovery already canceled");

        req.canceled = true;
        emit RecoveryCanceled(recoveryId);
    }
}
