# Hyperlane Validator e Relayer sem Docker em VPS Linux

## Objetivo

Este tutorial mostra o processo completo para instalar, compilar, configurar e executar o Hyperlane Validator e Relayer em uma VPS Linux sem Docker.

O processo cobre:

- Compilação local do `validator`
- Compilação local do `relayer`
- Envio dos binários para a VPS
- Envio dos arquivos de configuração
- Envio da pasta `config` necessária para runtime
- Configuração do DB/cache em `/tmp/hyp`
- Execução com `systemd`
- Logs com `journalctl`
- Limite de logs em 3GB
- Comandos para iniciar, parar, reiniciar e verificar status

---

## 1. Estrutura usada

Na máquina local:

```bash
$HOME/hyperlane-monorepo
$HOME/hyperlane-bin
```

Na VPS:

```bash
/root/hyperlane-bin/
  validator
  relayer

/root/hyperlane-config/
  agent-config.testnet.json
  validator.terraclassic.json
  relayer-testnet.json

/root/hyperlane-runtime/
  config/

/tmp/hyp/
  validator/terraclassic-cache
  relayer/terraclassic-cache
```

---

## 2. Observação importante sobre o binário

Mesmo compilado, o Hyperlane Validator e Relayer não funcionam completamente isolados.

Eles precisam da pasta:

```bash
hyperlane-monorepo/rust/main/config
```

Na VPS, essa pasta será copiada para:

```bash
/root/hyperlane-runtime/config
```

Por isso os scripts executam dentro de:

```bash
/root/hyperlane-runtime
```

---

## 3. Instalar dependências na máquina local

No Ubuntu/WSL local:

```bash
sudo apt update && sudo apt upgrade -y

sudo apt install -y \
  build-essential \
  pkg-config \
  libssl-dev \
  git \
  curl \
  jq
```

Instalar Rust:

```bash
curl https://sh.rustup.rs -sSf | sh
source "$HOME/.cargo/env"
```

Confirmar:

```bash
rustc --version
cargo --version
```

---

## 4. Build do Validator

Criar o script:

```bash
cat > ~/build-validator.sh <<'EOF'
#!/bin/bash
set -e

REPO_DIR="$HOME/hyperlane-monorepo"
BIN_DIR="$HOME/hyperlane-bin"

echo "Build do validator..."

if [ ! -d "$REPO_DIR" ]; then
  echo "Repositório não encontrado. Clonando Hyperlane..."
  git clone https://github.com/hyperlane-xyz/hyperlane-monorepo.git "$REPO_DIR"
fi

cd "$REPO_DIR/rust/main/agents/validator"

cargo build --release

mkdir -p "$BIN_DIR"

cp "$REPO_DIR/rust/main/target/release/validator" "$BIN_DIR/validator"

chmod +x "$BIN_DIR/validator"

echo ""
echo "Validator gerado em:"
echo "$BIN_DIR/validator"
EOF

chmod +x ~/build-validator.sh
```

Executar:

```bash
~/build-validator.sh
```

---

## 5. Build do Relayer

Criar o script:

```bash
cat > ~/build-relayer.sh <<'EOF'
#!/bin/bash
set -e

REPO_DIR="$HOME/hyperlane-monorepo"
BIN_DIR="$HOME/hyperlane-bin"

echo "Build do relayer..."

if [ ! -d "$REPO_DIR" ]; then
  echo "Repositório não encontrado. Clonando Hyperlane..."
  git clone https://github.com/hyperlane-xyz/hyperlane-monorepo.git "$REPO_DIR"
fi

cd "$REPO_DIR/rust/main/agents/relayer"

cargo build --release

mkdir -p "$BIN_DIR"

cp "$REPO_DIR/rust/main/target/release/relayer" "$BIN_DIR/relayer"

chmod +x "$BIN_DIR/relayer"

echo ""
echo "Relayer gerado em:"
echo "$BIN_DIR/relayer"
EOF

chmod +x ~/build-relayer.sh
```

Executar:

```bash
~/build-relayer.sh
```

---

