// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
contract Token {
    string public constant name = "Token";
    string public constant symbol = "L42";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    constructor(uint256 initialSupply) {
        _mint(msg.sender, initialSupply);
    }
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
    function allowance(address owner, address spender)
        external
        view
        returns (uint256)
    {
        return allowances[owner][spender];
    }
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }
    function approve(address spender, uint256 amount)
        external
        returns (bool)
    {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        uint256 currentAllowance = allowances[from][msg.sender];
        require(currentAllowance >= amount, "INSUFFICIENT_ALLOWANCE");
        allowances[from][msg.sender] = currentAllowance - amount;
        _transfer(from, to, amount);
        return true;
    }
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        require(to != address(0), "TRANSFER_TO_ZERO_ADDRESS");
        require(balances[from] >= amount, "INSUFFICIENT_BALANCE");
        balances[from] -= amount;
        balances[to] += amount;
        emit Transfer(from, to, amount);
    }
    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "MINT_TO_ZERO_ADDRESS");
        totalSupply += amount;
        balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }
}
