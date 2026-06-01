# Hyperlane Configuration Files Guide

## Objective

This document explains how to configure the main Hyperlane configuration files used by the Validator and Relayer.

It covers:

- `agent-config.testnet.json`
- `validator.terraclassic-testnet.json`
- `relayer.testnet.json`
- DB/cache configuration
- S3 checkpoint syncer
- Validator private key
- Relayer private keys
- Whitelist routes
- `blocks` settings
- `index` settings

---

# 1. Configuration files overview

For this setup, the main configuration files are:

```bash
agent-config.testnet.json
validator.terraclassic-testnet.json
relayer.testnet.json
```

Recommended VPS location:

```bash
/root/hyperlane-config/
```

Example final structure:

```bash
/root/hyperlane-config/
  agent-config.testnet.json
  validator.terraclassic-testnet.json
  relayer.testnet.json
```

When running the agents, the files are loaded using `CONFIG_FILES`.

Validator:

```bash
export CONFIG_FILES="/root/hyperlane-config/agent-config.testnet.json,/root/hyperlane-config/validator.terraclassic-testnet.json"
```

Relayer:

```bash
export CONFIG_FILES="/root/hyperlane-config/agent-config.testnet.json,/root/hyperlane-config/relayer.testnet.json"
```

---

# 2. DB/cache recommendation

Hyperlane uses RocksDB locally for indexing and cache.

The default examples often show:

```json
"db": "/etc/data/db"
```

For this native binary setup without Docker, it is recommended to use temporary cache paths under `/tmp/hyp`.

Validator:

```json
"db": "/tmp/hyp/validator/terraclassic-cache"
```

Relayer:

```json
"db": "/tmp/hyp/relayer/terraclassic-cache"
```

Why this is recommended:

- Prevents persistent RocksDB growth.
- Avoids very large disk usage over time.
- Makes cache cleanup simple.
- Keeps Validator and Relayer DBs separated.
- Prevents RocksDB `LOCK` conflicts.

Create the directories:

```bash
mkdir -p /tmp/hyp/validator/terraclassic-cache
mkdir -p /tmp/hyp/relayer/terraclassic-cache
```

Important:

Validator and Relayer must not use the same DB path.

Wrong:

```json
"db": "/etc/data/db"
```

Correct:

```json
// Validator
"db": "/tmp/hyp/validator/terraclassic-cache"

// Relayer
"db": "/tmp/hyp/relayer/terraclassic-cache"
```

---

# 3. Validator configuration example

File:

```bash
validator.terraclassic-testnet.json
```

Example:

```json
{
  "db": "/tmp/hyp/validator/terraclassic-cache",
  "checkpointSyncer": {
    "type": "s3",
    "bucket": "hyperlane-validator-signatures-igorverasvalidador-terraclassic",
    "region": "us-east-1"
  },
  "originChainName": "terraclassictestnet",
  "validator": {
    "type": "hexKey",
    "key": "0xYOUR_PRIVATE_KEY_HERE"
  },
  "chains": {
    "terraclassictestnet": {
      "signer": {
        "type": "cosmosKey",
        "key": "0xYOUR_PRIVATE_KEY_HERE",
        "prefix": "terra"
      }
    }
  }
}
```

---

# 4. Validator configuration fields

## `db`

Local RocksDB cache path.

Recommended:

```json
"db": "/tmp/hyp/validator/terraclassic-cache"
```

Do not share this DB with the Relayer.

## `checkpointSyncer`

Defines where the validator publishes checkpoint signatures.

For AWS S3:

```json
"checkpointSyncer": {
  "type": "s3",
  "bucket": "hyperlane-validator-signatures-igorverasvalidador-terraclassic",
  "region": "us-east-1"
}
```

Fields:

- `type`: storage type. For this setup, use `s3`.
- `bucket`: AWS S3 bucket where validator signatures/checkpoints are published.
- `region`: AWS region where the bucket is hosted.

The server must have AWS credentials available.

Example in `/root/run-validator.sh`:

```bash
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"
export AWS_REGION="us-east-1"
```

If AWS credentials are missing, the validator may fail with:

```text
no providers in chain provided credentials
the credential provider was not enabled
```

## `originChainName`

The chain where this validator is validating messages.

Example:

```json
"originChainName": "terraclassictestnet"
```

This must match the chain name inside `agent-config.testnet.json`.

## `validator`

Validator key configuration.

Example:

```json
"validator": {
  "type": "hexKey",
  "key": "0xYOUR_PRIVATE_KEY_HERE"
}
```

This key is used by the validator for signing validator metadata/checkpoints.