## 6. Arquivos necessários na máquina local

Antes de enviar para VPS, confirme:

```bash
ls -lah ~/hyperlane-bin/validator
ls -lah ~/hyperlane-bin/relayer
ls -lah ~/agent-config.testnet.json
ls -lah ~/validator.terraclassic.json
ls -lah ~/relayer-testnet.json
ls -lah ~/hyperlane-monorepo/rust/main/config
```

Arquivos esperados:

```bash
~/hyperlane-bin/validator
~/hyperlane-bin/relayer
~/agent-config.testnet.json
~/validator.terraclassic.json
~/relayer-testnet.json
~/hyperlane-monorepo/rust/main/config
```

---

## 7. Preparar a VPS

Conectar na VPS:

```bash
ssh root@IP_DA_VPS
```

Exemplo:

```bash
ssh root@31.97.91.4
```

Criar as pastas:

```bash
mkdir -p /root/hyperlane-bin
mkdir -p /root/hyperlane-config
mkdir -p /root/hyperlane-runtime

mkdir -p /tmp/hyp/validator/terraclassic-cache
mkdir -p /tmp/hyp/relayer/terraclassic-cache
```

Sair da VPS:

```bash
exit
```

---

## 8. Enviar binários para VPS

Na máquina local:

```bash
scp ~/hyperlane-bin/validator root@IP_DA_VPS:/root/hyperlane-bin/
scp ~/hyperlane-bin/relayer root@IP_DA_VPS:/root/hyperlane-bin/
```

Exemplo:

```bash
scp ~/hyperlane-bin/validator root@31.97.91.4:/root/hyperlane-bin/
scp ~/hyperlane-bin/relayer root@31.97.91.4:/root/hyperlane-bin/
```

---

## 9. Enviar arquivos de configuração

Na máquina local:

```bash
scp ~/agent-config.testnet.json root@IP_DA_VPS:/root/hyperlane-config/
scp ~/validator.terraclassic.json root@IP_DA_VPS:/root/hyperlane-config/
scp ~/relayer-testnet.json root@IP_DA_VPS:/root/hyperlane-config/
```

Exemplo:

```bash
scp ~/agent-config.testnet.json root@31.97.91.4:/root/hyperlane-config/
scp ~/validator.terraclassic.json root@31.97.91.4:/root/hyperlane-config/
scp ~/relayer-testnet.json root@31.97.91.4:/root/hyperlane-config/
```

---

## 10. Enviar runtime config para VPS

Na máquina local:

```bash
scp -r ~/hyperlane-monorepo/rust/main/config root@IP_DA_VPS:/root/hyperlane-runtime/
```

Exemplo:

```bash
scp -r ~/hyperlane-monorepo/rust/main/config root@31.97.91.4:/root/hyperlane-runtime/
```

Na VPS, deve existir:

```bash
/root/hyperlane-runtime/config
```

---

## 11. Dar permissão nos binários

Na VPS:

```bash
chmod +x /root/hyperlane-bin/validator
chmod +x /root/hyperlane-bin/relayer
```

Confirmar:

```bash
ls -lah /root/hyperlane-bin/
```

---

## 12. Ajustar DB/cache para `/tmp/hyp`

A documentação do Hyperlane mostra exemplos usando cache temporário em `/tmp/hyp`.

Isso evita crescimento indefinido do RocksDB em disco persistente.

Validator:

```bash
sed -i 's|/etc/data/db|/tmp/hyp/validator/terraclassic-cache|g' /root/hyperlane-config/validator.terraclassic.json
```

Relayer:

```bash
sed -i 's|/etc/data/db|/tmp/hyp/relayer/terraclassic-cache|g' /root/hyperlane-config/relayer-testnet.json
```

Criar pastas:

```bash
mkdir -p /tmp/hyp/validator/terraclassic-cache
mkdir -p /tmp/hyp/relayer/terraclassic-cache
```

---

## 13. Criar script `run-validator.sh`

Na VPS, substitua `SUA_ACCESS_KEY` e `SUA_SECRET_KEY` pelas credenciais AWS corretas:

