# Hyperlane Relayer API Guide

## Overview

The Hyperlane Relayer exposes an HTTP API that allows querying message relay operations and message status.

Official documentation:
https://docs.hyperlane.xyz/docs/operate/relayer/api

| Service | Port |
|----------|----------|
| Validator Metrics | 9090 |
| Relayer API | 9091 |

## Enable the Relayer API

Add:

```json
{
  "metricsPort": 9091
}
```

to relayer-testnet.json and restart:

```bash
systemctl restart hyperlane-relayer
```

Verify:

```bash
systemctl status hyperlane-relayer
ss -tulnp | grep 9091
```

Expected:

```text
0.0.0.0:9091
```

## API Examples

```bash
curl "http://127.0.0.1:9091/list_operations?destination_domain=97"
curl "http://127.0.0.1:9091/list_operations?destination_domain=1325"
curl "http://127.0.0.1:9091/list_operations?destination_domain=1399811150"
curl "http://127.0.0.1:9091/list_operations?destination_domain=11155111"
```

## Messages Endpoint

```bash
curl "http://127.0.0.1:9091/messages?domain_id=1325&nonce_start=1&nonce_end=200"
```

## Domain IDs

- Terra Classic Testnet: 1325
- BSC Testnet: 97
- Solana Testnet: 1399811150
- Ethereum Sepolia: 11155111

## Validator Metrics

```text
http://YOUR_SERVER_IP:9090/metrics
```

## Monitoring

```bash
systemctl status hyperlane-validator
journalctl -u hyperlane-validator -f

systemctl status hyperlane-relayer
journalctl -u hyperlane-relayer -f
```
