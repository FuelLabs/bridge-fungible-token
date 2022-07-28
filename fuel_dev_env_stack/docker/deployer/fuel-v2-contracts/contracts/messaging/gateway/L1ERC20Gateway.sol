// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFuelMessageInbox} from "../IFuelMessageInbox.sol";
import {FuelMessageSender} from "../FuelMessageSender.sol";
import {FuelMessageReceiver} from "../FuelMessageReceiver.sol";

/// @title L1ERC20Gateway
/// @notice The L1 side of the general ERC20 gateway with Fuel
/// @dev This contract can be used as a template for future gateways to Fuel
contract L1ERC20Gateway is
    FuelMessageSender,
    FuelMessageReceiver,
    Ownable,
    Pausable
{
    using SafeERC20 for IERC20;

    ///////////////
    // Constants //
    ///////////////

    /// @dev The predicate hash all outgoing messages will use as their owner
    bytes32 public immutable ERC20GATEWAY_MESSAGE_PREDICATE_HASH;

    /////////////
    // Storage //
    /////////////

    /// @notice Maps ERC20 tokens to Fuel tokens to balance of the ERC20 tokens deposited
    mapping(address => mapping(bytes32 => uint256)) public s_deposits;

    /////////////////
    // Constructor //
    /////////////////

    /// @notice Contract constructor to setup immutable values
    /// @param fuelMessageOutbox Address of the FuelMessageOutbox contract
    /// @param fuelMessageInbox Address of the FuelMessageInbox contract
    /// @param predicateHash The predicate hash to use as the sent message owner
    constructor(
        address fuelMessageOutbox,
        address fuelMessageInbox,
        bytes32 predicateHash
    )
        FuelMessageSender(fuelMessageOutbox)
        FuelMessageReceiver(fuelMessageInbox)
        Ownable()
    {
        ERC20GATEWAY_MESSAGE_PREDICATE_HASH = predicateHash;
    }

    //////////////////////
    // Public Functions //
    //////////////////////

    /// @notice Pause ERC20 transfers
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause ERC20 transfers
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Deposits the given tokens to an address on Fuel
    /// @param to Fuel account or contract to deposit tokens to
    /// @param tokenId ID of the token being transferred to Fuel
    /// @param fuelTokenId ID of the token on Fuel that represent the deposited tokens
    /// @param amount Amount of tokens to deposit
    /// @dev Made payable to reduce gas costs
    function deposit(
        bytes32 to,
        address tokenId,
        bytes32 fuelTokenId,
        uint256 amount
    ) external payable whenNotPaused {
        require(amount > 0, "Cannot deposit zero");

        //transfer tokens to this contract and update deposit balance
        IERC20(tokenId).safeTransferFrom(msg.sender, address(this), amount);
        s_deposits[tokenId][fuelTokenId] =
            s_deposits[tokenId][fuelTokenId] +
            amount;

        //send message to gateway on Fuel to finalize the deposit
        bytes memory data =
            abi.encodePacked(
                fuelTokenId,
                bytes32(uint256(uint160(tokenId))),
                bytes32(uint256(uint160(msg.sender))), //from
                to,
                bytes32(amount)
            );
        sendFuelMessageWithOwner(
            fuelTokenId,
            ERC20GATEWAY_MESSAGE_PREDICATE_HASH,
            data
        );
    }

    /// @notice Finalizes the withdrawal process from the Fuel side gateway contract
    /// @param to Account to send withdrawn tokens to
    /// @param tokenId ID of the token being withdrawn from Fuel
    /// @param amount Amount of tokens to withdraw
    /// @dev Made payable to reduce gas costs
    function finalizeWithdrawal(
        address to,
        address tokenId,
        uint256 amount
    ) external payable whenNotPaused onlyFromInbox {
        require(amount > 0, "Cannot withdraw zero");
        bytes32 fuelTokenId = IFuelMessageInbox(FUEL_INBOX).getMessageSender();

        //reduce deposit balance and transfer tokens (math will underflow if amount is larger than allowed)
        s_deposits[tokenId][fuelTokenId] =
            s_deposits[tokenId][fuelTokenId] -
            amount;
        IERC20(tokenId).safeTransfer(to, amount);
    }
}