```bash
cat > /root/run-validator.sh <<'EOF'
#!/bin/bash
set -e

echo "Iniciando validator..."

# AWS S3
export AWS_ACCESS_KEY_ID="SUA_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="SUA_SECRET_KEY"
export AWS_REGION="us-east-1"

# Hyperlane configs
export CONFIG_FILES="/root/hyperlane-config/agent-config.testnet.json,/root/hyperlane-config/validator.terraclassic.json"

# Cache temporário
export DB="/tmp/hyp/validator/terraclassic-cache"

mkdir -p "$DB"

cd /root/hyperlane-runtime

exec /root/hyperlane-bin/validator
EOF

chmod +x /root/run-validator.sh
```

---

## 14. Criar script `run-relayer.sh`

Na VPS, substitua `SUA_ACCESS_KEY` e `SUA_SECRET_KEY` pelas credenciais AWS corretas:

```bash
cat > /root/run-relayer.sh <<'EOF'
#!/bin/bash
set -e

echo "Iniciando relayer..."

# AWS S3
export AWS_ACCESS_KEY_ID="SUA_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="SUA_SECRET_KEY"
export AWS_REGION="us-east-1"

# Hyperlane configs
export CONFIG_FILES="/root/hyperlane-config/agent-config.testnet.json,/root/hyperlane-config/relayer-testnet.json"

# Cache temporário
export DB="/tmp/hyp/relayer/terraclassic-cache"

mkdir -p "$DB"

cd /root/hyperlane-runtime

exec /root/hyperlane-bin/relayer
EOF

chmod +x /root/run-relayer.sh
```

---

## 15. Teste manual do Validator

Na VPS:

```bash
/root/run-validator.sh
```

Se iniciar corretamente, pare com:

```bash
CTRL + C
```

---

## 16. Teste manual do Relayer

Na VPS:

```bash
/root/run-relayer.sh
```

Se iniciar corretamente, pare com:

```bash
CTRL + C
```

---

## 17. Criar serviço systemd do Validator

Na VPS:

```bash
cat > /etc/systemd/system/hyperlane-validator.service <<'EOF'
[Unit]
Description=Hyperlane Validator
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/hyperlane-runtime

ExecStart=/root/run-validator.sh

Restart=always
RestartSec=5

StandardOutput=journal
StandardError=journal

Environment=HOME=/root
Environment=RUST_LOG=warn

[Install]
WantedBy=multi-user.target
EOF
```

---

## 18. Criar serviço systemd do Relayer

Na VPS:

```bash
cat > /etc/systemd/system/hyperlane-relayer.service <<'EOF'
[Unit]
Description=Hyperlane Relayer
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/hyperlane-runtime

ExecStart=/root/run-relayer.sh

Restart=always
RestartSec=5

StandardOutput=journal
StandardError=journal

Environment=HOME=/root
Environment=RUST_LOG=warn

[Install]
WantedBy=multi-user.target
EOF
```

---

## 19. Recarregar systemd

```bash
systemctl daemon-reload
```

---

## 20. Habilitar inicialização automática

```bash
systemctl enable hyperlane-validator
systemctl enable hyperlane-relayer
```

---

## 21. Iniciar serviços

```bash
systemctl start hyperlane-validator
systemctl start hyperlane-relayer
```

---

## 22. Verificar status

```bash
systemctl status hyperlane-validator
systemctl status hyperlane-relayer
```

Resultado esperado:

```bash
Active: active (running)
```

---

## 23. Ver logs em tempo real

Validator:

```bash
journalctl -u hyperlane-validator -f
```

Relayer:

```bash
journalctl -u hyperlane-relayer -f
```

Para sair:

```bash
CTRL + C
```

---

## 24. Últimas linhas dos logs

Validator:

```bash
journalctl -u hyperlane-validator -n 100 --no-pager
```

Relayer:

```bash
journalctl -u hyperlane-relayer -n 100 --no-pager
```

---

## 25. Parar serviços

```bash
systemctl stop hyperlane-validator
systemctl stop hyperlane-relayer
```

