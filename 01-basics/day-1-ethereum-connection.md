# 📘 День 1: Подключение к Ethereum и базовые данные

## 🎯 Цель
научиться подключаться к сети Ethereum через RPC и получать базовые данные:
chain id
номер блока
баланс адреса
цену газа

## 🧠 Что происходит
ethereum — это распределённая сеть. Мы не подключаемся к ней напрямую, а используем RPC (Remote Procedure Call) — это точка доступа к ноде.
Через библиотеку web3.py мы отправляем запросы к ноде и получаем данные из блокчейна

По сути:
```наш код → RPC → нода → блокчейн → ответ → наш код```

## ⚙️ Подготовка
установи зависимости:
```pip install web3 python-dotenv```

Создай файл .env и добавь туда:
```python
RPC_URL=https://eth.llamarpc.com
CHECK_ADDRESS=0x0000000000000000000000000000000000000000
POLL_S=5
```

# 💻 Код
```python
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
```

## 🔍 Пошаговое объяснение

1. Загрузка переменных окружения
```load_dotenv() RPC_URL = os.getenv("RPC_URL") ```
Берём RPC_URL из .env. Это адрес ноды, через которую мы общаемся с сетью.
Если его нет — программа сразу останавливается.
2. Подключение к Ethereum
```w3 = Web3(Web3.HTTPProvider(RPC_URL)) ```
Создаём объект Web3.
Это основной инструмент для работы с блокчейном.
3. Проверка подключения
```if not w3.is_connected(): raise SystemExit("Нет подключения к RPC") ```
Проверяем, есть ли связь с нодой.
Если нет — дальше работать нет смысла.
4. Получение базовых данных
```print("Chain ID:", w3.eth.chain_id) print("Текущий блок:", w3.eth.block_number)```
chain_id показывает сеть (например 1 — mainnet)
block_number — номер последнего блока
5. Работа с адресом и балансом
``` addr = to_checksum(ADDRESS) balance = w3.eth.get_balance(addr)```
Адрес приводим к checksum формату — это важно для корректной работы
Баланс возвращается в wei (самая маленькая единица ETH)
w3.from_wei(balance, "ether") 
Переводим в ETH, чтобы было удобно читать
6. Цена газа
```gas_price = w3.eth.gas_price ```
Это текущая цена газа в сети
Переводим в GWEI:
w3.from_wei(gas_price, "gwei") 
7. Отслеживание новых блоков
```while True: current_block = w3.eth.block_number ```
Мы постоянно проверяем номер блока
if current_block != last_block: 
Если появился новый блок — выводим его
Это простой пример реального времени в блокчейне

## 🧪 Пример вывода
```python
Подключение установлено 
Chain ID: 1
Текущий блок: 19500000
Баланс: 0.0 ETH
Газ: 25 GWEI
Новый блок: 19500001
Новый блок: 19500002
```

## 🧠 Главная мысль
Ты не работаешь напрямую с блокчейном.
Ты работаешь через RPC → ноду → и получаешь данные.

Это база для всего:
dapps, ботов, аналитики, взаимодействия со смарт-контрактами
