# Makefile for v2-ami-automation
# AMI automation system using Packer for AWS
#
# Usage:
#   make build-ami FOLDER=sql-injection OS=ubuntu-24
#   make validate FOLDER=sql-injection
#   make init-lab FOLDER=new-lab OS=ubuntu-24
#   make list-labs
#   make list-os
#   make add-os OS=ubuntu-26
#   make help

.PHONY: help build-ami validate list-labs list-os add-os init-lab clean check-prereqs

# Colors for output
RED     := \033[0;31m
GREEN   := \033[0;32m
YELLOW  := \033[1;33m
BLUE    := \033[0;34m
CYAN    := \033[0;36m
MAGENTA := \033[0;35m
NC      := \033[0m # No Color

# Directories
PROJECT_ROOT := $(shell pwd)
LAB_DIR      := $(PROJECT_ROOT)/laboratory
SCRIPTS_DIR  := $(PROJECT_ROOT)/scripts
CONFIG_DIR   := $(PROJECT_ROOT)/config
TEMPLATES_DIR := $(PROJECT_ROOT)/templates

# Configuration files
OS_MAPPINGS  := $(TEMPLATES_DIR)/os-mappings.yaml

# Required tools
REQUIRED_TOOLS := aws packer git yq

# Timestamp for logging
TIMESTAMP := $(shell date +"%Y%m%d-%H%M%S")

# Default target
.DEFAULT_GOAL := help

##@ Help

help: ## Display this help message
	@echo ""
	@echo "$(CYAN)╔════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║           v2-ami-automation - Packer AMI Builder              ║$(NC)"
	@echo "$(CYAN)╚════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make $(CYAN)<target>$(NC) $(YELLOW)[ARGS]$(NC)\n\n"} \
		/^[a-zA-Z_-]+:.*?##/ { printf "  $(CYAN)%-20s$(NC) %s\n", $$1, $$2 } \
		/^##@/ { printf "\n$(MAGENTA)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make build-ami FOLDER=sql-injection OS=ubuntu-24"
	@echo "  make build-ami FOLDER=sql-injection OS=ubuntu-24 AMI_ID=ami-0123456789abcdef0"
	@echo "  make validate FOLDER=sql-injection"
	@echo "  make init-lab FOLDER=web-vuln OS=ubuntu-22"
	@echo "  make list-labs"
	@echo "  make list-os"
	@echo "  make add-os OS=ubuntu-26"
	@echo ""

##@ Prerequisites

check-prereqs: ## Check if all required tools are installed
	@echo "$(BLUE)[CHECK]$(NC) Verifying prerequisites..."
	@missing_tools=""; \
	for tool in $(REQUIRED_TOOLS); do \
		if ! command -v $$tool &> /dev/null; then \
			echo "$(RED)[✗]$(NC) $$tool is not installed"; \
			missing_tools="$$missing_tools $$tool"; \
		else \
			version=$$($$tool --version 2>&1 | head -n1); \
			echo "$(GREEN)[✓]$(NC) $$tool is installed: $$version"; \
		fi \
	done; \
	if [ -n "$$missing_tools" ]; then \
		echo ""; \
		echo "$(RED)[ERROR]$(NC) Missing required tools:$$missing_tools"; \
		echo "$(YELLOW)[INFO]$(NC) Please install missing tools:"; \
		echo "  brew install awscli packer git yq"; \
		exit 1; \
	fi
	@echo "$(GREEN)[✓]$(NC) All prerequisites satisfied!"

check-aws-creds: ## Check if AWS credentials are configured
	@echo "$(BLUE)[CHECK]$(NC) Verifying AWS credentials..."
	@if ! aws sts get-caller-identity &> /dev/null; then \
		echo "$(RED)[✗]$(NC) AWS credentials not configured or invalid"; \
		echo "$(YELLOW)[INFO]$(NC) Please configure AWS credentials:"; \
		echo "  aws configure"; \
		echo "  or set AWS_PROFILE environment variable"; \
		exit 1; \
	else \
		account_id=$$(aws sts get-caller-identity --query Account --output text); \
		echo "$(GREEN)[✓]$(NC) AWS credentials valid (Account: $$account_id)"; \
	fi

##@ Laboratory Management

list-labs: ## List all available laboratories
	@echo "$(CYAN)╔════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║                  Available Laboratories                        ║$(NC)"
	@echo "$(CYAN)╚════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@if [ ! -d "$(LAB_DIR)" ] || [ -z "$$(ls -A $(LAB_DIR) 2>/dev/null)" ]; then \
		echo "$(YELLOW)[INFO]$(NC) No laboratories found."; \
		echo "$(YELLOW)[INFO]$(NC) Create one with: make init-lab FOLDER=<name> OS=<os-type>"; \
	else \
		for lab in $(LAB_DIR)/*; do \
			if [ -d "$$lab" ]; then \
				lab_name=$$(basename $$lab); \
				echo "$(GREEN)📦 $$lab_name$(NC)"; \
				if [ -f "$$lab/userdata.sh" ]; then \
					echo "   $(GREEN)[✓]$(NC) userdata.sh exists"; \
				elif [ -f "$$lab/userdata.ps1" ]; then \
					echo "   $(GREEN)[✓]$(NC) userdata.ps1 exists"; \
				else \
					echo "   $(RED)[✗]$(NC) userdata script missing"; \
				fi; \
				if [ -f "$$lab/variables.pkr.hcl" ]; then \
					os_type=$$(grep -E 'default.*=' "$$lab/variables.pkr.hcl" | grep os_type | sed 's/.*"\(.*\)".*/\1/' || echo "unknown"); \
					echo "   $(BLUE)[i]$(NC) OS: $$os_type"; \
				fi; \
				if [ -d "$$lab/build-files" ]; then \
					file_count=$$(find "$$lab/build-files" -type f | wc -l | tr -d ' '); \
					echo "   $(BLUE)[i]$(NC) Build files: $$file_count"; \
				fi; \
				echo ""; \
			fi \
		done \
	fi

list-os: ## List all configured operating systems
	@echo "$(CYAN)╔════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║              Configured Operating Systems                      ║$(NC)"
	@echo "$(CYAN)╚════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@if [ ! -f "$(OS_MAPPINGS)" ]; then \
		echo "$(RED)[ERROR]$(NC) OS mappings file not found: $(OS_MAPPINGS)"; \
		exit 1; \
	fi
	@yq eval '.os_mappings | to_entries | .[] | .key + "|||" + .value.name + "|||" + .value.user_data_type + "|||" + .value.ssh_username' $(OS_MAPPINGS) | \
		while IFS='|||' read -r key name type user; do \
			printf "$(GREEN)%-20s$(NC) $(BLUE)%-35s$(NC) $(YELLOW)%-12s$(NC) $(CYAN)%s$(NC)\n" "$$key" "$$name" "$$type" "$$user"; \
		done
	@echo ""
	@echo "$(YELLOW)[INFO]$(NC) Use these OS keys with: make build-ami FOLDER=<lab> OS=<os-key>"
	@echo ""

add-os: ## Add a new OS mapping (requires OS=<os-key>)
	@if [ -z "$(OS)" ]; then \
		echo "$(RED)[ERROR]$(NC) OS parameter is required"; \
		echo "$(YELLOW)[INFO]$(NC) Usage: make add-os OS=<os-key>"; \
		echo "$(YELLOW)[INFO]$(NC) Example: make add-os OS=ubuntu-26"; \
		exit 1; \
	fi
	@echo "$(BLUE)[INFO]$(NC) Adding new OS mapping: $(OS)"
	@$(SCRIPTS_DIR)/add-os-mapping.sh "$(OS)"

init-lab: check-prereqs check-aws-creds ## Initialize a new laboratory (requires FOLDER=<name> OS=<os-type>)
	@if [ -z "$(FOLDER)" ]; then \
		echo "$(RED)[ERROR]$(NC) FOLDER parameter is required"; \
		echo "$(YELLOW)[INFO]$(NC) Usage: make init-lab FOLDER=<lab-name> OS=<os-type>"; \
		echo "$(YELLOW)[INFO]$(NC) Example: make init-lab FOLDER=sql-injection OS=ubuntu-24"; \
		exit 1; \
	fi
	@if [ -z "$(OS)" ]; then \
		echo "$(RED)[ERROR]$(NC) OS parameter is required"; \
		echo "$(YELLOW)[INFO]$(NC) Usage: make init-lab FOLDER=<lab-name> OS=<os-type>"; \
		echo "$(YELLOW)[INFO]$(NC) Run 'make list-os' to see available OS types"; \
		exit 1; \
	fi
	@if [ -d "$(LAB_DIR)/$(FOLDER)" ]; then \
		echo "$(RED)[ERROR]$(NC) Laboratory already exists: $(FOLDER)"; \
		exit 1; \
	fi
	@echo "$(BLUE)[INFO]$(NC) Creating new laboratory: $(FOLDER)"; \
	set -e; \
	trap 'if [ $$? -ne 0 ]; then \
		echo ""; \
		echo "$(RED)[ERROR]$(NC) Failed to create laboratory. Rolling back..."; \
		rm -rf "$(LAB_DIR)/$(FOLDER)"; \
		echo "$(YELLOW)[INFO]$(NC) Cleanup completed. Laboratory directory removed."; \
		exit 1; \
	fi' EXIT; \
	mkdir -p "$(LAB_DIR)/$(FOLDER)/build-files"; \
	touch "$(LAB_DIR)/$(FOLDER)/build-files/.gitkeep"; \
	echo "$(GREEN)[✓]$(NC) Created directory structure"; \
	user_data_type=$$(yq eval ".os_mappings.$(OS).user_data_type" $(OS_MAPPINGS)); \
	if [ "$$user_data_type" == "null" ] || [ -z "$$user_data_type" ]; then \
		echo "$(RED)[ERROR]$(NC) OS '$(OS)' not found in configuration"; \
		echo "$(YELLOW)[INFO]$(NC) Run 'make list-os' to see available OS types"; \
		exit 1; \
	fi; \
	if [ "$$user_data_type" == "powershell" ]; then \
		userdata_file="$(LAB_DIR)/$(FOLDER)/userdata.ps1"; \
		echo "# PowerShell userdata script for $(FOLDER)" > $$userdata_file; \
		echo "# Lab: $(FOLDER)" >> $$userdata_file; \
		echo "# OS: $(OS)" >> $$userdata_file; \
		echo "" >> $$userdata_file; \
		echo "Write-Host \"Starting lab setup: $(FOLDER)\"" >> $$userdata_file; \
		echo "" >> $$userdata_file; \
		echo "# TODO: Add your PowerShell setup commands here" >> $$userdata_file; \
		echo "# Example:" >> $$userdata_file; \
		echo "# Install-WindowsFeature -Name Web-Server -IncludeManagementTools" >> $$userdata_file; \
		echo "" >> $$userdata_file; \
		echo "Write-Host \"Lab setup completed\"" >> $$userdata_file; \
	else \
		userdata_file="$(LAB_DIR)/$(FOLDER)/userdata.sh"; \
		echo "#!/bin/bash" > $$userdata_file; \
		echo "# Userdata script for $(FOLDER)" >> $$userdata_file; \
		echo "# Lab: $(FOLDER)" >> $$userdata_file; \
		echo "# OS: $(OS)" >> $$userdata_file; \
		echo "" >> $$userdata_file; \
		echo "set -euo pipefail" >> $$userdata_file; \
		echo "" >> $$userdata_file; \
		echo "echo \"🚀 Starting lab setup: $(FOLDER)\"" >> $$userdata_file; \
		echo "" >> $$userdata_file; \
		echo "# Build files are available in: \$$BUILD_FILES" >> $$userdata_file; \
		echo "# Example: sudo cp \$$BUILD_FILES/app.jar /opt/app.jar" >> $$userdata_file; \
		echo "" >> $$userdata_file; \
		echo "# TODO: Add your setup commands here" >> $$userdata_file; \
		echo "# Example:" >> $$userdata_file; \
		echo "# sudo apt update" >> $$userdata_file; \
		echo "# sudo apt install -y docker.io" >> $$userdata_file; \
		echo "# sudo systemctl enable docker" >> $$userdata_file; \
		echo "" >> $$userdata_file; \
		echo "echo \"✅ Lab setup completed\"" >> $$userdata_file; \
		chmod +x $$userdata_file; \
	fi; \
	echo "$(GREEN)[✓]$(NC) Created userdata script"; \
	$(SCRIPTS_DIR)/generate-lab-files.sh "$(FOLDER)" "$(OS)"; \
	trap - EXIT; \
	echo ""; \
	echo "$(GREEN)╔════════════════════════════════════════════════════════════════╗$(NC)"; \
	echo "$(GREEN)║  Laboratory '$(FOLDER)' created successfully!                   $(NC)"; \
	echo "$(GREEN)╚════════════════════════════════════════════════════════════════╝$(NC)"; \
	echo ""; \
	echo "$(YELLOW)[NEXT STEPS]$(NC)"; \
	echo "  1. Edit the userdata script:"; \
	user_data_type=$$(yq eval ".os_mappings.$(OS).user_data_type" $(OS_MAPPINGS)); \
	if [ "$$user_data_type" == "powershell" ]; then \
		echo "     $(CYAN)vim $(LAB_DIR)/$(FOLDER)/userdata.ps1$(NC)"; \
	else \
		echo "     $(CYAN)vim $(LAB_DIR)/$(FOLDER)/userdata.sh$(NC)"; \
	fi; \
	echo "  2. Add build files to:"; \
	echo "     $(CYAN)$(LAB_DIR)/$(FOLDER)/build-files/$(NC)"; \
	echo "  3. Validate the configuration:"; \
	echo "     $(CYAN)make validate FOLDER=$(FOLDER)$(NC)"; \
	echo "  4. Build the AMI:"; \
	echo "     $(CYAN)make build-ami FOLDER=$(FOLDER) OS=$(OS)$(NC)"; \
	echo ""

##@ Building and Validation

validate: check-prereqs ## Validate Packer configuration (requires FOLDER=<lab-name>)
	@if [ -z "$(FOLDER)" ]; then \
		echo "$(RED)[ERROR]$(NC) FOLDER parameter is required"; \
		echo "$(YELLOW)[INFO]$(NC) Usage: make validate FOLDER=<lab-name>"; \
		exit 1; \
	fi
	@if [ ! -d "$(LAB_DIR)/$(FOLDER)" ]; then \
		echo "$(RED)[ERROR]$(NC) Laboratory not found: $(FOLDER)"; \
		echo "$(YELLOW)[INFO]$(NC) Run 'make list-labs' to see available laboratories"; \
		exit 1; \
	fi
	@echo "$(BLUE)[INFO]$(NC) Validating laboratory: $(FOLDER)"
	@echo ""
	@cd "$(LAB_DIR)/$(FOLDER)" && \
		if [ -f "userdata.sh" ]; then \
			echo "$(GREEN)[✓]$(NC) userdata.sh exists"; \
		elif [ -f "userdata.ps1" ]; then \
			echo "$(GREEN)[✓]$(NC) userdata.ps1 exists"; \
		else \
			echo "$(RED)[✗]$(NC) userdata script not found"; \
			exit 1; \
		fi
	@cd "$(LAB_DIR)/$(FOLDER)" && \
		if [ -f "variables.pkr.hcl" ]; then \
			echo "$(GREEN)[✓]$(NC) variables.pkr.hcl exists"; \
		else \
			echo "$(YELLOW)[⚠]$(NC) variables.pkr.hcl not found (will be generated)"; \
		fi
	@cd "$(LAB_DIR)/$(FOLDER)" && \
		if [ -f "template.pkr.hcl" ]; then \
			echo "$(GREEN)[✓]$(NC) template.pkr.hcl exists"; \
		else \
			echo "$(YELLOW)[⚠]$(NC) template.pkr.hcl not found (will be generated)"; \
		fi
	@cd "$(LAB_DIR)/$(FOLDER)" && \
		if [ -d "build-files" ]; then \
			file_count=$$(find build-files -type f ! -name '.gitkeep' | wc -l | tr -d ' '); \
			echo "$(GREEN)[✓]$(NC) build-files directory exists ($$file_count files)"; \
		else \
			echo "$(YELLOW)[⚠]$(NC) build-files directory not found"; \
		fi
	@echo ""
	@if [ -f "$(LAB_DIR)/$(FOLDER)/template.pkr.hcl" ]; then \
		echo "$(BLUE)[INFO]$(NC) Running packer validate..."; \
		cd "$(LAB_DIR)/$(FOLDER)" && packer init . && packer validate . && \
		echo "$(GREEN)[✓]$(NC) Packer configuration is valid!"; \
	else \
		echo "$(YELLOW)[INFO]$(NC) Skipping packer validate (template not generated yet)"; \
	fi
	@echo ""
	@echo "$(GREEN)[✓]$(NC) Validation completed successfully!"

build-ami: check-prereqs check-aws-creds ## Build AMI (requires FOLDER=<lab-name>, optional: OS=<os-type> AMI_ID=<ami-id>)
	@if [ -z "$(FOLDER)" ]; then \
		echo "$(RED)[ERROR]$(NC) FOLDER parameter is required"; \
		echo "$(YELLOW)[INFO]$(NC) Usage: make build-ami FOLDER=<lab-name> [OS=<os-type>] [AMI_ID=<ami-id>]"; \
		exit 1; \
	fi
	@if [ ! -d "$(LAB_DIR)/$(FOLDER)" ]; then \
		echo "$(RED)[ERROR]$(NC) Laboratory not found: $(FOLDER)"; \
		echo "$(YELLOW)[INFO]$(NC) Run 'make list-labs' to see available laboratories"; \
		exit 1; \
	fi
	@OS_TYPE="$(OS)"; \
	if [ -z "$$OS_TYPE" ]; then \
		if [ -f "$(LAB_DIR)/$(FOLDER)/variables.pkr.hcl" ]; then \
			OS_TYPE=$$(grep -A5 'variable "os_type"' "$(LAB_DIR)/$(FOLDER)/variables.pkr.hcl" | grep default | sed 's/.*=.*"\(.*\)".*/\1/'); \
			if [ -z "$$OS_TYPE" ]; then \
				echo "$(RED)[ERROR]$(NC) Could not read OS from variables.pkr.hcl"; \
				echo "$(YELLOW)[INFO]$(NC) Please specify: make build-ami FOLDER=$(FOLDER) OS=<os-type>"; \
				exit 1; \
			fi; \
			echo "$(BLUE)[INFO]$(NC) OS detected from variables.pkr.hcl: $$OS_TYPE"; \
		else \
			echo "$(RED)[ERROR]$(NC) OS parameter is required and variables.pkr.hcl not found"; \
			echo "$(YELLOW)[INFO]$(NC) Usage: make build-ami FOLDER=<lab-name> OS=<os-type>"; \
			echo "$(YELLOW)[INFO]$(NC) Run 'make list-os' to see available OS types"; \
			exit 1; \
		fi; \
	fi; \
	echo "$(CYAN)╔════════════════════════════════════════════════════════════════╗$(NC)"; \
	echo "$(CYAN)║                   Building AMI                                 ║$(NC)"; \
	echo "$(CYAN)╚════════════════════════════════════════════════════════════════╝$(NC)"; \
	echo ""; \
	echo "$(BLUE)[INFO]$(NC) Laboratory: $(FOLDER)"; \
	echo "$(BLUE)[INFO]$(NC) OS: $$OS_TYPE"; \
	if [ -n "$(AMI_ID)" ]; then \
		echo "$(BLUE)[INFO]$(NC) Custom AMI ID: $(AMI_ID)"; \
	fi; \
	echo "$(BLUE)[INFO]$(NC) Timestamp: $(TIMESTAMP)"; \
	echo ""; \
	echo "$(GREEN)[✓]$(NC) Laboratory directory exists"; \
	user_data_type=$$(yq eval ".os_mappings.$$OS_TYPE.user_data_type" $(OS_MAPPINGS)); \
	if [ "$$user_data_type" == "powershell" ]; then \
		if [ ! -f "$(LAB_DIR)/$(FOLDER)/userdata.ps1" ]; then \
			echo "$(RED)[✗] ERROR: userdata.ps1 not found!$(NC)"; \
			echo ""; \
			echo "$(RED)❌ CRITICAL ERROR: The file userdata.ps1 is mandatory!$(NC)"; \
			echo "   $(YELLOW)Expected path: $(LAB_DIR)/$(FOLDER)/userdata.ps1$(NC)"; \
			echo ""; \
			echo "$(YELLOW)💡 Tip: Create the file or use 'make init-lab FOLDER=$(FOLDER) OS=$$OS_TYPE'$(NC)"; \
			echo ""; \
			exit 1; \
		fi; \
		echo "$(GREEN)[✓]$(NC) userdata.ps1 exists"; \
	else \
		if [ ! -f "$(LAB_DIR)/$(FOLDER)/userdata.sh" ]; then \
			echo "$(RED)[✗] ERROR: userdata.sh not found!$(NC)"; \
			echo ""; \
			echo "$(RED)❌ CRITICAL ERROR: The file userdata.sh is mandatory!$(NC)"; \
			echo "   $(YELLOW)Expected path: $(LAB_DIR)/$(FOLDER)/userdata.sh$(NC)"; \
			echo ""; \
			echo "$(YELLOW)💡 Tip: Create the file or use 'make init-lab FOLDER=$(FOLDER) OS=$$OS_TYPE'$(NC)"; \
			echo ""; \
			exit 1; \
		fi; \
		echo "$(GREEN)[✓]$(NC) userdata.sh exists"; \
	fi; \
	echo "$(YELLOW)[⚠]$(NC) Regenerating Packer files..."; \
	if [ -n "$(AMI_ID)" ]; then \
		$(SCRIPTS_DIR)/generate-lab-files.sh "$(FOLDER)" "$$OS_TYPE" "$(AMI_ID)" > /dev/null 2>&1; \
	else \
		$(SCRIPTS_DIR)/generate-lab-files.sh "$(FOLDER)" "$$OS_TYPE" > /dev/null 2>&1; \
	fi; \
	echo "$(GREEN)[✓]$(NC) Generated variables.pkr.hcl"; \
	echo "$(GREEN)[✓]$(NC) Generated template.pkr.hcl"; \
	os_exists=$$(yq eval ".os_mappings.$$OS_TYPE" $(OS_MAPPINGS)); \
	if [ "$$os_exists" == "null" ]; then \
		echo "$(RED)[✗] ERROR: OS '$$OS_TYPE' not found in configuration$(NC)"; \
		echo ""; \
		echo "$(YELLOW)💡 Run 'make list-os' to see available OS types$(NC)"; \
		echo "$(YELLOW)💡 Or add new OS with 'make add-os OS=$$OS_TYPE'$(NC)"; \
		echo ""; \
		exit 1; \
	fi; \
	echo "$(GREEN)[✓]$(NC) OS configuration found"
	@echo ""
	@echo "$(BLUE)[INFO]$(NC) Initializing Packer..."
	@cd "$(LAB_DIR)/$(FOLDER)" && packer init .
	@echo ""
	@echo "$(BLUE)[INFO]$(NC) Validating Packer configuration..."
	@cd "$(LAB_DIR)/$(FOLDER)" && packer validate .
	@echo "$(GREEN)[✓]$(NC) Validation passed!"
	@echo ""
	@echo "$(BLUE)[INFO]$(NC) Building AMI (this may take several minutes)..."
	@echo ""
	@cd "$(LAB_DIR)/$(FOLDER)" && \
		packer build . ; \
		if [ $$? -eq 0 ]; then \
			if [ -f "packer-manifest.json" ]; then \
				ami_id=$$(jq -r '.builds[-1].artifact_id' packer-manifest.json | cut -d: -f2); \
				ami_name=$$(jq -r '.builds[-1].custom_data.ami_name // .builds[-1].name // "unknown"' packer-manifest.json 2>/dev/null || echo "unknown"); \
				if [ "$$ami_name" = "null" ] || [ -z "$$ami_name" ]; then \
					ami_name=$$(aws ec2 describe-images --image-ids $$ami_id --query 'Images[0].Name' --output text 2>/dev/null || echo "unknown"); \
				fi; \
				echo ""; \
				echo "$(GREEN)╔════════════════════════════════════════════════════════════════╗$(NC)"; \
				echo "$(GREEN)║               AMI Created Successfully! 🎉                     ║$(NC)"; \
				echo "$(GREEN)╚════════════════════════════════════════════════════════════════╝$(NC)"; \
				echo ""; \
				echo "$(GREEN)📦 AMI ID:$(NC)   $$ami_id"; \
				git_hash=$$(git rev-parse --short=7 HEAD 2>/dev/null || echo "unknown"); \
				echo "$(GREEN)🏷️  Tag:$(NC)      lab-$(FOLDER)-$$git_hash"; \
				echo "$(GREEN)📝 AMI Name:$(NC) $$ami_name"; \
				echo ""; \
			fi; \
		else \
			echo ""; \
			echo "$(RED)╔════════════════════════════════════════════════════════════════╗$(NC)"; \
			echo "$(RED)║                   Build Failed ❌                              ║$(NC)"; \
			echo "$(RED)╚════════════════════════════════════════════════════════════════╝$(NC)"; \
			echo ""; \
			exit 1; \
		fi

##@ Cleanup

clean: ## Clean up generated files
	@echo "$(YELLOW)[INFO]$(NC) Cleaning up..."
	@rm -f $(LAB_DIR)/*/packer-manifest.json
	@rm -f $(LAB_DIR)/*/.terraform.lock.hcl
	@rm -rf $(LAB_DIR)/*/.terraform/
	@echo "$(GREEN)[✓]$(NC) Cleaned up generated files"
