// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./DonateTransaction.sol";
import "./IDonate3.sol";

import "hardhat/console.sol";

contract Donate3 is Ownable, IDonate3, ReentrancyGuard {
    using ECDSA for bytes32;
    using SafeMath for uint256;

    string public tokenSymbol;

    uint32 handlingFee = 5;

    // project
    struct Project {
        uint256 pid;
        address payable rAddress;
        bool pause;
    }

    // Record
    struct Record {
        bytes32 symbol;
        uint256 amount;
        uint64 timestamp;
        bytes msg;
    }

    mapping(address => Project[]) private _ownedProjects;

    mapping(address => mapping(uint256 => Record[])) private _ownedRecords;

    bytes32 private freeMerkleRoot;

    event FreeMerkleRootChanged(bytes32 freeMerkleRoot);
    event donateRecord(
        uint256 pid,
        address from,
        address to,
        bytes32 symbol,
        uint256 amount,
        bytes msg
    );
    event withDraw(string symbol, address to, uint256 amount);

    error CallFailed();

    constructor(string memory _tokenSymbol) {
        tokenSymbol = _tokenSymbol;
    }

    receive() external payable {
        //        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    fallback() external payable {
        //        emit fallbackCalled(msg.sender, msg.value, msg.data);
    }

    function setHandleFee(uint32 _fee) external onlyOwner {
        require(_fee < 1000, "Donate3: Fee out of range.");
        require(_fee != handlingFee, "Donate3: Fee is equal.");
        handlingFee = _fee;
    }

    function setFreeMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        freeMerkleRoot = _merkleRoot;
        emit FreeMerkleRootChanged(freeMerkleRoot);
    }

    function verifyFreeAllowList(address owner, bytes32[] calldata _merkleProof)
        internal
        view
        returns (bool)
    {
        bytes32 leaf = keccak256(abi.encodePacked(owner));
        return MerkleProof.verify(_merkleProof, freeMerkleRoot, leaf);
    }

    function getProjectList(address owner)
        external
        view
        returns (Project[] memory)
    {
        require(owner != address(0), "Donate3: owner is the zero address.");
        return _ownedProjects[owner];
    }

    function getProject(address owner, uint32 index)
        external
        view
        returns (Project memory)
    {
        require(owner != address(0), "Donate3: owner is the zero address.");
        return _ownedProjects[owner][index];
    }

    function _emptyProject() internal pure returns (Project memory) {
        Project memory p = Project({
            pid: 0,
            rAddress: payable(address(0)),
            pause: false
        });
        return p;
    }

    function _findProject(address owner, uint256 pid)
        internal
        view
        returns (Project memory)
    {
        require(owner != address(0), "Donate3: owner is the zero address");

        Project[] memory list = _ownedProjects[owner];
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i].pid == pid) {
                return list[i];
            }
        }
        return _emptyProject();
    }

    function _exists(address owner, uint256 pid) internal view returns (bool) {
        Project memory project = _findProject(owner, pid);
        return project.rAddress != address(0);
    }

    function mint(
        address owner,
        uint256 pid,
        address payable rAddress
    ) external {
        require(owner != address(0), "Donate3: owner is the zero address");
        require(!_exists(owner, pid), "Donate3: pid already minted");

        Project[] storage list = _ownedProjects[owner];
        Project memory p = Project({
            pid: pid,
            rAddress: rAddress,
            pause: false
        });
        list.push(p);
    }

    function updateProjectReceive(
        address owner,
        uint256 pid,
        address payable rAddress
    ) external view {
        require(
            owner != address(0) && rAddress != address(0),
            "Donate3: owner or receive is the zero address"
        );

        bool bSet = false;
        Project[] memory list = _ownedProjects[owner];
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i].pid == pid) {
                list[i].rAddress = rAddress;
                bSet = true;
                break;
            }
        }
        if (!bSet) {
            revert("Donate3: pid is not exist");
        }
    }

    function donateToken(
        uint256 pid,
        uint256 amountIn,
        address to,
        bytes calldata message,
        bytes32[] calldata _merkleProof
    ) external payable nonReentrant {
        address from = _msgSender();
        require(from != to, "Donate3: The donor address is equal to receive");

        require(amountIn > 0, "Donate3: Invalid input amount.");

        Project memory p = _findProject(to, pid);
        require(p.rAddress != address(0), "Donate3: The project is not exist");
        require(p.pause == false, "Donate3: The project is paused");

        uint32 fee = _merkleProof.length > 0 &&
            verifyFreeAllowList(from, _merkleProof)
            ? 0
            : handlingFee;

        uint256 amountOut = amountIn.mul(uint256(1000).sub(fee)).div(1000);
        require(amountOut <= amountIn, "Donate3: Invalid output amount");

        // transfer
        (bool success, ) = p.rAddress.call{value: amountOut}("");
        if (!success) {
            revert CallFailed();
        }

        // refund dust eth, if any
        if (msg.value > amountIn) {
            TransferHelper.safeTransferETH(from, msg.value - amountIn);
        }

        _record(from, to, pid, tokenSymbol, amountOut, message);
    }

    function donateERC20(
        uint256 _pid,
        address _token,
        string calldata _tokenSymbol,
        uint256 _amountInDesired,
        address _to,
        bytes calldata _message,
        bytes32[] calldata _merkleProof
    ) external nonReentrant {
        address from = _msgSender();
        string calldata symbol = _tokenSymbol;
        bytes calldata message = _message;
        uint256 pid = _pid;
        address token = _token;
        bytes32[] calldata merkleProof = _merkleProof;
        uint256 amountInDesired = _amountInDesired;

        address to = _to;
        require(from != to, "Donate3: The donor address is equal to receive");

        address rAddress;
        {
            Project memory project = _findProject(to, pid);
            require(
                project.rAddress != address(0),
                "Donate3: The project is not exist"
            );
            require(project.pause == false, "Donate3: The project is paused");
            rAddress = project.rAddress;
        }

        uint256 amountOut = _transferToken(
            token,
            from,
            amountInDesired,
            rAddress,
            merkleProof
        );

        // record
        _record(from, to, pid, symbol, amountOut, message);
    }

    function _transferToken(
        address token,
        address from,
        uint256 amountInDesired,
        address rAddress,
        bytes32[] calldata merkleProof
    ) internal returns (uint256 amountOut) {
        require(amountInDesired > 0, "Donate3: Invalid input amount.");

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));

        // transfer to contract
        TransferHelper.safeTransferFrom(
            token,
            from,
            address(this),
            amountInDesired
        );

        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        uint256 amountIn = balanceAfter - balanceBefore;
        amountOut = _getAmount(from, amountIn, merkleProof);
        require(amountOut <= amountIn, "Donate3: Invalid output amount");

        // transfer to user
        TransferHelper.safeApprove(token, rAddress, amountOut);
        TransferHelper.safeTransfer(token, rAddress, amountOut);
    }

    function _getAmount(
        address from,
        uint256 amountIn,
        bytes32[] calldata _merkleProof
    ) internal view returns (uint256) {
        uint32 fee = _merkleProof.length > 0 &&
            verifyFreeAllowList(from, _merkleProof)
            ? 0
            : handlingFee;
        uint256 amountOut = amountIn.mul(uint256(1000).sub(fee)).div(1000);
        return amountOut;
    }

    function _record(
        address from,
        address to,
        uint256 pid,
        string memory symbol,
        uint256 amountOut,
        bytes calldata message
    ) internal {
        bytes32 symbolBytes = stringToBytes32(symbol);
        Record[] storage records = _ownedRecords[to][pid];
        Record memory record = Record({
            symbol: symbolBytes,
            amount: amountOut,
            timestamp: uint64(block.timestamp),
            msg: message
        });
        records.push(record);

        emit donateRecord(pid, from, to, symbolBytes, amountOut, message);
    }

    function stringToBytes32(string memory source)
        private
        pure
        returns (bytes32 result)
    {
        assembly {
            result := mload(add(source, 32))
        }
    }

    function getRecords(address owner, uint256 pid)
        external
        view
        returns (Record[] memory)
    {
        return _ownedRecords[owner][pid];
    }

    function withDrawToken(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Donate3: ZERO_ADDRESS");
        require(
            amount > 0 && amount <= to.balance,
            "Donate3: Invalid input amount."
        );

        // transfer
        (bool success, ) = to.call{value: amount}("");
        if (!success) {
            revert CallFailed();
        }
        emit withDraw(tokenSymbol, to, amount);
    }

    function withDrawERC20(
        address token,
        string calldata symbol,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(to != address(0), "Donate3: ZERO_ADDRESS");

        uint256 balance = IERC20(token).balanceOf(address(this));
        require(
            amount > 0 && amount <= balance,
            "Donate3: Invalid input amount."
        );

        // transfer to user
        TransferHelper.safeApprove(token, to, amount);
        TransferHelper.safeTransfer(token, to, amount);

        emit withDraw(symbol, to, amount);
    }
}