---

## 26. Reiniciar serviços

```bash
systemctl restart hyperlane-validator
systemctl restart hyperlane-relayer
```

---

## 27. Verificar se iniciam com reboot

```bash
systemctl is-enabled hyperlane-validator
systemctl is-enabled hyperlane-relayer
```

Resultado esperado:

```bash
enabled
```

---

## 28. Controlar verbosidade dos logs (RUST_LOG)

O relayer e o validator do Hyperlane geram **~3.7 GB/dia** de logs quando rodando em nível `info`.

Defina `RUST_LOG=warn` para registrar apenas avisos e erros:

```bash
# Adicionar no arquivo .env ou no serviço systemd
RUST_LOG=warn
```

Níveis disponíveis (do mais silencioso ao mais verboso):
- `error` — apenas falhas críticas
- `warn` — avisos e erros (recomendado para produção)
- `info` — logs operacionais detalhados (~3.7 GB/dia — NÃO recomendado)
- `debug` — muito verboso, apenas para depuração pontual

---

## 29. Impedir que logs do relayer poluam o /var/log/syslog

O rsyslog captura todas as mensagens dos serviços systemd e as grava em `/var/log/syslog`.
Sem filtragem, o relayer pode lotar o disco com ~3.7 GB/dia mesmo com `RUST_LOG=warn`.

Criar um filtro no rsyslog para descartar mensagens do relayer e validator do syslog
(eles continuam acessíveis via `journalctl`):

```bash
cat > /etc/rsyslog.d/49-hyperlane-drop.conf <<'EOF'
# Drop relayer and validator messages from /var/log/syslog.
# Their logs are retained in the systemd journal (capped at 500 MB).
if $programname == "relayer" then stop
if $programname == "validator" then stop
EOF

systemctl restart rsyslog
```

---

## 30. Limitar logs do journalctl a 500 MB

Criar arquivo de configuração em `/etc/systemd/journald.conf.d/`:

```bash
mkdir -p /etc/systemd/journald.conf.d

cat > /etc/systemd/journald.conf.d/hyperlane.conf <<'EOF'
[Journal]
ForwardToSyslog=no
SystemMaxUse=500M
SystemKeepFree=500M
MaxRetentionSec=7day
EOF

systemctl restart systemd-journald
```

Verificar espaço:

```bash
journalctl --disk-usage
```

Forçar limpeza imediata mantendo no máximo 500 MB:

```bash
journalctl --rotate
journalctl --vacuum-size=500M
```

---

## 31. Como o journalctl limpa os logs

Com `SystemMaxUse=500M`, o Linux mantém no máximo 500 MB de logs.

Quando passa desse tamanho, ele remove os logs mais antigos primeiro automaticamente.

---

## 32. Corrigir logrotate para rotação diária

Por padrão, o logrotate rotaciona `/var/log/syslog` semanalmente com 4 cópias.
Para discos pequenos, configure para rotação diária com 7 dias de retenção:

```bash
cat > /etc/logrotate.d/rsyslog <<'EOF'
/var/log/syslog
/var/log/mail.log
/var/log/kern.log
/var/log/auth.log
/var/log/user.log
/var/log/cron.log
{
    rotate 7
    daily
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
EOF
```

---

## 33. Monitorar tamanho dos caches

Validator:

```bash
du -sh /tmp/hyp/validator/terraclassic-cache
```

Relayer:

```bash
du -sh /tmp/hyp/relayer/terraclassic-cache
```

---

## 34. Limpar cache temporário manualmente

Pare primeiro os serviços:

```bash
systemctl stop hyperlane-validator
systemctl stop hyperlane-relayer
```

Limpar cache:

```bash
rm -rf /tmp/hyp/validator/terraclassic-cache
rm -rf /tmp/hyp/relayer/terraclassic-cache

mkdir -p /tmp/hyp/validator/terraclassic-cache
mkdir -p /tmp/hyp/relayer/terraclassic-cache
```

Iniciar novamente:

```bash
systemctl start hyperlane-validator
systemctl start hyperlane-relayer
```

---

