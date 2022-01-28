# ExcessivelySafeCall

This solidity library helps you call untrusted contracts safely. Specifically,
it seeks to prevent _all possible_ ways that the callee can maliciously cause
the caller to revert. Most of these revert cases are covered by the use of a
[low-level call](https://solidity-by-example.org/call/). The main difference
with between `address.call()`call and `address.excessivelySafeCall()` is that
a regular solidity call will **automatically** copy bytes to memory without
consideration of gas.

This is to say, a low-level solidity call will copy _any amount of bytes_ to
local memory. When bytes are copied from returndata to memory, the
[memory expansion cost
](https://ethereum.stackexchange.com/questions/92546/what-is-expansion-cost) is
paid. This means that when using a standard solidity call, the callee can
**"returnbomb"** the caller, imposing an arbitrary gas cost. Because this gas is
paid _by the caller_ and _in the caller's context_, it can cause the caller to
run out of gas and halt execution.

To prevent returnbombing, we provide `excessivelySafeCall` and
`excessivelySafeStaticCall`. These behave similarly to solidity's low-level
calls, however, they allow the user to specify a maximum number of bytes to be
copied to local memory. E.g. a user desiring a single return value should
specify a `_maxCopy` of 32 bytes. Refusing to copy large blobs to local memory
effectively prevents the callee from triggering local OOG reversion. We _also_ recommend careful consideration of the gas amount passed to untrusted
callees.

Consider the following contracts:

```solidity
contract BadGuy {
    function youveActivateMyTrapCard() external pure returns (bytes memory) {
        assembly{
            revert(0, 1_000_000)
        }
    }
}

contract Mark {
    function oops(address badGuy) {
        bool success;
        bytes memory ret;

        // Mark pays a lot of gas for this copy 😬😬😬
        (success, ret) == badGuy.call(
            SOME_GAS,
            abi.encodeWithSelector(
                BadGuy.youveActivateMyTrapCard.selector
            )
        );

        // Mark may OOG here, preventing local state changes
        importantCleanup();
    }
}

contract ExcessivelySafeSam {
    using ExcessivelySafeCall for address;

    // Sam is cool and doesn't get returnbombed
    function sunglassesEmoji(address badGuy) {
        bool success;
        bytes memory ret;

        (success, ret) == badGuy.excessivelySafeCall(
            SOME_GAS,
            32,  // <-- the magic. Copy no more than 32 bytes to memory
            abi.encodeWithSelector(
                BadGuy.youveActivateMyTrapCard.selector
            )
        );

        // Sam can afford to clean up after himself.
        importantCleanup();
    }
}
```

## When would I use this

`ExcessivelySafeCall` prevents malicious callees from affecting post-execution
cleanup (e.g. state-based replay protection). Given that a dev is unlikely to
hard-code a call to a malicious contract, we expect most danger to come from
dynamic dispatch protocols, where neither the callee nor the code being called
is known to the developer ahead of time.

Dynamic dispatch in solidity is probably _most_ useful for metatransaction
protocols. This includes gas-abstraction relayers, smart contract wallets,
bridges, etc.

Nomad uses excessively safe calls for safe processing of cross-domain messages.
This guarantees that a message recipient cannot interfere with safe operation
of the cross-domain communication channel and message processing layer.

## Interacting with the repo

**To install in your project**:

- install [Foundry](https://github.com/gakonst/foundry)
- `forge install nomad-xyz/ExcessivelySafeCall`

**To run tests**:

- install [Foundry](https://github.com/gakonst/foundry)
- `forge test`

## A note on licensing:

Tests are licensed GPLv3, as they extend the `DSTest` contract. Non-test work
is avialable under user's choice of MIT and Apache2.0.
