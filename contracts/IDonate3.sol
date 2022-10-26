// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IDonate3 {
    enum ProjectStatus {
        resume,
        suspend
    }

    // project
    struct Project {
        uint256 pid;
        address payable rAddress;
        ProjectStatus status;
    }

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
}
