pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./../../../src/lib/SenderSlot.sol";

contract SenderSlotTest is Test {
    function test_senderSlot() public {
        address sender = address(1);
        
        SenderSlot.setSender(sender);
        vm.assertEq(SenderSlot.sender(), sender);
        
        SenderSlot.clearSender();
        vm.assertEq(SenderSlot.sender(), address(0));
    }
} 