Keep this key private.

## `chains`

Defines signer configuration for the origin chain.

For Terra Classic testnet:

```json
"chains": {
  "terraclassictestnet": {
    "signer": {
      "type": "cosmosKey",
      "key": "0xYOUR_PRIVATE_KEY_HERE",
      "prefix": "terra"
    }
  }
}
```

Fields:

- `type`: for Cosmos chains, use `cosmosKey`.
- `key`: private key.
- `prefix`: Bech32 prefix. For Terra Classic, use `terra`.

---

# 5. Relayer configuration example

File:

```bash
relayer.testnet.json
```

Example:

```json
{
  "db": "/tmp/hyp/relayer/terraclassic-cache",
  "relayChains": "terraclassictestnet,bsctestnet,solanatestnet,sepolia",
  "allowLocalCheckpointSyncers": "false",
  "gasPaymentEnforcement": [
    {
      "type": "none"
    }
  ],
  "whitelist": [
    {
      "originDomain": [
        1325
      ],
      "destinationDomain": [
        97
      ]
    },
    {
      "originDomain": [
        97
      ],
      "destinationDomain": [
        1325
      ]
    },
    {
      "originDomain": [
        1325
      ],
      "destinationDomain": [
        1399811150
      ]
    },
    {
      "originDomain": [
        1399811150
      ],
      "destinationDomain": [
        1325
      ]
    },
    {
      "originDomain": [
        1325
      ],
      "destinationDomain": [
        11155111
      ]
    },
    {
      "originDomain": [
        11155111
      ],
      "destinationDomain": [
        1325
      ]
    }
  ],
  "chains": {
    "bsctestnet": {
      "signer": {
        "type": "hexKey",
        "key": "0xYOUR_PRIVATE_KEY_HERE"
      }
    },
    "solanatestnet": {
      "signer": {
        "type": "hexKey",
        "key": "0xYOUR_PRIVATE_KEY_HERE"
      }
    },
    "terraclassictestnet": {
      "signer": {
        "type": "cosmosKey",
        "key": "0xYOUR_PRIVATE_KEY_HERE",
        "prefix": "terra"
      }
    },
    "sepolia": {
      "signer": {
        "type": "hexKey",
        "key": "0xYOUR_PRIVATE_KEY_HERE"
      }
    }
  }
}
```

---

# 6. Relayer configuration fields

## `db`

Local RocksDB cache path.

Recommended:

```json
"db": "/tmp/hyp/relayer/terraclassic-cache"
```

Do not use the same DB as the Validator.

## `relayChains`

Defines the chains the Relayer will monitor and relay between.

Example:

```json
"relayChains": "terraclassictestnet,bsctestnet,solanatestnet,sepolia"
```

The names must match the chain names defined in `agent-config.testnet.json`.

## `allowLocalCheckpointSyncers`

Example:

```json
"allowLocalCheckpointSyncers": "false"
```

Recommended for production-like setups:

```json
"allowLocalCheckpointSyncers": "false"
```

This avoids using local checkpoint syncers and forces the relayer to use configured remote checkpoint syncers such as S3.

## `gasPaymentEnforcement`

Example:

```json
"gasPaymentEnforcement": [
  {
    "type": "none"
  }
]
```

This controls whether the Relayer enforces gas payment requirements before relaying messages.

For testing:

```json
"type": "none"
```

This means the relayer does not block messages based on gas payment enforcement.

For production, a stricter gas policy may be required depending on the project.

## `whitelist`

The whitelist controls which origin and destination domains the Relayer is allowed to relay.

Example:

```json
{
  "originDomain": [
    1325
  ],
  "destinationDomain": [
    97
  ]
}
```

This means:

```text
Allow messages from Terra Classic Testnet to BSC Testnet.
```

Domain examples:

```text
1325        = Terra Classic Testnet
97          = BSC Testnet
1399811150  = Solana Testnet
11155111    = Sepolia
```

Example routes:

```text
1325 -> 97
97 -> 1325

1325 -> 1399811150
1399811150 -> 1325

1325 -> 11155111
11155111 -> 1325
```

This is important because it prevents the relayer from processing unwanted routes.

## `chains`

Defines signer keys per chain.

For EVM chains such as BSC Testnet and Sepolia:

```json
"type": "hexKey"
```

For Cosmos chains such as Terra Classic:

```json
"type": "cosmosKey"
```

Terra Classic example:

```json
"terraclassictestnet": {
  "signer": {
    "type": "cosmosKey",
    "key": "0xYOUR_PRIVATE_KEY_HERE",
    "prefix": "terra"
  }
}
```

