# День 68: protocol launch checklist

## почему это важно

Deploy контракта  

это ещё не запуск протокола  

перед mainnet  

нужно проверить огромное количество вещей  

## что такое launch checklist

Это список проверок  

которые проходят перед запуском  

## зачем это нужно

в DeFi ошибки стоят дорого  

один пропущенный момент  

может привести к потере средств  

## что обычно проверяют

contracts  

roles  

multisig  

oracle  

vault  

upgrade system  

## проверка доступа

кто может  

pause  

upgrade  

mint  

withdraw  

## проверка env

RPC  

private keys  

адреса контрактов  

## проверка безопасности

reentrancy  

overflow  

DoS  

oracle manipulation  

## проверка экономики

reward system  

fees  

liquidation  

token emission  

## проверка инфраструктуры

monitoring  

alerting  

backup RPC  

indexer  

## важный момент

нужно тестировать  

не только обычные сценарии  

но и edge cases  

## что ещё важно

verify contracts  

настроить multisig  

проверить ownership  

## частая ошибка

запускать протокол  

сразу после deploy  

без полноценной проверки  

## пример из жизни

это как запуск самолёта  

перед взлётом  

проверяют каждую систему  

## главная мысль

launch checklist помогает  

не забыть критичные вещи  

перед mainnet запуском  

чем сложнее протокол  

тем важнее подготовка
