// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IDonate3 {
    enum ProjectStatus {
        resume,
        suspend
    }

    // project
    struct Project {
        bytes pid;
        address payable rAddress;
        ProjectStatus status;
    }

    function getProjectList(address owner)
        external
        view
        returns (Project[] memory);

    function mint(
        address owner,
        bytes calldata pid,
        address payable rAddress
    ) external;

    function burn(address owner, bytes calldata pid) external;

    function updateProjectReceive(
        address owner,
        bytes calldata pid,
        address payable rAddress
    ) external;

    function donateToken(
        bytes calldata pid,
        uint256 amountIn,
        address to,
        bytes calldata message,
        bytes32[] calldata _merkleProof
    ) external payable;

    function donateERC20(
        bytes calldata _pid,
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
}
