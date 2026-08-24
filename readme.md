# Promover Usuário Windows para Administrador via Linux

> **Aviso:** Este procedimento modifica diretamente o banco de dados de contas locais do Windows (SAM). Faça backup dos seus dados antes de prosseguir.

## Pré-requisitos

* Um sistema Linux inicializado via Live USB (Ubuntu, Linux Mint, etc.).
* Acesso físico ao computador.
* Partição do Windows sem bloqueio por BitLocker.
* Permissões de administrador (sudo).

---

# Passo 1: Identificar a Partição do Windows

Antes de criar o script, descubra qual partição contém a instalação do Windows.

Execute:

```bash
lsblk -f
```

Exemplo de saída:

```text
NAME        FSTYPE LABEL
sda
├─sda1      FAT32
├─sda2      NTFS
└─sda3      ext4

nvme0n1
├─nvme0n1p1 FAT32
├─nvme0n1p2 NTFS
└─nvme0n1p3 NTFS
```

Localize a partição formatada em **NTFS** que contém o Windows.

Exemplos comuns:

```text
/dev/sda2
/dev/sdb1
/dev/nvme0n1p3
```

Anote esse valor para usar no script.

---

# Passo 2: Criar o Script

Crie o arquivo:

```bash
nano promote_win_admin.sh
```

Cole o conteúdo abaixo:

```bash
#!/bin/bash

# =======================================================
# Configuração da Partição do Windows
# =======================================================
# Altere abaixo para a partição correta
# Exemplo:
# /dev/sda2
# /dev/sdb1
# /dev/nvme0n1p3

WINDOWS_PART="/dev/sdXn"

echo "[+] Atualizando repositórios e instalando a ferramenta chntpw..."
sudo apt update && sudo apt install -y chntpw

echo "[+] Criando ponto de montagem e montando a partição do Windows..."
sudo mkdir -p /mnt/windows
sudo mount "$WINDOWS_PART" /mnt/windows

if [ $? -ne 0 ]; then
    echo "[-] Erro ao montar a partição."
    echo "[-] Verifique se WINDOWS_PART está configurado corretamente."
    exit 1
fi

echo "[+] Acessando o registro do Windows..."
cd /mnt/windows/Windows/System32/config

echo "[+] Promovendo a conta TIMS01..."
sudo chntpw -u "TIMS01" SAM

echo "[+] Desmontando a partição..."
cd ~
sudo umount /mnt/windows

echo "[+] Processo concluído."
echo "[+] Reiniciando em 5 segundos..."

sleep 5
sudo reboot
```

Salve o arquivo:

```text
Ctrl + O
Enter
```

Saia do editor:

```text
Ctrl + X
```

---

# Passo 3: Editar a Partição no Script

Abra novamente o arquivo:

```bash
nano promote_win_admin.sh
```

Localize a linha:

```bash
WINDOWS_PART="/dev/sdXn"
```

Substitua pelo identificador encontrado anteriormente.

Exemplos:

```bash
WINDOWS_PART="/dev/sda2"
```

ou

```bash
WINDOWS_PART="/dev/nvme0n1p3"
```

Salve e feche:

```text
Ctrl + O
Enter
Ctrl + X
```

---

# Passo 4: Dar Permissão de Execução

Execute:

```bash
chmod +x promote_win_admin.sh
```

---

# Passo 5: Executar o Script

Execute como administrador:

```bash
sudo ./promote_win_admin.sh
```

---

# O que o Script Faz

## 1. Instala o chntpw

```bash
sudo apt update && sudo apt install -y chntpw
```

Instala o utilitário **chntpw**, utilizado para acessar e modificar o banco de dados local de usuários do Windows.

---

## 2. Monta a Partição do Windows

```bash
sudo mount "$WINDOWS_PART" /mnt/windows
```

Monta a partição NTFS do Windows em:

```text
/mnt/windows
```

---

## 3. Acessa o Arquivo SAM

```bash
cd /mnt/windows/Windows/System32/config
```

O arquivo **SAM** contém as informações das contas locais do Windows.

---

## 4. Modifica o Usuário

```bash
sudo chntpw -u "TIMS01" SAM
```

Abre o banco de dados SAM para o usuário especificado.

---

## 5. Desmonta a Partição

```bash
sudo umount /mnt/windows
```

Garante que todas as alterações sejam gravadas corretamente.

---

## 6. Reinicia o Computador

```bash
sudo reboot
```

Reinicia o sistema após a conclusão do procedimento.

---

# Solução de Problemas

## Partição NTFS em Modo Somente Leitura

Erro semelhante a:

```text
The NTFS partition is in an unsafe state.
```

Desligue o Windows completamente:

1. Segure **Shift**.
2. Clique em **Desligar**.
3. Aguarde o desligamento completo.
4. Tente novamente pelo Linux.

---

## Fast Startup (Inicialização Rápida)

A Inicialização Rápida pode impedir a montagem correta da partição NTFS.

Desative em:

```text
Painel de Controle
→ Opções de Energia
→ Escolher a função dos botões de energia
→ Desativar Inicialização Rápida
```

---

## BitLocker

Se a unidade estiver protegida pelo BitLocker, o Linux não conseguirá acessar o arquivo SAM sem desbloqueá-la primeiro.

Será necessário:

```text
- Recuperar a chave do BitLocker
- Desbloquear a unidade
- Montar a partição
```

---

## Erro ao Montar a Partição

Verifique novamente a identificação do disco:

```bash
lsblk -f
```

Confirme que a variável:

```bash
WINDOWS_PART="..."
```

corresponde à partição correta.

---

# Observações

* Faça backup dos dados antes de qualquer alteração.
* Certifique-se de que a partição correta foi selecionada.
* Desative hibernação e Fast Startup para evitar problemas de montagem.
* Caso utilize BitLocker, desbloqueie a unidade antes de prosseguir.