The relayer wallet must have enough native gas tokens on each chain it relays from.

Examples:

- BNB on BSC Testnet
- LUNC on Terra Classic Testnet
- SOL on Solana Testnet
- ETH on Sepolia

---

# 7. Agent config file

File:

```bash
agent-config.testnet.json
```

This file contains the chain registry used by the Validator and Relayer.

It defines:

- chain names
- domain IDs
- chain IDs
- protocols
- RPC URLs
- gas settings
- contract addresses
- index settings
- block confirmation settings

Example chain entry:

```json
"terraclassictestnet": {
  "name": "terraclassictestnet",
  "domainId": 1325,
  "chainId": "rebel-2",
  "protocol": "cosmos",
  "rpcUrls": [
    {
      "http": "https://rpc.luncblaze.com"
    }
  ],
  "bech32Prefix": "terra",
  "gasPrice": {
    "amount": "28.325",
    "denom": "uluna"
  },
  "mailbox": "0x...",
  "validatorAnnounce": "0x...",
  "interchainGasPaymaster": "0x...",
  "merkleTreeHook": "0x..."
}
```

---

# 8. Importance of `blocks`

Example:

```json
"blocks": {
  "confirmations": 1,
  "estimateBlockTime": 3,
  "reorgPeriod": 9
}
```

This block controls how the agent treats block finality and indexing.

## `confirmations`

Example:

```json
"confirmations": 1
```

Defines how many block confirmations are required before a block is considered safe to process.

Lower value:

- faster indexing
- faster message detection
- higher risk if the chain has reorgs

Higher value:

- safer
- slower processing

For testnet, `1` is commonly acceptable.

## `estimateBlockTime`

Example:

```json
"estimateBlockTime": 3
```

Estimated block time in seconds.

This helps the agent estimate sync progress and polling intervals.

Examples:

```text
Terra Classic Testnet: 3 seconds
BSC Testnet: 3 seconds
Solana Testnet: 0.4 seconds
```

If this value is wrong, estimated sync time and polling behavior may be inaccurate.

## `reorgPeriod`

Example:

```json
"reorgPeriod": 9
```

Defines how far back the agent should consider possible chain reorganizations.

A larger reorg period increases safety but may require more rechecking.

Recommended logic:

```text
reorgPeriod should be larger than confirmations.
```

For example:

```json
"confirmations": 1,
"reorgPeriod": 9
```

This means the agent processes quickly but still keeps a safety window for reorg handling.

For Terra Classic testnet, the example may use:

```json
"reorgPeriod": 1
```

For EVM testnets, a higher value such as `9` can be used.

---

# 9. Importance of `index`

Example:

```json
"index": {
  "from": 375964820,
  "chunk": 10
}
```

The `index` section defines where and how the agent starts indexing blockchain events.

## `from`

Example:

```json
"from": 375964820
```

This is the starting block or slot for event indexing.

> **IMPORTANT — Always check the current block height before starting the agents.**
>
> If `index.from` is set to a very old block, the agent must scan every block since then before becoming operational. On chains like Solana (300M+ slots) or BSC (40M+ blocks), this can take **many hours or even days**.
>
> **Always run `check-block-height.sh` before configuring `agent-config.json` for the first time or after a long downtime.**

### How to get the current block height

Run the provided script:

```bash
chmod +x check-block-height.sh
./check-block-height.sh
```

Or query each chain manually:

**Terra Classic:**
```bash
# Mainnet
curl -s https://terra-classic-rpc.publicnode.com:443/status | python3 -c \
  "import sys,json; print(json.load(sys.stdin)['result']['sync_info']['latest_block_height'])"

# Testnet
curl -s https://rpc.testnet.terraclassic.community/status | python3 -c \
  "import sys,json; print(json.load(sys.stdin)['result']['sync_info']['latest_block_height'])"
```

**Ethereum:**
```bash
# Mainnet
curl -s -X POST https://eth.llamarpc.com -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | \
  python3 -c "import sys,json; print(int(json.load(sys.stdin)['result'],16))"

# Sepolia testnet
curl -s -X POST https://1rpc.io/sepolia -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | \
  python3 -c "import sys,json; print(int(json.load(sys.stdin)['result'],16))"
```

**BSC:**
```bash
# Mainnet
curl -s -X POST https://bsc.drpc.org -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | \
  python3 -c "import sys,json; print(int(json.load(sys.stdin)['result'],16))"

# Testnet
curl -s -X POST https://bsc-testnet.drpc.org -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | \
  python3 -c "import sys,json; print(int(json.load(sys.stdin)['result'],16))"
```

