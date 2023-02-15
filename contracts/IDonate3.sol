// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./Donate3Storage.sol";

interface IDonate3 {

    function getProjectList(address owner)
        external
        view
        returns (Project[] memory);

    function mint(
        address owner,
        uint256 pid,
        address payable rAddress
    ) external;

    function burn(address owner, uint256 pid) external;

    function updateProjectReceive(
        address owner,
        uint256 pid,
        address payable rAddress
    ) external;

    function donateToken(
        uint256 pid,
        uint256 amountIn,
        address to,
        bytes calldata message,
        bytes32[] calldata _merkleProof
    ) external payable;

    function donateERC20(
        uint256 _pid,
        address _token,
        string calldata _tokenSymbol,
        uint256 _amountInDesired,
        address _to,
        bytes calldata _message,
        bytes32[] calldata _merkleProof
    ) external;

    function withDrawToken(address to, uint256 amount) external;

    function withDrawERC20(
        address token,
        string calldata symbol,
        address to,
        uint256 amount
    ) external;

    function withDrawERC20List(
        address[] calldata tokens,
        string[] calldata symbols,
        address to,
        uint256[] calldata amounts
    ) external;

    event HandleFeeChanged(address from, uint32 feeBefore, uint32 feeAfter);
    
    event FreeMerkleRootChanged(
        address from,
        bytes32 freeMerkleRootBefore,
        bytes32 freeMerkleRootAfter
    );
    
    event donateRecord(
        uint256 pid,
        address from,
        address to,
        bytes32 symbol,
        uint256 amount,
        bytes msg
    );
    
    event withDraw(string symbol, address from, address to, uint256 amount);

    error CallFailed();

}
