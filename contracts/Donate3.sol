// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "./DonateTransaction.sol";
import "./IDonate3.sol";

contract Donate3 is Ownable, DonateTransaction, IDonate3 {
    using ECDSA for bytes32;
    using SafeMath for uint256;

    // fee
    address public feeTo;
    address public feeToSetter;
    uint256 handlingFee = 3;

    struct PidReceives {
        int8 count;
        mapping(uint256 => address) value;
    }

    // pid -> PidReceive
    mapping(address => PidReceives) public _ownedPids;

    bytes32 private freeMerkleRoot;

    mapping(address => uint256) public tokensReserve;

    event FreeMerkleRootChanged(bytes32 freeMerkleRoot);
    event donateRecord(uint256 pid, uint256 amount);

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "Donate3: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

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

    function setHandleFee(uint256 _fee) external {
        require(_fee < 1000, "Donate3: Fee out of range.");
        handlingFee = _fee;
    }

    function _exists(address owner, uint256 pid)
        internal
        view
        virtual
        returns (bool)
    {
        PidReceives storage model = _ownedPids[owner];
        if (model.count == 0) {
            return false;
        }
        return model.value[pid] != address(0);
    }

    function mint(
        address to,
        uint256 pid,
        address tokenReceive
    ) external {
        require(to != address(0), "Donate3: mint to the zero address");

        PidReceives storage model = _ownedPids[to];
        if (model.count > 0 && model.value[pid] != address(0)) {
            revert("Donate3: pid already minted");
        } else {
            model.count++;
            model.value[pid] = tokenReceive;
        }
    }

    function update(
        address from,
        uint256 pid,
        address tokenReceive
    ) external {
        PidReceives storage model = _ownedPids[from];
        if (model.count > 0 && model.value[pid] != address(0)) {
            model.value[pid] = tokenReceive;
        } else {
            revert("Donate3: pid is not exist");
        }
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

    function setAllowList(bytes32[] calldata merkleProof) public {}

    function donateETH(
        uint256 cid,
        uint256 amountIn,
        address payable to,
        bytes32[] calldata _merkleProof,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) external payable lock {
        address from = _msgSender();
        uint256 amountIn = msg.value;

        //        Transaction memory tx = Transaction({
        //            amount: amountIn,
        //            nonce: nonces[from]
        //        });
        //
        //        require(
        //            verify(from, metaTx, sigR, sigS, sigV),
        //            "Donate3: Signer and signature do not match"
        //        );
        //
        //        // increase nonce for user (to avoid re-use)
        //        nonces[from] = nonces[from].add(1);

        uint256 amountOut = amountIn;

        // transfer
        to.transfer(amountOut);

        // refund dust eth, if any
        if (msg.value > amountIn) {
            TransferHelper.safeTransferETH(msg.sender, msg.value - amountIn);
        }
    }

    function donate(
        uint256 cid,
        address token,
        uint256 amountIn,
        address to,
        bytes32[] calldata _merkleProof,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) external lock {
        address from = _msgSender();

        //        Transaction memory tx = Transaction({
        //            token: token,
        //            amount: amountIn,
        //            nonce: nonces[from]
        //        });
        //
        //        require(
        //            verify(from, metaTx, sigR, sigS, sigV),
        //            "Donate3: Signer and signature do not match"
        //        );
        //
        //        // increase nonce for user (to avoid re-use)
        //        nonces[from] = nonces[from].add(1);

        uint256 balanceBefore = IERC20(token).balanceOf(to);
        uint256 amountOut = amountIn;

        TransferHelper.safeTransferFrom(token, from, address(this), amountOut);
    }

    function withDraw() external {}
}
