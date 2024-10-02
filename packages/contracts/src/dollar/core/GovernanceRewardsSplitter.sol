// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title GovernanceRewardsSplitter
 * @notice A configurable mono ERC20 payment splitter.
 * @dev This contract allows to split governance token payments among a group of accounts. The sender does not need to be aware
 * that the ERC20 will be split in this way, since it is handled transparently by the contract.
 *
 * The split can be in equal parts or in any other arbitrary proportion. The way this is specified is by assigning each
 * account to a number of shares. Of all tokens that this contract receives, each account will then be able to claim
 * an amount proportional to the percentage of total shares they were assigned.
 *
 * This contract is configurable by owner, which means that at any time it's owner can update the split configuration.
 * The configuration is tracked through IDs and all previous configurations can be transparently checked.
 *
 * `GovernanceRewardsSplitter` follows a _pull payment_ model. This means that payments are not automatically forwarded to the
 * accounts but kept in this contract, and the actual transfer is triggered as a separate step by calling the {release}
 * function.
 *
 * NOTE: This contract assumes that ERC20 tokens will behave similarly to native tokens (Ether). Rebasing tokens, and
 * tokens that apply fees during transfers, are likely to not be supported as expected.
 */
contract GovernanceRewardsSplitter is Ownable {
    IERC20 public constant governanceToken = IERC20(address(0x0));

    event NewSplitConfiguration(
        uint256 indexed currentConfig,
        address[] payees,
        uint256[] shares
    );
    event PayeeAdded(
        uint256 indexed currentConfig,
        address account,
        uint256 shares
    );
    event GovernanceTokenReleased(
        IERC20 governanceToken,
        address indexed to,
        uint256 amount
    );

    /// @dev Split configuration is ID based, whenever a new config is set currentConfig is incremented.
    uint256 public currentConfig;
    mapping(uint256 => address[]) public _configToPayees;
    mapping(uint256 => mapping(address => uint256)) public _configToShares;
    mapping(uint256 => uint256) public _configTotalShares;

    uint256 public governanceTokenTotalReleased;
    mapping(address => uint256) public accountToGovernanceTokenReleased;

    /**
     * @dev Creates an instance of `GovernanceRewardsSplitter` where each account in `payees` is assigned the number of shares at
     * the matching position in the `shares` array.
     *
     * All addresses in `payees` must be non-zero. Both arrays must have the same non-zero length, and there must be no
     * duplicates in `payees`.
     */
    constructor(address[] memory payees, uint256[] memory shares_) payable {
        require(
            payees.length == shares_.length,
            "GovernanceRewardsSplitter: payees and shares length mismatch"
        );
        require(payees.length > 0, "GovernanceRewardsSplitter: no payees");

        // Initial configuration ID will be 1 as setNewConfig will increment currentConfig
        currentConfig = 0;

        // This will set an initial configuration of payees and shares
        setNewConfig(payees, shares_);
    }

    /**
     * @dev Triggers a transfer to `account` of the amount of `governanceToken` tokens they are owed, according to their
     * percentage of the total shares and their previous withdrawals.
     */
    function release(address account) public virtual {
        require(
            _configToShares[currentConfig][account] > 0,
            "GovernanceRewardsSplitter: account has no shares"
        );

        uint256 payment = releasable(account);

        require(
            payment != 0,
            "GovernanceRewardsSplitter: account is not due payment"
        );

        // _erc20TotalReleased[governanceToken] is the sum of all values in _erc20Released[governanceToken].
        // If "_erc20TotalReleased[governanceToken] += payment" does not overflow, then "_erc20Released[governanceToken][account] += payment"
        // cannot overflow.
        governanceTokenTotalReleased += payment;
        unchecked {
            accountToGovernanceTokenReleased[account] += payment;
        }

        SafeERC20.safeTransfer(governanceToken, account, payment);
        emit GovernanceTokenReleased(governanceToken, account, payment);
    }

    /**
     * @dev Add a new payee to the contract.
     * @param account The address of the payee to add.
     * @param shares_ The number of shares owned by the payee.
     */
    function addPayee(address account, uint256 shares_) public onlyOwner {
        require(
            account != address(0),
            "GovernanceRewardsSplitter: account is the zero address"
        );
        require(shares_ > 0, "GovernanceRewardsSplitter: shares are 0");
        require(
            _configToShares[currentConfig][account] == 0,
            "GovernanceRewardsSplitter: account already has shares"
        );

        _configToPayees[currentConfig].push(account);
        _configToShares[currentConfig][account] = shares_;
        _configTotalShares[currentConfig] += shares_;
        emit PayeeAdded(currentConfig, account, shares_);
    }

    /**
     * @dev Sets a new payee and share config
     * @param payees The addresses of the payees to be set.
     * @param shares_ The number of shares owned respectively by each payee. (i.e shares_[0] is the amount owned by payees[0])
     */
    function setNewConfig(
        address[] memory payees,
        uint256[] memory shares_
    ) public onlyOwner {
        currentConfig++; // Start's this new splitter config round
        require(
            payees.length == shares_.length,
            "GovernanceRewardsSplitter: miss match between payees length and shares_ length"
        );
        require(payees.length > 0, "GovernanceRewardsSplitter: no payees");

        for (uint256 i = 0; i < payees.length; i++) {
            addPayee(payees[i], shares_[i]);
        }
        emit NewSplitConfiguration(currentConfig, payees, shares_);
    }

    /**
     * @dev Getter for current round's payees.
     */
    function currentPayees() public view returns (address[] memory) {
        return _configToPayees[currentConfig];
    }

    /**
     * @dev Getter for the current round's amount of shares held by an account.
     */
    function currentShares(address account) public view returns (uint256) {
        return _configToShares[currentConfig][account];
    }

    /**
     * @dev Getter for the total shares held by payees.
     */
    function currentTotalShares() public view returns (uint256) {
        return _configTotalShares[currentConfig];
    }

    /**
     * @dev Getter for the amount of payee's releasable `governanceToken` tokens.
     */
    function releasable(address account) public view returns (uint256) {
        uint256 totalReceived = governanceToken.balanceOf(address(this)) +
            governanceTokenTotalReleased;
        return
            _pendingPayment(
                account,
                totalReceived,
                accountToGovernanceTokenReleased[account]
            );
    }

    /**
     * @dev internal logic for computing the pending payment of an `account` given the governanceToken historical balances and
     * already released amounts.
     */
    function _pendingPayment(
        address account,
        uint256 totalReceived,
        uint256 alreadyReleased
    ) private view returns (uint256) {
        return
            (totalReceived * _configToShares[currentConfig][account]) /
            _configTotalShares[currentConfig] -
            alreadyReleased;
    }
}
