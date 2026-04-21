from future import annotations

import os
import sys
from decimal import Decimal, InvalidOperation
from pathlib import Path

from dotenv import load_dotenv
from eth_account import Account
from eth_account.signers.local import LocalAccount
from web3 import Web3
from web3.exceptions import Web3RPCError


def env_flag(name: str, default: bool = False) -> bool:
 value = os.getenv(name)
 if value is None:
  return default
 return value.strip().lower() in {"1", "true", "yes", "on"}


def to_wei_from_env(name: str, default_eth: str) -> int:
 raw = os.getenv(name, default_eth).strip()
 try:
  return Web3.to_wei(Decimal(raw), "ether")
 except (InvalidOperation, ValueError) as exc:
  raise ValueError(f"{name} must be a valid ETH amount, got: {raw}") from exc


def upsert_env_values(env_path: Path, values: dict[str, str]) -> None:
 env_path.parent.mkdir(parents=True, exist_ok=True)
 if env_path.exists():
  lines = env_path.read_text(encoding="utf-8").splitlines()
 else:
  lines = []

 remaining = dict(values)
 updated_lines: list[str] = []
 for line in lines:
  stripped = line.strip()
  if not stripped or stripped.startswith("#") or "=" not in line:
   updated_lines.append(line)
   continue

  key, _, _ = line.partition("=")
  key = key.strip()
  if key in remaining:
   updated_lines.append(f"{key}={remaining.pop(key)}")
  else:
   updated_lines.append(line)

 for key, value in remaining.items():
  updated_lines.append(f"{key}={value}")

 env_path.write_text("\n".join(updated_lines) + "\n", encoding="utf-8")


def get_or_create_wallet(env_path: Path) -> tuple[LocalAccount, bool]:
 private_key = os.getenv("PRIVATE_KEY", "").strip()
 wallet_address = os.getenv("WALLET_ADDRESS", "").strip()

 if private_key and wallet_address:
  account = Account.from_key(private_key)
  if account.address.lower() != wallet_address.lower():
   upsert_env_values(env_path, {"WALLET_ADDRESS": account.address})
  return account, False

 new_account = Account.create()
 upsert_env_values(
  env_path,
  {
   "PRIVATE_KEY": new_account.key.hex(),
   "WALLET_ADDRESS": new_account.address,
  },
 )
 return new_account, True


def get_fee_params(w3: Web3) -> dict[str, int]:
 latest_block = w3.eth.get_block("latest")
 base_fee = latest_block.get("baseFeePerGas")

 if base_fee is None:
  gas_price = w3.eth.gas_price
  return {"gasPrice": gas_price}

 priority_fee = w3.eth.max_priority_fee
 max_fee = base_fee * 2 + priority_fee
 return {
  "maxPriorityFeePerGas": priority_fee,
  "maxFeePerGas": max_fee,
 }


def main() -> None:
 env_path = Path(file).with_name(".env")
 load_dotenv(dotenv_path=env_path)

 rpc_url = os.getenv("RPC_URL", "").strip()
 if not rpc_url:
  sys.exit(1)

 sender, created_now = get_or_create_wallet(env_path)
 if created_now:
  sys.exit(0)

 w3 = Web3(Web3.HTTPProvider(rpc_url))
 if not w3.is_connected():
  sys.exit(1)

 chain_id = w3.eth.chain_id
 nonce = w3.eth.get_transaction_count(sender.address, "pending")

 to_address = os.getenv("TO_ADDRESS", "").strip()
 if not to_address:
  to_address = sender.address

 if not Web3.is_address(to_address):
  sys.exit(1)

 amount_wei = to_wei_from_env("AMOUNT_ETH", "0.00001")
 to_checksum = Web3.to_checksum_address(to_address)

 tx_base = {
  "chainId": chain_id,
  "nonce": nonce,
  "from": sender.address,
  "to": to_checksum,
  "value": amount_wei,
 }

 gas_limit = int(os.getenv("GAS_LIMIT", "21000"))
 estimate_enabled = env_flag("ESTIMATE_GAS", default=True)
 if estimate_enabled:
  try:
   estimated = w3.eth.estimate_gas(tx_base)
   gas_limit = max(gas_limit, estimated)
  except Exception:
   pass

 fee_params = get_fee_params(w3)
 tx = {
  **tx_base,
  "gas": gas_limit,
  **fee_params,
 }

 sender_balance = w3.eth.get_balance(sender.address)
 if "maxFeePerGas" in tx:
  max_possible_fee = tx["gas"] * tx["maxFeePerGas"]
 else:
  max_possible_fee = tx["gas"] * tx["gasPrice"]
 max_total_cost = tx["value"] + max_possible_fee

 if sender_balance < max_total_cost:
  sys.exit(1)

 signed = w3.eth.account.sign_transaction(tx, sender.key)

 try:
  tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
 except Web3RPCError:
  sys.exit(1)

 w3.eth.wait_for_transaction_receipt(tx_hash, timeout=int(os.getenv("RECEIPT_TIMEOUT_SEC", "180")))


if name == "main":
 main()
