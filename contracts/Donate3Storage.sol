// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.17;

// Record
struct Record {
    bytes32 symbol;
    uint256 amount;
    uint64 timestamp;
    bytes msg;
}

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

contract Donate3Storage {
    string public tokenSymbol;

    uint32 public handlingFee;

    mapping(address => Project[]) public _ownedProjects;

    mapping(address => mapping(uint256 => Record[])) public _ownedRecords;

    bytes32 public freeMerkleRoot;

    uint256[49] private __gap;

}