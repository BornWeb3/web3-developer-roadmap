# День 1: Подключение к Ethereum и базовые данные

## Цель
в этом уроке ты научишься подключаться к сети Ethereum через RPC и получать базовые данные: номер блока, баланс адреса и цену газа.

## Что происходит
ethereum — это распределенная сеть. Мы не подключаемся к ней напрямую, а используем RPC — это точка доступа к ноде. Через библиотеку web3 мы можем отправлять запросы и получать данные.

## Подготовка
установи зависимости:

pip install web3 python-dotenv

## Создай файл `.env` и добавь туда:

RPC_URL=https://eth.llamarpc.com
CHECK_ADDRESS=0x0000000000000000000000000000000000000000
POLL_S=5

## Код

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

## Объяснение
Cначала мы загружаем переменные окружения и берем RPC_URL. Это адрес ноды, через которую мы общаемся с сетью

Далее создаем объект Web3 — это наш инструмент для работы с Ethereum

Метод is_connected проверяет, есть ли связь с сетью. Если нет — программа останавливается

После этого мы получаем базовые данные: chain_id показывает, к какой сети мы подключены, block_number - номер последнего блока

Баланс адреса хранится в wei, поэтому мы переводим его в ether для удобства

Цена газа показывает стоимость транзакций в сети

В конце запускается цикл, который отслеживает появление новых блоков. Это позволяет видеть, как обновляется сеть в реальном времени

## Вывод

На этом этапе ты уже взаимодействуешь с реальным блокчейном и получаешь актуальные данные из сети
