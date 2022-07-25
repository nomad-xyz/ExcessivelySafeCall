// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.7.6;

import "ds-test/test.sol";
import "src/ExcessivelySafeCall.sol";

contract ContractTest is DSTest {
    using ExcessivelySafeCall for address;

    address target;
    CallTarget t;

    function returnSize() internal pure returns (uint256 _bytes) {
        assembly {
            _bytes := returndatasize()
        }
    }

    function setUp() public {
        t = new CallTarget();
        target = address(t);
    }

    function testCall() public {
        bool _success;
        bytes memory _ret;

        (_success, _ret) = target.excessivelySafeCall(
            100_000,
            0,
            0,
            abi.encodeWithSelector(CallTarget.one.selector)
        );
        assertTrue(_success);
        assertEq(_ret.length, 0);
        assertEq(t.called(), 1);

        (_success, _ret) = target.excessivelySafeCall(
            100_000,
            0,
            0,
            abi.encodeWithSelector(CallTarget.two.selector)
        );
        assertTrue(_success);
        assertEq(_ret.length, 0);
        assertEq(t.called(), 2);

        (_success, _ret) = target.excessivelySafeCall(
            100_000,
            0,
            0,
            abi.encodeWithSelector(CallTarget.any.selector, 5)
        );
        assertTrue(_success);
        assertEq(_ret.length, 0);
        assertEq(t.called(), 5);

        (_success, _ret) = target.excessivelySafeCall(
            100_000,
            69,
            0,
            abi.encodeWithSelector(CallTarget.payme.selector)
        );
        assertTrue(_success);
        assertEq(_ret.length, 0);
        assertEq(t.called(), 69);
    }

    function testStaticCall() public {
        bool _success;
        bytes memory _ret;

        (_success, _ret) = target.excessivelySafeStaticCall(
            100_000,
            0,
            abi.encodeWithSelector(CallTarget.two.selector)
        );
        assertEq(t.called(), 0, "t modified state");
        assertTrue(!_success, "staticcall should error on state modification");
    }

    function testCopy(uint16 _maxCopy, uint16 _requested) public {
        uint16 _toCopy = _maxCopy < _requested ? _maxCopy : _requested;

        bool _success;
        bytes memory _ret;

        (_success, _ret) = target.excessivelySafeCall(
            100_000,
            0,
            _maxCopy,
            abi.encodeWithSelector(CallTarget.retBytes.selector, uint256(_requested))
        );
        assertTrue(_success);
        assertEq(_ret.length, _toCopy, "return copied wrong amount");

        (_success, _ret) = target.excessivelySafeCall(
            100_000,
            0,
            _maxCopy,
            abi.encodeWithSelector(CallTarget.revBytes.selector, uint256(_requested))
        );
        assertTrue(!_success);
        assertEq(_ret.length, _toCopy, "revert copied wrong amount");
    }


    function testStaticCopy(uint16 _maxCopy, uint16 _requested) public {
        uint16 _toCopy = _maxCopy < _requested ? _maxCopy : _requested;

        bool _success;
        bytes memory _ret;

        (_success, _ret) = target.excessivelySafeStaticCall(
            100_000,
            _maxCopy,
            abi.encodeWithSelector(CallTarget.retBytes.selector, uint256(_requested))
        );
        assertTrue(_success);
        assertEq(_ret.length, _toCopy, "return copied wrong amount");

        (_success, _ret) = target.excessivelySafeStaticCall(
            100_000,
            _maxCopy,
            abi.encodeWithSelector(CallTarget.revBytes.selector, uint256(_requested))
        );
        assertTrue(!_success);
        assertEq(_ret.length, _toCopy, "revert copied wrong amount");
    }

    function testBadBehavior() public {
        bool _success;
        bytes memory _ret;

        (_success, _ret) = target.excessivelySafeCall(
            3_000_000,
            0,
            32,
            abi.encodeWithSelector(CallTarget.badRet.selector)
        );
        assertTrue(_success);
        assertEq(returnSize(), 1_000_000, "didn't return all");
        assertEq(_ret.length, 32, "revert didn't truncate");


        (_success, _ret) = target.excessivelySafeCall(
            3_000_000,
            0,
            32,
            abi.encodeWithSelector(CallTarget.badRev.selector)
        );
        assertTrue(!_success);
        assertEq(returnSize(), 1_000_000, "didn't return all");
        assertEq(_ret.length, 32, "revert didn't truncate");
    }

    function testStaticBadBehavior() public {
        bool _success;
        bytes memory _ret;

        (_success, _ret) = target.excessivelySafeStaticCall(
            2_002_000,
            32,
            abi.encodeWithSelector(CallTarget.badRet.selector)
        );
        assertTrue(_success);
        assertEq(returnSize(), 1_000_000, "didn't return all");
        assertEq(_ret.length, 32, "revert didn't truncate");

                (_success, _ret) = target.excessivelySafeStaticCall(
            2_002_000,
            32,
            abi.encodeWithSelector(CallTarget.badRev.selector)
        );
        assertTrue(!_success);
        assertEq(returnSize(), 1_000_000, "didn't return all");
        assertEq(_ret.length, 32, "revert didn't truncate");
    }

}


contract CallTarget {
    uint256 public called;
    constructor () {}

    function one() external {
        called = 1;
    }

    function two() external {
        called = 2;
    }

    function any(uint256 _num) external {
        called = _num;
    }

    function payme() external payable {
        called = msg.value;
    }

    function retBytes(uint256 _bytes) public pure {
        assembly {
            return(0, _bytes)
        }
    }

    function revBytes(uint256 _bytes) public pure {
        assembly {
            revert(0, _bytes)
        }
    }

    function badRet() external pure returns (bytes memory) {
        retBytes(1_000_000);
    }

    function badRev() external pure {
        revBytes(1_000_000);
    }
}
