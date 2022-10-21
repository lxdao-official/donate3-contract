// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DonateTransaction is EIP712 {
    using ECDSA for bytes32;
    using SafeMath for uint256;

    struct Transaction {
        address token;
        uint256 amount;
        uint256 nonce;
    }

    mapping(address => uint256) private nonces;

    constructor() EIP712("DonateTransaction", "0.0.1") {}

    function getNonce(address from) public view returns (uint256) {
        return nonces[from];
    }

    function hashTransaction(Transaction memory metaTx)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(metaTx.token, metaTx.amount, metaTx.nonce));
    }

    function verify(
        address signer,
        Transaction memory metaTx,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) internal view returns (bool) {
        require(signer != address(0), "NativeMetaTransaction: INVALID_SIGNER");
        return
            signer ==
            ecrecover(
                _hashTypedDataV4(hashTransaction(metaTx)),
                sigV,
                sigR,
                sigS
            );
    }
}
