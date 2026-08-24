#!/bin/bash

# =======================================================
# Configuração da Partição do Windows
# =======================================================
# Altere abaixo para a partição correta (ex: /dev/sda2 ou /dev/nvme0n1p3)
WINDOWS_PART="/dev/"

echo "[+] Atualizando repositórios e instalando a ferramenta chntpw..."
sudo apt update && sudo apt install -y chntpw

echo "[+] Criando ponto de montagem e montando a partição do Windows..."
sudo mkdir -p /mnt/windows
sudo mount "$WINDOWS_PART" /mnt/windows

# Verifica se a montagem foi bem-sucedida
if [ $? -ne 0 ]; then
    echo "[-] Erro ao montar a partição. Verifique se o caminho em WINDOWS_PART está correto."
    exit 1
fi

echo "[+] Acessando o diretório do registro e promovendo a conta TIMS01 a Administrador..."
cd /mnt/windows/Windows/System32/config
sudo chntpw -u "TIMS01" SAM

echo "[+] Realizando a limpeza e desmontando a partição..."
cd ~
sudo umount /mnt/windows

echo "[+] Processo concluído com sucesso! O sistema será reiniciado em 5 segundos..."
sleep 5
sudo reboot