## 35. Resolver erro de LOCK no RocksDB

Erro comum:

```bash
LOCK: Resource temporarily unavailable
```

Isso significa que já existe outro processo usando o mesmo DB/cache.

Parar tudo:

```bash
systemctl stop hyperlane-validator
systemctl stop hyperlane-relayer

pkill -9 -f validator
pkill -9 -f relayer
```

Verificar:

```bash
ps -ef | grep -E 'validator|relayer'
```

Se ainda existir lock órfão:

```bash
rm -f /tmp/hyp/validator/terraclassic-cache/LOCK
rm -f /tmp/hyp/relayer/terraclassic-cache/LOCK
```

Reiniciar:

```bash
systemctl start hyperlane-validator
systemctl start hyperlane-relayer
```

---

## 36. Resolver erro de AWS credentials

Erro comum:

```bash
no providers in chain provided credentials
the credential provider was not enabled
```

Significa que o validator não recebeu as credenciais AWS.

Verifique o script:

```bash
cat /root/run-validator.sh
```

Deve conter:

```bash
export AWS_ACCESS_KEY_ID="SUA_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="SUA_SECRET_KEY"
export AWS_REGION="us-east-1"
```

Depois reinicie:

```bash
systemctl restart hyperlane-validator
```

---

## 37. Atualização futura dos binários

Na máquina local:

```bash
~/build-validator.sh
~/build-relayer.sh
```

Enviar novos binários:

```bash
scp ~/hyperlane-bin/validator root@IP_DA_VPS:/root/hyperlane-bin/
scp ~/hyperlane-bin/relayer root@IP_DA_VPS:/root/hyperlane-bin/
```

Na VPS:

```bash
chmod +x /root/hyperlane-bin/validator
chmod +x /root/hyperlane-bin/relayer

systemctl restart hyperlane-validator
systemctl restart hyperlane-relayer
```

---

## 38. Comandos principais

Status:

```bash
systemctl status hyperlane-validator
systemctl status hyperlane-relayer
```

Iniciar:

```bash
systemctl start hyperlane-validator
systemctl start hyperlane-relayer
```

Parar:

```bash
systemctl stop hyperlane-validator
systemctl stop hyperlane-relayer
```

Reiniciar:

```bash
systemctl restart hyperlane-validator
systemctl restart hyperlane-relayer
```

Logs em tempo real:

```bash
journalctl -u hyperlane-validator -f
journalctl -u hyperlane-relayer -f
```

Últimas linhas:

```bash
journalctl -u hyperlane-validator -n 100 --no-pager
journalctl -u hyperlane-relayer -n 100 --no-pager
```

Espaço usado pelos logs:

```bash
journalctl --disk-usage
```

Espaço usado pelo cache:

```bash
du -sh /tmp/hyp/validator/terraclassic-cache
du -sh /tmp/hyp/relayer/terraclassic-cache
```

---

## 39. Estrutura final da VPS

```bash
/root/hyperlane-bin/
  validator
  relayer

/root/hyperlane-config/
  agent-config.testnet.json
  validator.terraclassic.json
  relayer-testnet.json

/root/hyperlane-runtime/
  config/

/tmp/hyp/
  validator/terraclassic-cache
  relayer/terraclassic-cache

/etc/systemd/system/
  hyperlane-validator.service
  hyperlane-relayer.service
```

---

## 40. Recomendação final

Use sempre `systemd` para produção.

Evite `nohup` com arquivos `.log`, porque os logs podem crescer indefinidamente.

Com `systemd` e `journalctl`:

- os serviços reiniciam automaticamente
- iniciam junto com o servidor
- logs são gerenciados pelo Linux
- `RUST_LOG=warn` evita spam de INFO (~3.7 GB/dia)
- filtro rsyslog (`/etc/rsyslog.d/49-hyperlane-drop.conf`) mantém o syslog limpo
- limite de 500 MB no journal evita lotar o disco
- logrotate diário mantém o `/var/log/syslog` sob controle
- DB/cache fica em `/tmp/hyp`, evitando crescimento persistente
