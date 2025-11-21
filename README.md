# v2-ami-automation

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
- [Sistemas Operacionais Suportados](#sistemas-operacionais-suportados)
- [Configuração de Laboratórios](#configuração-de-laboratórios)
- [Tags e Metadados](#tags-e-metadados)
- [Troubleshooting](#troubleshooting)
- [Arquitetura](#arquitetura)

## 🎯 Visão Geral

Automação para gerar AMIs na AWS.

### Características Principais

- ✅ Suporte para múltiplos sistemas operacionais (Linux e Windows)
- ✅ Templates reutilizáveis e parametrizáveis
- ✅ Busca automática da AMI mais recente ou uso de AMI específica

## 🔧 Pré-requisitos

### Ferramentas Necessárias

```bash
# macOS (usando Homebrew)
brew install awscli packer git yq

# Verificar instalação
aws --version
packer --version
git --version
yq --version
```

### Versões Recomendadas

- **AWS CLI**: >= 2.0
- **Packer**: >= 1.8.0
- **Git**: >= 2.0
- **yq**: >= 4.0

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

# Verifique as credenciais AWS
make check-aws-creds
```

## 📁 Estrutura do Projeto

```
v2-ami-automation/
├── Makefile                    # Interface principal de comandos
├── README.md                   # Esta documentação
├── laboratory/                 # Diretório de laboratórios
│   ├── sql-injection/         # Exemplo de laboratório
│   │   ├── userdata.sh        # Script de configuração
│   │   ├── variables.pkr.hcl  # Variáveis do Packer (auto-gerado)
│   │   ├── template.pkr.hcl   # Template do Packer (auto-gerado)
│   │   └── build-files/       # Arquivos para copiar para a AMI
│   │       ├── app.jar
│   │       └── config.json
│   └── ...
├── scripts/                    # Scripts de automação
│   ├── generate-lab-files.sh  # Gera arquivos HCL do Packer
│   ├── get-latest-ami.sh      # Busca AMI mais recente
│   └── add-os-mapping.sh      # Adiciona novo OS
├── templates/                  # Templates base
│   ├── template-linux.pkr.hcl.tpl
│   ├── template-windows.pkr.hcl.tpl
│   ├── variables.pkr.hcl.tpl
│   └── os-mappings.yaml       # Mapeamento de sistemas operacionais
└── config/                     # Configurações (se houver)
```

## 🚀 Uso Rápido

```bash
# 1. Verificar pré-requisitos
make check-prereqs

# 2. Listar sistemas operacionais disponíveis
make list-os

# 3. Criar um novo laboratório
make init-lab FOLDER=meu-lab OS=ubuntu-24

# 4. Editar o script de configuração
vim laboratory/meu-lab/userdata.sh

# 5. Adicionar arquivos necessários
cp /path/to/files/* laboratory/meu-lab/build-files/

# 6. Validar configuração
make validate FOLDER=meu-lab

# 7. Buildar a AMI
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

# Buildar AMI (AMI mais recente será usado)
make build-ami FOLDER=<nome> OS=<os-type>

# Buildar AMI com ID específico (útil para testar vulnerabilidades)
make build-ami FOLDER=<nome> OS=<os-type> AMI_ID=ami-0123456789abcdef0
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

### userdata.sh - Variáveis Disponíveis

Dentro do `userdata.sh`, você tem acesso a:

```bash
$LAB_NAME       # Nome do laboratório (ex: "sql-injection")
$OS_TYPE        # Tipo do OS (ex: "ubuntu-24")
$BUILD_FILES    # Caminho dos arquivos: /tmp/build-files
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
| **SourceAmiId**  | ID da AMI fonte*                             | ami-0abcdef1234567890                |
| **SourceAmiName**| Nome da AMI fonte                            | ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20231001 |

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