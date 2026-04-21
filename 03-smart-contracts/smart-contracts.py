import os
from typing import Any

from dotenv import load_dotenv
from web3 import Web3


SEPOLIA_CHAIN_ID = 11155111


ERC20_ABI: list[dict[str, Any]] = [
    {
        "type": "function",
        "stateMutability": "view",
        "name": "name",
        "inputs": [],
        "outputs": [{"name": "", "type": "string"}],
    },
    {
        "type": "function",
        "stateMutability": "view",
        "name": "symbol",
        "inputs": [],
        "outputs": [{"name": "", "type": "string"}],
    },
    {
        "type": "function",
        "stateMutability": "view",
        "name": "balanceOf",
        "inputs": [{"name": "owner", "type": "address"}],
        "outputs": [{"name": "", "type": "uint256"}],
    },
    {
        "type": "function",
        "stateMutability": "nonpayable",
        "name": "transfer",
        "inputs": [
            {"name": "to", "type": "address"},
            {"name": "amount", "type": "uint256"},
        ],
        "outputs": [{"name": "", "type": "bool"}],
    },
]


def require_env(name: str, value: str | None) -> str:
    if not value:
        raise ValueError(f"ОТСУТСТВУЕТ ПЕРЕМЕННАЯ ОКРУЖЕНИЯ: {name}")
    return value


def parse_amount_units(raw: str) -> int:
    try:
        value = int(raw)
    except ValueError as error:
        raise ValueError(f"НЕКОРРЕКТНЫЙ TRANSFER_AMOUNT_UNITS: {raw}") from error

    if value < 0:
        raise ValueError("TRANSFER_AMOUNT_UNITS ДОЛЖЕН БЫТЬ >= 0")
    return value


def main() -> None:
    load_dotenv()

    rpc_url = require_env("RPC_URL", os.getenv("RPC_URL"))
    private_key = require_env("PRIVATE_KEY", os.getenv("PRIVATE_KEY"))
    token_address_raw = require_env("TOKEN_ADDRESS", os.getenv("TOKEN_ADDRESS"))
    transfer_amount_units = parse_amount_units(os.getenv("TRANSFER_AMOUNT_UNITS", "0"))

    w3 = Web3(Web3.HTTPProvider(rpc_url))
    account = w3.eth.account.from_key(private_key)
    my_address = account.address

    if not w3.is_address(token_address_raw):
        raise ValueError(f"НЕКОРРЕКТНЫЙ TOKEN_ADDRESS: {token_address_raw}")
    token_address = w3.to_checksum_address(token_address_raw)

    chain_id = w3.eth.chain_id

    if chain_id != SEPOLIA_CHAIN_ID:
        raise ValueError(
            f"НЕВЕРНАЯ СЕТЬ. ОЖИДАЛАСЬ SEPOLIA {SEPOLIA_CHAIN_ID}, ПОЛУЧЕНО {chain_id}"
        )

    token = w3.eth.contract(address=token_address, abi=ERC20_ABI)

    name = token.functions.name().call()
    symbol = token.functions.symbol().call()
    balance = token.functions.balanceOf(my_address).call()

    if transfer_amount_units == 0:
        return

    to_address_raw = require_env("TO_ADDRESS", os.getenv("TO_ADDRESS"))
    if not w3.is_address(to_address_raw):
        raise ValueError(f"НЕКОРРЕКТНЫЙ TO_ADDRESS: {to_address_raw}")
    to_address = w3.to_checksum_address(to_address_raw)

    nonce = w3.eth.get_transaction_count(my_address, "pending")

    tx_data = token.encode_abi("transfer", args=[to_address, transfer_amount_units])

    gas_estimate = w3.eth.estimate_gas(
        {
            "from": my_address,
            "to": token_address,
            "data": tx_data,
            "value": 0,
        }
    )

    latest_block = w3.eth.get_block("latest")
    base_fee = latest_block.get("baseFeePerGas")

    tx: dict[str, Any] = {
        "chainId": SEPOLIA_CHAIN_ID,
        "nonce": nonce,
        "to": token_address,
        "data": tx_data,
        "value": 0,
        "gas": gas_estimate,
    }

    if base_fee is None:
        tx["gasPrice"] = w3.eth.gas_price
    else:
        priority = w3.eth.max_priority_fee
        tx["maxPriorityFeePerGas"] = priority
        tx["maxFeePerGas"] = base_fee * 2 + priority

    signed = w3.eth.account.sign_transaction(tx, private_key=private_key)
    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)

    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)


if name == "main":
    try:
        main()
    except Exception:
        raise SystemExit(1)
