// contracts/TokenVesting.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

error RedemptionAlreadyClaimed();
error TransferFailed();

/**
 * @title TokenVesting
 */
contract Vesting is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    struct VestingSchedule {
        bool initialized;
        // redeemer of tokens after they are redeemed
        address redeemer;
        // flexibility for contract to be revocable
        bool revocable;
        // total amount of tokens to be redeemed at the end of the vesting
        uint256 amountTotal;
        // amount of tokens redeemed
        uint256 redeemed;
        // whether or not the vesting has been revoked
        bool revoked;
    }

    // address of the ERC20 token
    IERC20 public _vestingToken;
    IERC20 public _rewardToken;

    bytes32[] private vestingSchedulesIds;
    mapping(bytes32 => VestingSchedule) private vestingSchedules;
    uint256 private vestingSchedulesTotalAmount;
    mapping(address => uint256) private holdersVestingCount;
    event Redeemed(address addr, uint256 amount);
    event Revoked();

    event RedemptionAttempt(address indexed user, uint256 indexed amount);

    /**
     * @dev Reverts if no vesting schedule matches the passed identifier.
     */
    modifier onlyIfVestingScheduleExists(bytes32 vestingScheduleId) {
        require(vestingSchedules[vestingScheduleId].initialized == true);
        _;
    }

    /**
     * @dev Reverts if the vesting schedule does not exist or has been revoked.
     */
    modifier onlyIfVestingScheduleNotRevoked(bytes32 vestingScheduleId) {
        require(vestingSchedules[vestingScheduleId].initialized == true);
        require(vestingSchedules[vestingScheduleId].revoked == false);
        _;
    }

    /**
     * @dev Creates a vesting contract.
     * @param vestingToken_ address of eBLU ERC20 token contract
     * @param rewardToken_ address of BLU ERC20 token contract
     */
    constructor(address vestingToken_, address rewardToken_) {
        require(vestingToken_ != address(0x0));
        _vestingToken = IERC20(vestingToken_);
        _rewardToken = IERC20(rewardToken_);
    }

    receive() external payable {}

    fallback() external payable {}

    /**
     * @dev Returns the number of vesting schedules associated to a redeemer.
     * @return the number of vesting schedules
     */
    function getVestingSchedulesCountByRedeemer(address _redeemer)
        public
        view
        returns (uint256)
    {
        return holdersVestingCount[_redeemer];
    }

    /**
     * @dev Returns the vesting schedule id at the given index.
     * @return the vesting id
     */
    function getVestingIdAtIndex(uint256 index)
        external
        view
        returns (bytes32)
    {
        require(
            index < getVestingSchedulesCount(),
            "TokenVesting: index out of bounds"
        );
        return vestingSchedulesIds[index];
    }

    /**
     * @notice Returns the vesting schedule information for a given holder and index.
     * @return the vesting schedule structure information
     */
    function getVestingScheduleByAddressAndIndex(address holder, uint256 index)
        public
        view
        returns (VestingSchedule memory)
    {
        return
            getVestingSchedule(
                computeVestingScheduleIdForAddressAndIndex(holder, index)
            );
    }

    /**
     * @notice Returns the total amount of vesting schedules.
     * @return the total amount of vesting schedules
     */
    function getVestingSchedulesTotalAmount() external view returns (uint256) {
        return vestingSchedulesTotalAmount;
    }

    /**
     * @dev Returns the address of the ERC20 token managed by the vesting contract.
     */
    function getToken() external view returns (address) {
        return address(_vestingToken);
    }

    /**
     * @notice Creates a new vesting schedule for a redeemer. The schedule is base on the supply of BLU.
     * @param _redeemer address of the redeemer to whom vested tokens are transferred
     * @param _revocable whether the vesting is revocable or not
     * @param _amount total amount of tokens to be redeemed at the end of the vesting
     */
    function createVestingSchedule(
        address _redeemer,
        bool _revocable,
        uint256 _amount
    ) public onlyOwner {
        require(
            _vestingToken.balanceOf(_redeemer) >= _amount,
            "TokenVesting: cannot create vesting schedule because redeemer has insufficient tokens"
        );
        require(_amount > 0, "TokenVesting: amount must be > 0");
        bytes32 vestingScheduleId = this.computeNextVestingScheduleIdForHolder(
            _redeemer
        );
        vestingSchedules[vestingScheduleId] = VestingSchedule(
            true,
            _redeemer,
            _revocable,
            _amount,
            0,
            false
        );
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.add(_amount);
        vestingSchedulesIds.push(vestingScheduleId);
        uint256 currentVestingCount = holdersVestingCount[_redeemer];
        holdersVestingCount[_redeemer] = currentVestingCount.add(1);
    }

    /**
     * @notice Revokes the vesting schedule for given identifier.
     * @param vestingScheduleId the vesting schedule identifier
     */
    function revoke(bytes32 vestingScheduleId)
        public
        onlyOwner
        onlyIfVestingScheduleNotRevoked(vestingScheduleId)
    {
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        require(
            vestingSchedule.revocable == true,
            "TokenVesting: vesting is not revocable"
        );
        uint256 vestedAmount = _computeRedemptionAmount(vestingSchedule);
        if (vestedAmount > 0) {
            release(vestingScheduleId, vestedAmount);
        }
        uint256 unreleased = vestingSchedule.amountTotal.sub(
            vestingSchedule.redeemed
        );
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.sub(
            unreleased
        );
        vestingSchedule.revoked = true;
    }

    /**
     * @notice Release vested amount of tokens.
     * @param vestingScheduleId the vesting schedule identifier
     * @param amount the amount to release
     */
    function release(bytes32 vestingScheduleId, uint256 amount)
        public
        nonReentrant
        onlyIfVestingScheduleNotRevoked(vestingScheduleId)
    {
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        bool isredeemer = msg.sender == vestingSchedule.redeemer;
        bool isOwner = msg.sender == owner();
        require(
            isredeemer || isOwner,
            "TokenVesting: only redeemer and owner can release vested tokens"
        );
        uint256 vestedAmount = _computeRedemptionAmount(vestingSchedule);
        require(
            vestedAmount >= amount,
            "TokenVesting: cannot release tokens, not enough vested tokens"
        );
        vestingSchedule.redeemed = vestingSchedule.redeemed.add(amount);
        address payable redeemerPayable = payable(vestingSchedule.redeemer);
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.sub(amount);
        _vestingToken.safeTransfer(redeemerPayable, amount);
    }

    /**
     * @dev Returns the number of vesting schedules managed by this contract.
     * @return the number of vesting schedules
     */
    function getVestingSchedulesCount() public view returns (uint256) {
        return vestingSchedulesIds.length;
    }

    /**
     * @notice Computes the vested amount of tokens for the given vesting schedule identifier.
     * @return the vested amount
     */
    function computeRedemptionAmount(bytes32 vestingScheduleId)
        public
        view
        onlyIfVestingScheduleNotRevoked(vestingScheduleId)
        returns (uint256)
    {
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        return _computeRedemptionAmount(vestingSchedule);
    }

    /**
     * @notice Returns the vesting schedule information for a given identifier.
     * @return the vesting schedule structure information
     */
    function getVestingSchedule(bytes32 vestingScheduleId)
        public
        view
        returns (VestingSchedule memory)
    {
        return vestingSchedules[vestingScheduleId];
    }

    /**
     * @dev Computes the next vesting schedule identifier for a given holder address.
     */
    function computeNextVestingScheduleIdForHolder(address holder)
        public
        view
        returns (bytes32)
    {
        return
            computeVestingScheduleIdForAddressAndIndex(
                holder,
                holdersVestingCount[holder]
            );
    }

    /**
     * @dev Returns the last vesting schedule for a given holder address.
     */
    function getLastVestingScheduleForHolder(address holder)
        public
        view
        returns (VestingSchedule memory)
    {
        return
            vestingSchedules[
                computeVestingScheduleIdForAddressAndIndex(
                    holder,
                    holdersVestingCount[holder] - 1
                )
            ];
    }

    /**
     * @dev Computes the vesting schedule identifier for an address and an index.
     */
    function computeVestingScheduleIdForAddressAndIndex(
        address holder,
        uint256 index
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(holder, index));
    }

    /**
     * @dev Computes the releasable amount of BLU tokens for a vesting schedule.
     *      1M BLU Supply -> 100k eBLU vested -> 1k BLU available to redeem
     *      100M BLU Supply -> 100k eBLU vested -> 100k BLU available to redeem
     *      No vested eBLU -> Nothing to redeem
     * @return the amount of releasable tokens
     */
    function _computeRedemptionAmount(VestingSchedule memory vestingSchedule)
        internal
        view
        returns (uint256)
    {
        if (vestingSchedule.revoked == true) {
            return 0;
        } else {
            uint256 redemptionAmount = SafeMath.mul(
                vestingSchedule.amountTotal,
                _computeRedemptionRate()
            );
            return SafeMath.div(redemptionAmount,100);
        }
    }

    /**
     * @dev Computes the redemption rate of BLU Tokens.
     *      Note the initial supply is at 1 million BLU Tokens.
     * @return the percentage of BLU tokens against 100 million cap
     */
    function _computeRedemptionRate() internal view returns (uint256) {
        if (_rewardToken.totalSupply() >= 100000000 * 10**18) {
            // 10**18 proxy for decimals()
            // if the cap == 100 Million, able to redeem fully
            return 1;
        }
        uint256 total_supply = SafeMath.mul(_rewardToken.totalSupply(), 100); // to counter floating point, precision to 2 decimals
        return SafeMath.div(total_supply, SafeMath.mul(100000000, 10**18)); // ensuring the numerator is more than the denominator
    }

    /**
     * @notice Redeem BLU tokens from this contract
     */
    function redeem(address payable redeemer) public payable {
        uint256 index = SafeMath.sub(
            getVestingSchedulesCountByRedeemer(redeemer),
            1
        ); // minus 1 for index
        bytes32 vestingScheduleId = computeVestingScheduleIdForAddressAndIndex(
            redeemer,
            index
        ); // bytes32 vesting id
        uint256 redemptionAmount = computeRedemptionAmount(vestingScheduleId); // calculate redemption amount
        uint256 redeemed = vestingSchedules[vestingScheduleId].redeemed; // amount that has already been redeemed
        if (redeemed == redemptionAmount) {
            revert RedemptionAlreadyClaimed();
        }
        uint256 toBeRedeemed = SafeMath.sub(redemptionAmount, redeemed);
        emit RedemptionAttempt(redeemer, toBeRedeemed);
        bool success = _rewardToken.transfer(redeemer, toBeRedeemed);
        if (!success) {
            revert TransferFailed();
        }
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        vestingSchedule.redeemed = toBeRedeemed;
        emit Redeemed(redeemer, toBeRedeemed);
    }
}
