import os
import time
from dotenv import load_dotenv
from web3 import Web3

load_dotenv()

RPC_URL = os.getenv("RPC_URL")

if not RPC_URL:
    raise SystemExit("RPC_URL не найден")

w3 = Web3(Web3.HTTPProvider(RPC_URL))

ADDRESS = os.getenv("CHECK_ADDRESS", "0x0000000000000000000000000000000000000000")

def to_checksum(addr: str) -> str:
    return w3.to_checksum_address(addr)

def main():
    if not w3.is_connected():
        raise SystemExit("Нет подключения к RPC")

    print("Подключение установлено")

    print("Chain ID:", w3.eth.chain_id)
    print("Текущий блок:", w3.eth.block_number)

    addr = to_checksum(ADDRESS)
    balance = w3.eth.get_balance(addr)
    print("Баланс:", w3.from_wei(balance, "ether"), "ETH")

    gas_price = w3.eth.gas_price
    print("Газ:", w3.from_wei(gas_price, "gwei"), "GWEI")

    last_block = w3.eth.block_number

    while True:
        current_block = w3.eth.block_number
        if current_block != last_block:
            last_block = current_block
            print("Новый блок:", current_block)

        time.sleep(5)

if __name__ == "__main__":
    main()
