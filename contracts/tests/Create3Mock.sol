//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//import "../libraries/CREATE3.sol";

contract ERC20Mock is ERC20 {
    constructor(string memory name, string memory version)
        ERC20(name, version)
    {}

    function kill() external {
        selfdestruct(payable(msg.sender));
    }
}

interface IERC20Mock {
    function kill() external;
}

// contract Factory {
//     address public proxy;
//     address public deployed;

//     function deploy(string calldata name_, string calldata symbol_) external {
//         bytes32 salt = keccak256(abi.encodePacked(address(this)));
//         (deployed, proxy) = CREATE3.deploy(
//             salt,
//             abi.encodePacked(
//                 type(ERC20Mock).creationCode,
//                 abi.encode(name_, symbol_)
//             ),
//             0
//         );
//     }

//     function destroy() external {
//         IERC20Mock(deployed).kill();
//     }
// }
