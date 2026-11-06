# ==============================================================================
# Cloud-1: Infrastructure & Configuration Orchestrator (GNU Make Standard)
# ==============================================================================

# 1. Configuración del Shell y robustez en ejecución
SHELL        := /bin/bash
.SHELLFLAGS  := -eu -o pipefail -c
.ONESHELL:
.DELETE_ON_ERROR:

# 2. Objetivo por defecto
.DEFAULT_GOAL := help

# 3. Variables para comandos (GNU Conventions - Overridable)
TERRAFORM        ?= terraform
ANSIBLE_PLAYBOOK ?= ansible-playbook
SLEEP            ?= sleep

# 4. Directorios y archivos del proyecto
TF_DIR           := terraform
ANSIBLE_DIR      := ansible
ANSIBLE_SITE     := $(ANSIBLE_DIR)/site.yml
ANSIBLE_INV      := $(ANSIBLE_DIR)/inventory/hosts.yml
WAIT_SSH_SECONDS ?= 20

# 5. Targets que no generan un archivo con su mismo nombre
.PHONY: all help init plan apply deploy check test clean distclean fmt

# ==============================================================================
# Metas de ayuda y documentación
# ==============================================================================

help: ## Muestra este menú de ayuda documentado
	@printf "\033[1;36mComandos disponibles en Cloud-1:\033[0m\n\n"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[32m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ==============================================================================
# Flujo principal de entrega (All / Build)
# ==============================================================================

all: apply deploy ## Despliega infraestructura completa en AWS y aprovisiona con Ansible

# ==============================================================================
# Gestión de Infraestructura (Terraform)
# ==============================================================================

init: ## Inicializa plugins y proveedores de Terraform
	$(TERRAFORM) -chdir=$(TF_DIR) init

plan: ## Genera y muestra el plan de ejecución de Terraform
	$(TERRAFORM) -chdir=$(TF_DIR) plan

apply: $(ANSIBLE_DIR)/inventory ## Despliega recursos en AWS y genera inventario de Ansible
	$(TERRAFORM) -chdir=$(TF_DIR) apply -auto-approve

# Regla de soporte para asegurar que el directorio del inventario existe
$(ANSIBLE_DIR)/inventory:
	mkdir -p $@

# ==============================================================================
# Gestión de Configuración (Ansible)
# ==============================================================================

deploy: ## Ejecuta el playbook de configuración sobre la máquina EC2
	@echo "Esperando $(WAIT_SSH_SECONDS) segundos para que el demonio SSH este disponible..."
	$(SLEEP) $(WAIT_SSH_SECONDS)
	$(ANSIBLE_PLAYBOOK) -i $(ANSIBLE_INV) $(ANSIBLE_SITE) --ask-vault-pass

# ==============================================================================
# Verificación y Calidad de Código (GNU 'check' target)
# ==============================================================================

check: ## Valida la sintaxis y coherencia de Terraform y Ansible
	$(TERRAFORM) -chdir=$(TF_DIR) validate
	$(ANSIBLE_PLAYBOOK) -i $(ANSIBLE_INV) $(ANSIBLE_SITE) --syntax-check

test: ## Ejecuta la suite de pruebas automatizadas del rol testing
	$(ANSIBLE_PLAYBOOK) -i $(ANSIBLE_INV) $(ANSIBLE_SITE) --tags test --ask-vault-pass

fmt: ## Aplica el formateo canónico de Terraform
	$(TERRAFORM) -chdir=$(TF_DIR) fmt

# ==============================================================================
# Limpieza y Destrucción (GNU 'clean' / 'distclean' targets)
# ==============================================================================

clean: ## Destruye los recursos aprovisionados en AWS para evitar costes
	$(TERRAFORM) -chdir=$(TF_DIR) destroy -auto-approve

distclean: clean ## Limpieza total: destruye recursos y elimina archivos locales autogenerados
	rm -f $(ANSIBLE_INV)
	rm -rf $(TF_DIR)/.terraform
	rm -f $(TF_DIR)/.terraform.lock.hcl
	rm -f $(TF_DIR)/*.tfstate $(TF_DIR)/*.tfstate.*