**Solana:**
```bash
# Mainnet
curl -s -X POST https://api.mainnet-beta.solana.com -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getBlockHeight"}' | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['result'])"

# Testnet
curl -s -X POST https://api.testnet.solana.com -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getBlockHeight"}' | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['result'])"
```

### Setting `from` correctly

Copy the value returned by the commands above into the `index.from` field of each chain in `agent-config.json`.

If `from` is set too far in the past:

- the agent indexes too much history
- sync time increases significantly
- DB/cache grows faster

If `from` is set to a block slightly in the future:

- the agent may miss recent Hyperlane events
- use the **current block minus a small buffer** (e.g., current - 100) to be safe

Recommended:

```text
Use the current block height (or current - 100) when starting fresh.
Use the Hyperlane contract deployment block if you need to index historical messages.
```

## `chunk`

Example:

```json
"chunk": 10
```

Defines how many blocks/slots the agent indexes per request batch.

Small chunk:

- safer for unstable RPCs
- fewer timeout issues
- slower sync

Large chunk:

- faster sync
- may overload RPC
- may fail on slow endpoints

For unstable public RPCs, use:

```json
"chunk": 10
```

This is safer and reduces RPC errors.

---

# 10. Example `blocks` and `index` by chain

## BSC Testnet

```json
"blocks": {
  "confirmations": 1,
  "estimateBlockTime": 3,
  "reorgPeriod": 9
},
"index": {
  "from": 64000000,
  "chunk": 10
}
```

## Solana Testnet

```json
"blocks": {
  "confirmations": 1,
  "estimateBlockTime": 0.4,
  "reorgPeriod": 0
},
"index": {
  "from": 375964820,
  "chunk": 10
}
```

## Terra Classic Testnet

```json
"blocks": {
  "confirmations": 1,
  "estimateBlockTime": 3,
  "reorgPeriod": 1
},
"index": {
  "from": 28563839,
  "chunk": 10
}
```

---

# 11. Common mistakes

## Using the same DB for Validator and Relayer

Wrong:

```json
"db": "/etc/data/db"
```

Correct:

```json
// Validator
"db": "/tmp/hyp/validator/terraclassic-cache"

// Relayer
"db": "/tmp/hyp/relayer/terraclassic-cache"
```

If both use the same DB, this error may happen:

```text
LOCK: Resource temporarily unavailable
```

## Missing AWS credentials

If the Validator uses S3 checkpoint syncer, AWS credentials are required.

Error:

```text
no providers in chain provided credentials
the credential provider was not enabled
```

Fix:

```bash
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"
export AWS_REGION="us-east-1"
```

## Incorrect private key type

EVM chains:

```json
"type": "hexKey"
```

Cosmos chains:

```json
"type": "cosmosKey"
```

Terra Classic needs:

```json
"prefix": "terra"
```

## Incorrect `relayChains`

If the chain name is not present in `agent-config.testnet.json`, the Relayer will fail or ignore it.

Correct:

```json
"relayChains": "terraclassictestnet,bsctestnet,solanatestnet,sepolia"
```

The names must match exactly.

## Incorrect `from` index

If the `from` block is too old, indexing may be slow and cache may grow faster.

If it is too recent, the agent may miss events.

Use the Hyperlane deployment block or a block slightly before it.

---

# 12. Final recommended configuration paths

Validator config:

```bash
/root/hyperlane-config/validator.terraclassic-testnet.json
```

Relayer config:

```bash
/root/hyperlane-config/relayer.testnet.json
```

Agent config:

```bash
/root/hyperlane-config/agent-config.testnet.json
```

Validator DB/cache:

```bash
/tmp/hyp/validator/terraclassic-cache
```

Relayer DB/cache:

```bash
/tmp/hyp/relayer/terraclassic-cache
```

Runtime config:

```bash
/root/hyperlane-runtime/config
```

---

# 13. Final recommendation

Before starting the Validator or Relayer, always verify:

```bash
jq . /root/hyperlane-config/agent-config.testnet.json
jq . /root/hyperlane-config/validator.terraclassic-testnet.json
jq . /root/hyperlane-config/relayer.testnet.json
```

Check DB paths:

```bash
grep -R '"db"' /root/hyperlane-config/
```

Check chain names:

```bash
grep -R '"name"' /root/hyperlane-config/agent-config.testnet.json
```

Check services:

```bash
systemctl status hyperlane-validator
systemctl status hyperlane-relayer
```

Check logs:

```bash
journalctl -u hyperlane-validator -f
journalctl -u hyperlane-relayer -f
```
