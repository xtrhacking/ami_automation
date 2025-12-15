# AMI Automator

Sistema de automação para criação de AMIs (Amazon Machine Images) usando Packer para laboratórios de segurança e ambientes de teste.

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Pré-requisitos](#pré-requisitos)
- [Instalação](#instalação)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Uso Rápido](#uso-rápido)
- [Comandos Disponíveis](#comandos-disponíveis)
- [Criando um Novo Laboratório](#criando-um-novo-laboratório)
- [Buildando AMIs](#buildando-amis)
- [Modo DRY RUN - Validação Rápida](#-modo-dry-run---validação-rápida)
- [Windows - Tratamento Automático de Restart](#-windows---tratamento-automático-de-restart)
- [Sistemas Operacionais Suportados](#sistemas-operacionais-suportados)
- [Configuração de Laboratórios](#configuração-de-laboratórios)
- [Tags e Metadados](#tags-e-metadados)
- [Testes](#-testes)
- [Documentação Adicional](#-documentação-adicional)
- [Contribuindo](#-contribuindo)
- [Troubleshooting](#-troubleshooting)
- [Suporte](#-suporte)

## 🎯 Visão Geral

Automação para gerar AMIs na AWS.

### Características Principais

- ✅ Suporte para múltiplos sistemas operacionais (Linux e Windows)
- ✅ Templates reutilizáveis e parametrizáveis
- ✅ Busca automática da AMI mais recente ou uso de AMI específica
- ✅ **Split automático de scripts Windows com Restart-Computer**
- ✅ **Modo DRY_RUN para validação rápida sem build**
- ✅ Configuração automática de WinRM para Windows (porta 5986, HTTPS)
- ✅ Tratamento de erro robusto (build falha se script falhar)

## 🔧 Pré-requisitos

### Ferramentas Necessárias

```bash
# macOS (usando Homebrew)
brew install awscli packer git yq python3

# Verificar instalação
aws --version
packer --version
git --version
yq --version
python3 --version
```

### Versões Recomendadas

- **AWS CLI**: >= 2.0
- **Packer**: >= 1.8.0
- **Git**: >= 2.0
- **yq**: >= 4.0
- **Python**: >= 3.8

### Credenciais AWS

Configure suas credenciais AWS:

```bash
# Opção 1: Configuração interativa
aws configure

# Opção 2: Variáveis de ambiente
export AWS_ACCESS_KEY_ID="sua-access-key"
export AWS_SECRET_ACCESS_KEY="sua-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Opção 3: AWS Profile
export AWS_PROFILE=nome-do-perfil
```

### Permissões IAM Necessárias

Sua conta AWS precisa das seguintes permissões:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CopyImage",
        "ec2:CreateImage",
        "ec2:CreateKeypair",
        "ec2:CreateSecurityGroup",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteKeyPair",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteSnapshot",
        "ec2:DeleteVolume",
        "ec2:DeregisterImage",
        "ec2:DescribeImageAttribute",
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeRegions",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSnapshots",
        "ec2:DescribeSubnets",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DetachVolume",
        "ec2:GetPasswordData",
        "ec2:ModifyImageAttribute",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifySnapshotAttribute",
        "ec2:RegisterImage",
        "ec2:RunInstances",
        "ec2:StopInstances",
        "ec2:TerminateInstances"
      ],
      "Resource": "*"
    }
  ]
}
```

## 📦 Instalação

```bash
# Clone o repositório
git clone https://github.com/xtrhacking/ami_automation.git
cd ami-automation

# Verifique os pré-requisitos
make check-prereqs

# Instale as dependências Python (cria ambiente virtual automaticamente)
make install-deps

# Verifique as credenciais AWS
make check-aws-creds
```

### Ambiente Virtual Python

O projeto utiliza um ambiente virtual Python (`venv`) para gerenciar dependências de forma isolada. Este ambiente é criado automaticamente quando você executa comandos que precisam dele.

**Criação automática:**
- O ambiente virtual é criado automaticamente ao executar `make build-ami`, `make init-lab`, ou `make add-os`
- Você também pode criá-lo manualmente com `make install-deps`

**Ativação manual (opcional):**
```bash
# Ativar o ambiente virtual
source venv/bin/activate

# Desativar o ambiente virtual
deactivate
```

**Nota:** Não é necessário ativar manualmente o ambiente virtual ao usar os comandos `make`. O Makefile já faz isso automaticamente.

## 📁 Estrutura do Projeto

```
ami-automation/
├── Makefile                       # Interface principal de comandos
├── README.md                      # Esta documentação
├── WINDOWS_RESTART_SUMMARY.md     # Resumo da implementação de restart
├── laboratory/                    # Diretório de laboratórios
│   ├── sql-injection/            # Exemplo de laboratório Linux
│   │   ├── userdata.sh           # Script de configuração
│   │   ├── variables.pkr.hcl     # Variáveis do Packer (auto-gerado)
│   │   ├── template.pkr.hcl      # Template do Packer (auto-gerado)
│   │   └── build-files/          # Arquivos para copiar para a AMI
│   │       ├── app.jar
│   │       └── config.json
│   ├── jekroast/                 # Exemplo de laboratório Windows
│   │   ├── userdata.ps1          # Script de configuração PowerShell
│   │   ├── split-userdata-1.ps1  # Part 1 (auto-gerado se houver restart)
│   │   ├── split-userdata-2.ps1  # Part 2 (auto-gerado se houver restart)
│   │   ├── variables.pkr.hcl     # Variáveis do Packer (auto-gerado)
│   │   ├── template.pkr.hcl      # Template do Packer (auto-gerado)
│   │   ├── packer-manifest.json  # Manifest de build (gerado após build)
│   │   └── build-files/          # Arquivos para copiar para a AMI
│   └── ...
├── scripts/                       # Scripts de automação
│   ├── generate_lab_files.py     # Gera arquivos HCL do Packer
│   ├── get_latest_ami.py         # Busca AMI mais recente
│   ├── add_os_mapping.py         # Adiciona novo OS
│   └── auto_split_restart.py     # Split automático de scripts Windows
├── templates/                     # Templates base
│   ├── template-linux.pkr.hcl.tpl    # Template Linux
│   ├── template-windows.pkr.hcl.tpl  # Template Windows com WinRM
│   ├── variables.pkr.hcl.tpl         # Template de variáveis
│   └── os-mappings.yaml              # Mapeamento de sistemas operacionais
├── docs/                          # Documentação adicional
│   ├── DRY_RUN.md                # Guia completo do DRY_RUN mode
│   └── WINDOWS_RESTART.md        # Guia de tratamento de Restart-Computer
├── tests/                         # Testes unitários
│   ├── test_auto_split_restart.py   # Testes de split de scripts
│   ├── test_generate_lab_files.py   # Testes de geração de arquivos
│   ├── test_get_latest_ami.py       # Testes de busca de AMI
│   └── test_add_os_mapping.py       # Testes de adição de OS
├── venv/                          # Ambiente virtual Python (auto-gerado)
├── requirements.txt               # Dependências Python
└── pytest.ini                     # Configuração de testes
```

## 🚀 Uso Rápido

```bash
# 1. Verificar pré-requisitos
make check-prereqs

# 2. Instalar dependências Python (cria ambiente virtual automaticamente)
make install-deps

# 3. Listar sistemas operacionais disponíveis
make list-os

# 4. Criar um novo laboratório
make init-lab FOLDER=meu-lab OS=ubuntu-24

# 5. Editar o script de configuração
vim laboratory/meu-lab/userdata.sh

# 6. Adicionar arquivos necessários
cp /path/to/files/* laboratory/meu-lab/build-files/

# 7. Validar configuração (opcional - apenas valida sintaxe HCL)
make validate FOLDER=meu-lab

# 8. Testar com DRY_RUN (recomendado - valida tudo sem build)
make build-ami FOLDER=meu-lab OS=ubuntu-24 DRY_RUN=true

# 9. Buildar a AMI
make build-ami FOLDER=meu-lab OS=ubuntu-24
```

## 📖 Comandos Disponíveis

### Ajuda e Informações

```bash
# Exibir ajuda completa
make help

# Listar laboratórios disponíveis
make list-labs

# Listar sistemas operacionais configurados
make list-os
```

### Gestão de Laboratórios

```bash
# Criar novo laboratório
make init-lab FOLDER=<nome> OS=<os-type>

# Exemplo
make init-lab FOLDER=web-security OS=ubuntu-24
```

### Validação e Build

```bash
# Validar configuração do Packer
make validate FOLDER=<nome>

# Validação completa sem executar o build (DRY_RUN)
make build-ami FOLDER=<nome> OS=<os-type> DRY_RUN=true

# Buildar AMI (AMI mais recente será usado)
make build-ami FOLDER=<nome> OS=<os-type>

# Buildar AMI com ID específico (útil para testar vulnerabilidades)
make build-ami FOLDER=<nome> OS=<os-type> AMI_ID=ami-0123456789abcdef0
```

### Dependências

```bash
# Instalar/atualizar dependências Python
make install-deps
```

### Limpeza

```bash
# Limpar arquivos temporários gerados
make clean
```

### Adicionar Novo OS

```bash
# Adicionar novo sistema operacional ao mapeamento
make add-os OS=<os-key>

# Exemplo
make add-os OS=ubuntu-26
```

## 🆕 Criando um Novo Laboratório

### Passo 1: Inicializar

```bash
make init-lab FOLDER=sql-injection OS=ubuntu-24
```

Este comando cria:
- `laboratory/sql-injection/` - Diretório do laboratório
- `laboratory/sql-injection/userdata.sh` - Script de configuração
- `laboratory/sql-injection/build-files/` - Diretório para arquivos
- `laboratory/sql-injection/variables.pkr.hcl` - Variáveis do Packer
- `laboratory/sql-injection/template.pkr.hcl` - Template do Packer

### Passo 2: Configurar o userdata.sh

Edite `laboratory/sql-injection/userdata.sh`:

```bash
#!/bin/bash
# Userdata script for sql-injection
# Lab: sql-injection
# OS: ubuntu-24

set -euo pipefail

echo "🚀 Starting lab setup: sql-injection"

# Build files estão disponíveis em: $BUILD_FILES
# Exemplo: sudo cp $BUILD_FILES/app.jar /opt/app.jar

# Atualizar sistema
sudo apt update
sudo apt install -y docker.io mysql-server

# Copiar aplicação vulnerável
sudo cp $BUILD_FILES/vulnerable-app.jar /opt/app.jar

# Configurar serviços
sudo systemctl enable docker
sudo systemctl start docker

# Deploy da aplicação
sudo docker run -d -p 8080:8080 -v /opt/app.jar:/app.jar openjdk:11 java -jar /app.jar

echo "✅ Lab setup completed"
```

### Passo 3: Adicionar Arquivos de Build

```bash
# Copiar arquivos necessários
cp /path/to/vulnerable-app.jar laboratory/sql-injection/build-files/
cp /path/to/config.json laboratory/sql-injection/build-files/
```

### Passo 4: Validar

```bash
make validate FOLDER=sql-injection
```

### Passo 5: Buildar

```bash
make build-ami FOLDER=sql-injection OS=ubuntu-24
```

## 🏗️ Buildando AMIs

### Build Padrão (AMI mais recente)

```bash
make build-ami FOLDER=meu-lab OS=ubuntu-24
```

O sistema automaticamente:
1. ✅ Busca a AMI mais recente do Ubuntu 24
2. ✅ Gera/atualiza os arquivos Packer necessários
3. ✅ Valida a configuração
4. ✅ Cria uma instância temporária
5. ✅ Executa o userdata.sh
6. ✅ Copia os build-files
7. ✅ Cria a AMI final
8. ✅ Limpa recursos temporários

### Build com AMI Específica

Para testar vulnerabilidades em versões específicas:

```bash
make build-ami FOLDER=security-test OS=ubuntu-22 AMI_ID=ami-0abcdef1234567890
```

**Casos de uso:**
- 🔍 Testar exploits em versões específicas
- 🐛 Reproduzir bugs conhecidos
- 📊 Comparar comportamento entre versões
- 🔐 Validar patches de segurança

### O que acontece durante o build?

```
┌─────────────────────────────────────┐
│  1. Validação de pré-requisitos     │
│     ✓ Ferramentas instaladas        │
│     ✓ Credenciais AWS válidas       │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  2. Preparação dos arquivos         │
│     ✓ Gera variables.pkr.hcl        │
│     ✓ Gera template.pkr.hcl         │
│     ✓ Busca/usa AMI especificada    │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  3. Packer Init & Validate          │
│     ✓ Baixa plugins necessários     │
│     ✓ Valida sintaxe HCL            │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  4. Build da AMI                    │
│     ✓ Cria instância EC2 temporária │
│     ✓ Copia build-files             │
│     ✓ Executa userdata.sh           │
│     ✓ Limpa dados sensíveis         │
│     ✓ Cria snapshot e AMI           │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  5. Finalização                     │
│     ✓ Adiciona tags                 │
│     ✓ Gera manifest.json            │
│     ✓ Exibe AMI ID                  │
└─────────────────────────────────────┘
```

## 🧪 Modo DRY RUN - Validação Rápida

O modo `DRY_RUN` permite validar toda a configuração **sem executar o build real da AMI**. Isso é útil para:

- ✅ Testar mudanças de configuração rapidamente
- ✅ Validar scripts antes de commit
- ✅ Debugar problemas de split de scripts Windows
- ✅ Verificar se templates são gerados corretamente
- ✅ Economia de tempo e custos AWS

### Uso

```bash
# Validação completa sem build
make build-ami FOLDER=meu-lab OS=ubuntu-24 DRY_RUN=true

# Também aceita valor numérico
make build-ami FOLDER=meu-lab OS=windows-server-2022 DRY_RUN=1
```

### O que é executado no DRY_RUN?

✅ **Executado:**
- Verificação de pré-requisitos (aws, packer, git, python3)
- Verificação de credenciais AWS
- Instalação de dependências Python
- Verificação de diretório do laboratório
- Verificação de script userdata (userdata.ps1 ou userdata.sh)
- **Processamento de scripts Windows** (split se houver Restart-Computer)
- Regeneração de arquivos Packer (variables.pkr.hcl, template.pkr.hcl)
- Verificação de configuração do OS
- `packer init` (inicialização de plugins)
- `packer validate` (validação da configuração)

❌ **Não executado:**
- `packer build` (criação real da AMI)

### Exemplo de Output

```
╔════════════════════════════════════════════════════════════════╗
║                   Building AMI                                 ║
╚════════════════════════════════════════════════════════════════╝

[INFO] Laboratory: jekroast
[INFO] OS: windows-server-2022
[INFO] Timestamp: 20251214-195500

[✓] Laboratory directory exists
[✓] userdata.ps1 exists
[INFO] Processing Windows PowerShell script...
INFO: Found 1 Restart-Computer command(s)
INFO: Splitting script into parts...
SUCCESS: Created 2 script parts
SUCCESS: Template updated with restart provisioners
[✓] Script processing completed
[⚠] Regenerating Packer files...
[✓] Generated variables.pkr.hcl
[✓] Generated template.pkr.hcl
[✓] OS configuration found

[INFO] Initializing Packer...
[INFO] Validating Packer configuration...
[✓] Validation passed!

╔════════════════════════════════════════════════════════════════╗
║                   DRY RUN MODE                                 ║
╚════════════════════════════════════════════════════════════════╝

[DRY-RUN] Skipping Packer build
[✓] All pre-build checks passed
[✓] Configuration validated
[✓] Scripts processed

[INFO] To execute the actual build, run:
      make build-ami FOLDER=jekroast
```

### Workflow Recomendado

```bash
# 1. DRY_RUN para validar configuração
make build-ami FOLDER=meu-lab DRY_RUN=true

# 2. Se validação passar, executar build real
make build-ami FOLDER=meu-lab
```

**Vantagens:**
- **Rápido**: DRY_RUN leva ~10-30 segundos vs 15-45 minutos do build completo
- **Econômico**: Não cria recursos AWS
- **Seguro**: Detecta erros antes do build real

Para mais detalhes, consulte: [`docs/DRY_RUN.md`](docs/DRY_RUN.md)

## 🪟 Windows - Tratamento Automático de Restart

Laboratórios Windows frequentemente precisam de **reinicializações** (ex: instalação do Active Directory). O sistema detecta automaticamente comandos `Restart-Computer` e divide o script em múltiplas partes.

### Como Funciona

**Seu script (`userdata.ps1`):**
```powershell
Write-Host "Installing AD Domain Services..."
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Import-Module ADDSDeployment

# Sistema detecta este restart automaticamente
Restart-Computer -Force

Write-Host "Creating domain..."
Install-ADDSForest -DomainName "lab.local" -SafeModeAdministratorPassword $password
```

**O que acontece automaticamente:**

1. ✅ Sistema detecta `Restart-Computer` no script
2. ✅ Divide em `split-userdata-1.ps1` (antes do restart) e `split-userdata-2.ps1` (depois do restart)
3. ✅ Atualiza `template.pkr.hcl` com provisioners de restart
4. ✅ **Preserva** o `userdata.ps1` original
5. ✅ Build executa: Part 1 → Restart Windows → Part 2

**Template gerado automaticamente:**
```hcl
# Execute part 1 of setup script
provisioner "powershell" {
  script = "${path.root}/split-userdata-1.ps1"
  environment_vars = [
    "LAB_NAME=jekroast",
    "OS_TYPE=windows-server-2022",
    "BUILD_FILES=C:\\temp\\build-files"
  ]

}

# Restart Windows
provisioner "windows-restart" {
  restart_timeout = "10m"
}

# Execute part 2 of setup script
provisioner "powershell" {
  script = "${path.root}/split-userdata-2.ps1"
  environment_vars = [
    "LAB_NAME=jekroast",
    "OS_TYPE=windows-server-2022",
    "BUILD_FILES=C:\\temp\\build-files"
  ]

}
```

### Características

- ✅ **Automático**: Não precisa fazer nada, funciona no `make build-ami`
- ✅ **Múltiplos restarts**: Suporta vários `Restart-Computer` no mesmo script
- ✅ **Preserva original**: O `userdata.ps1` não é modificado
- ✅ **Limpeza automática**: Remove arquivos split antigos antes de recriar
- ✅ **Timeout configurável**: 10 minutos por restart (ajustável)
- ✅ **Validação**: `packer validate` verifica a configuração gerada

### Múltiplos Restarts

```powershell
Write-Host "Part 1"
Install-WindowsFeature Web-Server
Restart-Computer -Force

Write-Host "Part 2"
Install-WindowsFeature RSAT-AD-Tools
Restart-Computer -Force

Write-Host "Part 3"
Configure-System
```

**Resultado:**
- `split-userdata-1.ps1` (Part 1)
- `split-userdata-2.ps1` (Part 2)
- `split-userdata-3.ps1` (Part 3)

Com 2 provisioners `windows-restart` entre eles.

### Configuração WinRM Automática

Todo laboratório Windows recebe automaticamente:

- ✅ WinRM habilitado com HTTPS (porta 5986)
- ✅ Certificado autoassinado configurado
- ✅ Firewall configurado
- ✅ TrustedHosts configurado
- ✅ Timeout: 10 minutos

**Não é necessário configurar WinRM manualmente!**

Para mais detalhes, consulte: [`docs/WINDOWS_RESTART.md`](docs/WINDOWS_RESTART.md)

## 💻 Sistemas Operacionais Suportados

Liste os sistemas disponíveis:

```bash
make list-os
```

### Sistemas Pré-configurados

| OS Key       | Nome                          | Tipo      | SSH User    |
|--------------|-------------------------------|-----------|-------------|
| ubuntu-25    | Ubuntu 25.04 LTS              | bash      | ubuntu      |
| ubuntu-24    | Ubuntu 24.04 LTS              | bash      | ubuntu      |
| ubuntu-22    | Ubuntu 22.04 LTS              | bash      | ubuntu      |
| ubuntu-20    | Ubuntu 20.04 LTS              | bash      | ubuntu      |
| debian-12    | Debian 12 (Bookworm)          | bash      | admin       |
| amazonlinux-2| Amazon Linux 2                | bash      | ec2-user    |
| amazonlinux-2023 | Amazon Linux 2023         | bash      | ec2-user    |
| rhel-9       | Red Hat Enterprise Linux 9    | bash      | ec2-user    |
| windows-2022 | Windows Server 2022           | powershell| Administrator|
| windows-2019 | Windows Server 2019           | powershell| Administrator|

### Adicionar Novo Sistema Operacional

```bash
# Adiciona interativamente
make add-os OS=ubuntu-26

# Você será solicitado a fornecer:
# - Nome completo do OS
# - Owner ID da AWS
# - Filtro de nome da AMI
# - Username SSH
# - Tipo de userdata (bash/powershell)
```

Ou edite manualmente `templates/os-mappings.yaml`:

```yaml
os_mappings:
  ubuntu-26:
    name: "Ubuntu 26.04 LTS"
    owner: "099720109477"  # Canonical
    filter: "ubuntu/images/hvm-ssd/ubuntu-noble-26.04-amd64-server-*"
    ssh_username: "ubuntu"
    user_data_type: "bash"
    communicator: "ssh"
```

## ⚙️ Configuração de Laboratórios

### Estrutura de um Laboratório

```
laboratory/meu-lab/
├── userdata.sh              # Script principal de configuração
├── variables.pkr.hcl        # Variáveis do Packer (auto-gerado)
├── template.pkr.hcl         # Template do Packer (auto-gerado)
├── packer-manifest.json     # Manifest de build (gerado após build)
└── build-files/             # Arquivos a serem copiados para a AMI
    ├── app/
    │   ├── server.jar
    │   └── config.json
    ├── scripts/
    │   └── startup.sh
    └── data/
        └── database.sql
```

### userdata.sh/ps1 - Variáveis Disponíveis

Dentro do `userdata.sh` (Linux) ou `userdata.ps1` (Windows), você tem acesso a:

**Linux (Bash):**
```bash
$LAB_NAME       # Nome do laboratório (ex: "sql-injection")
$OS_TYPE        # Tipo do OS (ex: "ubuntu-24")
$BUILD_FILES    # Caminho dos arquivos: /tmp/build-files
```

**Windows (PowerShell):**
```powershell
$env:LAB_NAME       # Nome do laboratório (ex: "jekroast")
$env:OS_TYPE        # Tipo do OS (ex: "windows-server-2022")
$env:BUILD_FILES    # Caminho dos arquivos: C:\temp\build-files
```

### Exemplo Completo: Laboratório Web Vulnerável

**userdata.sh:**
```bash
#!/bin/bash
set -euo pipefail

echo "🚀 Starting lab setup: $LAB_NAME"

# Instalar dependências
sudo apt update
sudo apt install -y apache2 php php-mysql mysql-server

# Configurar MySQL
sudo systemctl start mysql
sudo mysql -e "CREATE DATABASE vulnerable_db;"
sudo mysql -e "CREATE USER 'webapp'@'localhost' IDENTIFIED BY 'password123';"
sudo mysql -e "GRANT ALL PRIVILEGES ON vulnerable_db.* TO 'webapp'@'localhost';"

# Importar schema
sudo mysql vulnerable_db < $BUILD_FILES/database.sql

# Deploy da aplicação
sudo cp -r $BUILD_FILES/webapp/* /var/www/html/

# Configurar Apache
sudo systemctl enable apache2
sudo systemctl restart apache2

# Configurar permissões inseguras (para fins de lab)
sudo chmod 777 /var/www/html/uploads
sudo chown -R www-data:www-data /var/www/html

echo "✅ Lab setup completed"
echo "🌐 Application will be available at http://<instance-ip>/"
```

### Exemplo Completo: Laboratório Windows Active Directory

**userdata.ps1:**
```powershell
#
# Active Directory Lab Setup
# This script configures a Windows Server as a Domain Controller
#

$ErrorActionPreference = "Stop"

Write-Host "============================================"
Write-Host "Active Directory Lab Setup Started"
Write-Host "============================================"

# Disable Windows Defender (for lab purposes)
Write-Host "[*] Disabling Windows Defender..."
Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true

# Install Chocolatey
Write-Host "[*] Installing Chocolatey..."
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install required tools
Write-Host "[*] Installing tools..."
choco install sysinternals -y

# Rename computer
Write-Host "[*] Renaming computer to Lab-DC..."
Rename-Computer -NewName "Lab-DC" -Force

# Install Active Directory Domain Services
Write-Host "[*] Installing AD Domain Services..."
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Import-Module ADDSDeployment

# RESTART REQUIRED - System will automatically split here
Restart-Computer -Force

# Create domain (runs after restart)
Write-Host "[*] Creating domain LAB.local..."
$SecPassword = ConvertTo-SecureString "ComplexP@ssw0rd!" -AsPlainText -Force
Install-ADDSForest `
    -CreateDnsDelegation:$false `
    -DomainName "LAB.local" `
    -DomainNetbiosName "LAB" `
    -InstallDns:$true `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "7" `
    -ForestMode "7" `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion:$true `
    -SysvolPath "C:\Windows\SYSVOL" `
    -Force:$true `
    -SafeModeAdministratorPassword $SecPassword

# Wait for AD services
Write-Host "[*] Waiting for AD services..."
Start-Sleep -Seconds 60

# Add management tools
Write-Host "[*] Installing AD management tools..."
Add-WindowsFeature RSAT-AD-PowerShell
Add-WindowsFeature RSAT-AD-Tools
Import-Module ActiveDirectory

# Configure password policy (weak for lab)
Write-Host "[*] Configuring password policy..."
Set-ADDefaultDomainPasswordPolicy -Identity LAB.local `
    -ComplexityEnabled $false `
    -MinPasswordLength 1 `
    -PasswordHistoryCount 1 `
    -LockoutThreshold 1000

# Create OUs
Write-Host "[*] Creating Organizational Units..."
New-ADOrganizationalUnit -Name "Users" -Path "DC=LAB,DC=local"
New-ADOrganizationalUnit -Name "Computers" -Path "DC=LAB,DC=local"
New-ADOrganizationalUnit -Name "Admins" -Path "DC=LAB,DC=local"

# Create users
Write-Host "[*] Creating users..."
New-ADUser -Name "John Doe" `
    -SamAccountName "jdoe" `
    -UserPrincipalName "jdoe@LAB.local" `
    -Path "OU=Users,DC=LAB,DC=local" `
    -AccountPassword (ConvertTo-SecureString "Password123" -AsPlainText -Force) `
    -Enabled $true

New-ADUser -Name "Admin User" `
    -SamAccountName "labadmin" `
    -UserPrincipalName "labadmin@LAB.local" `
    -Path "OU=Admins,DC=LAB,DC=local" `
    -AccountPassword (ConvertTo-SecureString "AdminPass123!" -AsPlainText -Force) `
    -Enabled $true

Add-ADGroupMember -Identity "Domain Admins" -Members "labadmin"

# Copy lab files
Write-Host "[*] Copying lab files..."
if (Test-Path "$env:BUILD_FILES") {
    Copy-Item -Path "$env:BUILD_FILES\*" -Destination "C:\LabFiles\" -Recurse -Force
    Write-Host "[+] Lab files copied"
}

Write-Host "============================================"
Write-Host "Active Directory Lab Setup Completed!"
Write-Host "============================================"
Write-Host ""
Write-Host "Lab Details:"
Write-Host "  - Computer: Lab-DC"
Write-Host "  - Domain: LAB.local"
Write-Host "  - Admin: labadmin / AdminPass123!"
Write-Host ""
```

**O que acontece:**
1. Sistema detecta `Restart-Computer` automaticamente
2. Cria `split-userdata-1.ps1` (instalação do AD)
3. Cria `split-userdata-2.ps1` (configuração do domínio)
4. Build executa: Instala AD → Reinicia → Configura domínio

### variables.pkr.hcl - Customização

Você pode editar o arquivo gerado para ajustar:

```hcl
variable "instance_type" {
  type        = string
  description = "EC2 instance type for building the AMI"
  default     = "t3.large"  # Mudou de t3.medium para t3.large
}

variable "volume_size" {
  type        = number
  description = "Root volume size in GB"
  default     = 50  # Mudou de 30 para 50 GB
}
```

## 🏷️ Tags e Metadados

Toda AMI criada recebe automaticamente as seguintes tags:

| Tag              | Descrição                                    | Exemplo                              |
|------------------|----------------------------------------------|--------------------------------------|
| Name             | Nome da AMI com timestamp                    | lab-sql-injection-20250121-153045    |
| Lab              | Nome do lab com git hash                     | lab-sql-injection-a1b2c3d            |
| OS               | Sistema operacional usado                    | ubuntu-24                            |
| CreatedAt        | Timestamp de criação                         | 2025-01-21T15:30:45Z                 |
| CreatedBy        | Criador (sempre "packer")                    | packer                               |
| Environment      | Ambiente (sempre "laboratory")               | laboratory                           |
| ManagedBy        | Sistema gerenciador                          | v2-ami-automation                    |
| **SourceAmiId**  | ID da AMI source                             | ami-0abcdef1234567890                |
| **SourceAmiName**| Nome da AMI source                           | ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20231001 |

### Manifest File

Após cada build, um arquivo `packer-manifest.json` é gerado:

```json
{
  "builds": [
    {
      "name": "sql-injection-build",
      "builder_type": "amazon-ebs",
      "build_time": 1705849845,
      "files": null,
      "artifact_id": "us-east-1:ami-0123456789abcdef0",
      "packer_run_uuid": "abc123...",
      "custom_data": {
        "lab_name": "sql-injection",
        "os_type": "ubuntu-24",
        "git_hash": "a1b2c3d",
        "build_time": "2025-01-21T15:30:45Z",
        "ami_name": "lab-sql-injection-20250121-153045"
      }
    }
  ],
  "last_run_uuid": "abc123..."
}
```

## 🧪 Testes

O projeto possui uma suíte completa de testes unitários para garantir a qualidade e confiabilidade do código.

### Executar Testes

```bash
# Ativar ambiente virtual
source venv/bin/activate

# Executar todos os testes
python3 -m pytest tests/ -v

# Executar testes específicos
python3 -m pytest tests/test_auto_split_restart.py -v

# Executar com cobertura de código
python3 -m pytest tests/ --cov=scripts --cov-report=html
```

### Cobertura de Testes

O projeto possui **80+ testes unitários** cobrindo:

| Módulo | Testes | Cobertura |
|--------|--------|-----------|
| `auto_split_restart.py` | 21 | ✅ Split de scripts, detecção de restart, atualização de templates |
| `generate_lab_files.py` | 18 | ✅ Geração de arquivos HCL, comunicator config, templates |
| `get_latest_ami.py` | 17 | ✅ Busca de AMI, AWS CLI, validação |
| `add_os_mapping.py` | 24 | ✅ Adição de OS, validação, configuração |

### Testes do Auto-Split de Scripts Windows

```bash
# Testes específicos para Restart-Computer
python3 -m pytest tests/test_auto_split_restart.py -v

# Cobertura:
# - Detecção de Restart-Computer (case-insensitive, múltiplos, comentados)
# - Split de scripts (1, 2, 3+ partes)
# - Atualização de template.pkr.hcl
# - Escaping de paths (C:\\temp\\build-files)
# - Edge cases (restart na primeira/última linha, consecutivos)
# - Preservação de encoding UTF-8
```

### CI/CD

Os testes são executados automaticamente:
- ✅ Em cada commit (pre-commit hook)
- ✅ Em pull requests (GitHub Actions)
- ✅ Antes de releases

## 📚 Documentação Adicional

Para informações mais detalhadas, consulte:

- **[`docs/DRY_RUN.md`](docs/DRY_RUN.md)** - Guia completo do modo DRY_RUN
- **[`docs/WINDOWS_RESTART.md`](docs/WINDOWS_RESTART.md)** - Documentação do tratamento de Restart-Computer
- **[`WINDOWS_RESTART_SUMMARY.md`](WINDOWS_RESTART_SUMMARY.md)** - Resumo da implementação

## 🤝 Contribuindo

Contribuições são bem-vindas! Para contribuir:

1. Fork o repositório
2. Crie uma branch para sua feature (`git checkout -b feature/nova-funcionalidade`)
3. Adicione testes para suas mudanças
4. Execute os testes (`pytest tests/ -v`)
5. Commit suas mudanças (`git commit -am 'Add nova funcionalidade'`)
6. Push para a branch (`git push origin feature/nova-funcionalidade`)
7. Abra um Pull Request

### Checklist para Pull Requests

- [ ] Código segue os padrões do projeto
- [ ] Testes adicionados/atualizados
- [ ] Todos os testes passando (`pytest tests/`)
- [ ] Documentação atualizada (README.md, docs/)
- [ ] Commit messages descritivos

## 📝 License

Este projeto é de propriedade da Xtreme Hacking e está sujeito aos termos de uso internos.

## 🐛 Troubleshooting

### Erro: "packer: command not found"

```bash
# macOS
brew install packer

# Linux
sudo apt install packer
```

### Erro: "AWS credentials not configured"

```bash
# Configurar credenciais
aws configure

# OU definir variáveis de ambiente
export AWS_PROFILE=seu-perfil
```

### Erro: "WinRM timeout"

Se o build Windows falhar por timeout do WinRM:

1. Verifique se a AMI source tem WinRM habilitado
2. Aumente o timeout em `scripts/generate_lab_files.py` (linha 142: `winrm_timeout = "10m"`)
3. Verifique security groups na AWS (porta 5986 deve estar aberta)

### Erro: "Restart-Computer não dividiu o script"

1. Verifique se o comando está como `Restart-Computer` (não comentado)
2. Execute com DRY_RUN para debug: `make build-ami FOLDER=meu-lab DRY_RUN=true`
3. Verifique os logs do script `auto_split_restart.py`

### Build muito lento

1. Use instâncias maiores: edite `variables.pkr.hcl` → `instance_type = "t3.large"`
2. Otimize o userdata script (remova downloads desnecessários)
3. Use AMI source mais recente (menos atualizações necessárias)

## 📞 Suporte

Para suporte interno:
- 📧 Email: infra@xtremehacking.com
- 💬 Slack: #ami-automation
- 📖 Wiki: https://wiki.xtremehacking.com/ami-automation