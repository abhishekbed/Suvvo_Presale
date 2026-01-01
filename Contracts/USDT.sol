// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SUUVO is ERC20, Ownable {
    constructor() ERC20("SUUVO", "SUUVO") Ownable(msg.sender) {}

    function mint() public onlyOwner {
        _mint(msg.sender, 10000000000 * 10 ** decimals());
    }
}
