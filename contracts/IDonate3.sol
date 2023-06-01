// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// todo: withDraw -> withdraw
interface IDonate3 {
    // todo: 这两个是动词，状态应该是形容词，可以换成 active, suspended
    enum ProjectStatus {
        resume,
        suspend
    }

    // project
    // todo: 建议加入一些类似 project name 的字段，来让人可以分辨自己的项目
    // 否则一旦用户创建多个 project，但是忘记了 pid 的映射关系，那就完蛋了
    struct Project {
        uint256 pid;
        // todo: rAddress 是什么意思？receiptAddress 么？
        address payable rAddress;
        ProjectStatus status;
    }

    function getProjectList(address owner)
        external
        view
        returns (Project[] memory);

    // todo: mint 和 burn 建议换成 createProject 和 destroyProject
    // todo: prject 如果加入 name 那么可能可以把 pid 的分配放在合约内部？不需要用户自己指定 pid
    // 因为 pid 对用户来说维护成本太高
    function mint(
        address owner,
        uint256 pid,
        address payable rAddress
    ) external;

    function burn(address owner, uint256 pid) external;

    // todo: 改成 updateProjectRecipientAddress?
    function updateProjectReceive(
        address owner,
        uint256 pid,
        address payable rAddress
    ) external;


    // todo: -> donateETH?
    // todo: 其实一般来说, 都是指定 amountOut 或者叫 amountToDonate?
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

    // todo: -> withdrawETH?
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
