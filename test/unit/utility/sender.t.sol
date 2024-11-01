pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./../../../src/lib/SenderSlot.sol";

contract SenderSlotTest is Test {
    function test_senderSlot() public {
        address sender = address(1);

        SenderSlot.set(sender);
        vm.assertEq(SenderSlot.get(), sender);

        SenderSlot.clear();
        vm.assertEq(SenderSlot.get(), address(0));
    }
}
