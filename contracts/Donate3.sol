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

    mapping(address => Project[]) private _ownedProjects;

    bytes32 private freeMerkleRoot;

    event HandleFeeChanged(address from, uint32 feeBefore, uint32 feeAfter);
    event FreeMerkleRootChanged(
        address from,
        bytes32 freeMerkleRootBefore,
        bytes32 freeMerkleRootAfter
    );
    event donateRecord(
        bytes pid,
        address from,
        address to,
        bytes32 symbol,
        uint256 amount,
        bytes msg
    );
    event withDraw(string symbol, address from, address to, uint256 amount);

    error CallFailed();

    constructor(string memory _tokenSymbol) {
        require(bytes(_tokenSymbol).length > 0, "Token symbol is empty.");
        tokenSymbol = _tokenSymbol;
    }

    receive() external payable {
        //        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    fallback() external payable {
        //        emit fallbackCalled(msg.sender, msg.value, msg.data);
    }

    function setHandleFee(uint32 _fee) external onlyOwner {
        require(_fee <= 200, "Fee out of range.");
        require(_fee != handlingFee, "Fee is equal.");

        emit HandleFeeChanged(_msgSender(), handlingFee, _fee);

        handlingFee = _fee;
    }

    function setFreeMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        emit FreeMerkleRootChanged(_msgSender(), freeMerkleRoot, _merkleRoot);

        freeMerkleRoot = _merkleRoot;
    }

    function _verifyFreeAllowList(
        address owner,
        bytes32[] calldata _merkleProof
    ) internal view returns (bool) {
        require(owner != address(0), "Owner is the zero address.");

        bytes32 leaf = keccak256(abi.encodePacked(owner));
        return MerkleProof.verify(_merkleProof, freeMerkleRoot, leaf);
    }

    function getProjectList(address owner)
        external
        view
        returns (Project[] memory)
    {
        require(owner != address(0), "Owner is the zero address.");
        return _ownedProjects[owner];
    }

    function _emptyProject() internal pure returns (Project memory) {
        Project memory p = Project({
            pid: bytes(""),
            rAddress: payable(address(0)),
            status: ProjectStatus.resume
        });
        return p;
    }

    function _findProject(address owner, bytes calldata pid)
        internal
        view
        returns (Project memory)
    {
        require(owner != address(0), "Owner is the zero address");

        Project[] memory list = _ownedProjects[owner];
        for (uint256 i = 0; i < list.length; i++) {
            if (keccak256(list[i].pid) == keccak256(pid)) {
                return list[i];
            }
        }
        return _emptyProject();
    }

    function _exists(address owner, bytes calldata pid)
        internal
        view
        returns (bool)
    {
        Project memory project = _findProject(owner, pid);
        return project.rAddress != address(0);
    }

    function mint(
        address owner,
        bytes calldata pid,
        address payable rAddress
    ) external {
        require(owner != address(0), "Owner is the zero address");
        require(!_exists(owner, pid), "Pid already minted");

        Project[] storage list = _ownedProjects[owner];
        Project memory p = Project({
            pid: pid,
            rAddress: rAddress,
            status: ProjectStatus.resume
        });
        list.push(p);
    }

    function burn(address owner, bytes calldata pid) external {
        require(owner != address(0), "Owner is the zero address");
        require(_exists(owner, pid), "Pid is not exist");

        _updateProject(owner, pid, payable(address(0)), ProjectStatus.suspend);
    }

    function updateProjectReceive(
        address owner,
        bytes calldata pid,
        address payable rAddress
    ) external {
        require(
            owner != address(0) && rAddress != address(0),
            "Owner or receive is the zero address"
        );

        _updateProject(owner, pid, rAddress, ProjectStatus.resume);
    }

    function _updateProject(
        address owner,
        bytes calldata pid,
        address payable rAddress,
        ProjectStatus status
    ) internal {
        bool bSet = false;
        Project[] storage list = _ownedProjects[owner];
        for (uint256 i = 0; i < list.length; i++) {
            Project storage project = list[i];
            if (keccak256(project.pid) == keccak256(pid)) {
                if (status == ProjectStatus.suspend) {
                    project.status = ProjectStatus.suspend;
                } else {
                    // update rAddress
                    project.rAddress = rAddress;
                }
                bSet = true;
                break;
            }
        }
        if (!bSet) {
            revert("Pid is not exist");
        }
    }

    function donateToken(
        bytes calldata pid,
        uint256 amountIn,
        address to,
        bytes calldata message,
        bytes32[] calldata _merkleProof
    ) external payable nonReentrant {
        address from = _msgSender();
        require(from != to, "The donor address is equal to receive");

        require(amountIn > 0, "Invalid input amount.");

        Project memory p = _findProject(to, pid);
        require(p.rAddress != address(0), "The project is not exist");
        require(p.status == ProjectStatus.resume, "The project is deleted");

        uint32 fee = _merkleProof.length > 0 &&
            _verifyFreeAllowList(from, _merkleProof)
            ? 0
            : handlingFee;

        uint256 amountOut = amountIn.mul(uint256(1000).sub(fee)).div(1000);
        require(amountOut <= amountIn, "Invalid output amount");

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
        bytes calldata _pid,
        address _token,
        string calldata _tokenSymbol,
        uint256 _amountInDesired,
        address _to,
        bytes calldata _message,
        bytes32[] calldata _merkleProof
    ) external nonReentrant {
        bytes calldata pid = _pid;
        string calldata symbol = _tokenSymbol;
        bytes calldata message = _message;
        address token = _token;
        bytes32[] calldata merkleProof = _merkleProof;
        uint256 amountInDesired = _amountInDesired;

        address to = _to;
        require(_msgSender() != to, "The donor address is equal to receive");

        address rAddress;
        {
            Project memory project = _findProject(to, pid);
            require(project.rAddress != address(0), "The project is not exist");
            require(
                project.status == ProjectStatus.resume,
                "The project is deleted"
            );
            rAddress = project.rAddress;
        }

        uint256 amountOut;
        {
            amountOut = _transferToken(
                token,
                _msgSender(),
                amountInDesired,
                rAddress,
                merkleProof
            );
        }

        // record
        _record(_msgSender(), to, pid, symbol, amountOut, message);
    }

    function _transferToken(
        address token,
        address from,
        uint256 amountInDesired,
        address rAddress,
        bytes32[] calldata merkleProof
    ) internal returns (uint256 amountOut) {
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
        require(amountOut <= amountIn, "Invalid output amount");

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
            _verifyFreeAllowList(from, _merkleProof)
            ? 0
            : handlingFee;
        uint256 amountOut = amountIn.mul(uint256(1000).sub(fee)).div(1000);
        return amountOut;
    }

    function _record(
        address from,
        address to,
        bytes calldata pid,
        string memory symbol,
        uint256 amountOut,
        bytes calldata message
    ) internal {
        bytes32 symbolBytes = stringToBytes32(symbol);
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

    function withDrawToken(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "ZERO_ADDRESS");
        require(amount > 0 && amount <= to.balance, "Invalid input amount.");

        // transfer
        (bool success, ) = to.call{value: amount}("");
        if (!success) {
            revert CallFailed();
        }
        emit withDraw(tokenSymbol, _msgSender(), to, amount);
    }

    function withDrawERC20List(
        address[] calldata tokens,
        string[] calldata symbols,
        address to,
        uint256[] calldata amounts
    ) external onlyOwner {
        require(to != address(0), "ZERO_ADDRESS");
        require(
            tokens.length == symbols.length && symbols.length == amounts.length,
            "Invalid input length"
        );

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            string memory symbol = symbols[i];
            uint256 amount = amounts[i];

            uint256 balance = IERC20(token).balanceOf(address(this));
            require(amount > 0 && amount <= balance, "Invalid input amount.");

            // transfer to user
            TransferHelper.safeApprove(token, to, amount);
            TransferHelper.safeTransfer(token, to, amount);

            emit withDraw(symbol, _msgSender(), to, amount);
        }
    }

    function withDrawERC20(
        address token,
        string calldata symbol,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(to != address(0), "ZERO_ADDRESS");

        uint256 balance = IERC20(token).balanceOf(address(this));
        require(amount > 0 && amount <= balance, "Invalid input amount.");

        // transfer to user
        TransferHelper.safeApprove(token, to, amount);
        TransferHelper.safeTransfer(token, to, amount);

        emit withDraw(symbol, _msgSender(), to, amount);
    }
}
