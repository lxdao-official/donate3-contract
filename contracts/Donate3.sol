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

    // fee
    address public feeTo;
    address public feeToSetter;
    uint32 handlingFee = 5;

    //    // PidReceive
    //    struct PidReceives {
    //        int8 count;
    //        mapping(uint256 => address) value;
    //    }
    //    mapping(address => PidReceives) public _ownedPids;

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

    mapping(address => uint256) public tokensReserve;

    event FreeMerkleRootChanged(bytes32 freeMerkleRoot);
    event donateToken(
        uint256 pid,
        address from,
        address to,
        uint256 amount,
        bytes msg
    );
    event donateERC20(
        address from,
        uint256 pid,
        address to,
        uint256 amount,
        bytes32 msg
    );

    error CallFailed();

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    receive() external payable {
        //        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    fallback() external payable {
        //        emit fallbackCalled(msg.sender, msg.value, msg.data);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "Donate3: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "Donate3: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }

    function setHandleFee(uint32 _fee) external {
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

    function _emptyProject() internal returns (Project memory) {
        Project memory p = Project({
            pid: 0,
            rAddress: payable(address(0)),
            pause: false
        });
        return p;
    }

    function _findProject(address owner, uint256 pid)
        internal
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

    function _exists(address owner, uint256 pid) internal returns (bool) {
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
    ) external {
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

    function donateETH(
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

        console.log("amountOut:", amountOut);

        // transfer
        (bool success, ) = p.rAddress.call{value: amountOut}("");
        if (!success) {
            revert CallFailed();
        }

        // refund dust eth, if any
        if (msg.value > amountIn) {
            TransferHelper.safeTransferETH(from, msg.value - amountIn);
        }

        {
            Record[] storage records = _ownedRecords[to][pid];
            Record memory record = Record({
                symbol: "ETH",
                amount: amountOut,
                timestamp: uint64(block.timestamp),
                msg: message
            });
            records.push(record);
        }

        emit donateToken(pid, from, to, amountIn, message);
    }

    //    function donate(
    //        uint256 pid,
    //        address token,
    //        uint256 amountIn,
    //        uint32 _fee,
    //        address to,
    //        bytes32[] calldata _merkleProof,
    //        bytes32 message
    //    ) external nonReentrant {
    //        address from = _msgSender();
    //        require(from != to, "Donate3: The donor address is equal to receive");
    //
    //        require(amountIn > 0, "Donate3: Invalid input amount.");
    //        require(_fee < 1000 && _fee > 0, "Donate3: Fee out of range.");
    //
    //        uint32 fee = verifyFreeAllowList(to, _merkleProof) ? 0 : _fee;
    //        uint256 amountOut = amountIn.mul(uint256(1000).sub(fee)).div(1000);
    //        require(amountOut <= amountIn, "Donate3: Invalid output amount");
    //
    //        uint256 balanceBefore = IERC20(token).balanceOf(to);
    //
    //        TransferHelper.safeTransferFrom(token, from, address(this), amountOut);
    //
    //        emit donateToken(pid, from, to, amountIn, message);
    //    }

    function getRecords(address owner, uint256 pid)
        external
        view
        returns (Record[] memory)
    {
        return _ownedRecords[owner][pid];
    }

    function withDraw() external onlyOwner {}
}
