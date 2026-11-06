# Cloud-1: Infraestructura como Código y Gestión de Configuración (42 School)

Proyecto de automatización de infraestructura en la nube (AWS) y aprovisionamiento de servicios de alta disponibilidad mediante **Terraform**, **Ansible** y **Docker**, orquestado bajo estándares **GNU Make**.

---

## 📋 Tabla de Contenidos

1. [Descripción General](#-descripción-general)
2. [Arquitectura del Sistema](#-arquitectura-del-sistema)
3. [Decisiones de Diseño](#-decisiones-de-diseño)
4. [Estructura del Repositorio](#-estructura-del-repositorio)
5. [Requisitos Previos](#-requisitos-previos)
6. [Seguridad y Gestión de Secretos](#-seguridad-y-gestión-de-secretos)
7. [Ciclo de Vida y Despliegue](#-ciclo-de-vida-y-despliegue)
8. [Pruebas y Verificación](#-pruebas-y-verificación)
9. [Control de Costes (Free Tier)](#-control-de-costes-free-tier)

---

## 🎯 Descripción General

El objetivo de **Cloud-1** es trasladar y evolucionar los conceptos de virtualización y contenedores (*Inception*) a un entorno de nube pública (**Amazon Web Services**).

La arquitectura implementa una separación estricta de responsabilidades:
* **Terraform**: Aprovisiona la topología de red aislada (VPC, Subred Pública, Internet Gateway, Tabla de Rutas), el perímetro de seguridad perimetral (Security Group) y el cómputo (Instancia EC2 con Ubuntu 22.04 LTS y par de claves SSH).
* **Ansible**: Aprovisiona el sistema operativo, endurece la seguridad base, instala el motor Docker oficial y orquesta el stack de WordPress mediante contenedores aislados.
* **GNU Make**: Ejerce de interfaz unificada para validar, desplegar, auditar y destruir la infraestructura de forma idempotente y reproducible.

---

## 🏗️ Arquitectura del Sistema

```text
INTERNET
   │
   ▼
[ Internet Gateway (IGW) ]
   │
   ▼
[ Tabla de Rutas: 0.0.0.0/0 -> IGW ]
   │
   ▼
[ AWS Virtual Private Cloud (VPC: 10.0.0.0/16) ]
   └── [ Subred Pública (10.0.1.0/24) - us-east-1a ]
         │
         ├── [ Security Group ]
         │     ├── Ingress: 22 (SSH), 80 (HTTP), 443 (HTTPS)
         │     └── Egress:  All (0.0.0.0/0)
         │
         └── [ Instancia EC2 (t2.micro / Ubuntu 22.04 LTS) ]
               │
               └── [ Docker Engine ]
                     ├── Contenedor 1: Nginx (Reverse Proxy SSL / TLS)
                     ├── Contenedor 2: WordPress (PHP-FPM)
                     ├── Contenedor 3: MariaDB (Base de datos interna)
                     └── Contenedor 4: phpMyAdmin (Gestión web)
```

---

## 💡 Decisiones de Diseño

### 1. Desacoplamiento de Herramientas (Opción B)
En lugar de forzar a Terraform a invocar Ansible mediante *provisioners* frágiles (`local-exec` o `remote-exec`), se ha implementado un desacoplamiento limpio:
* Terraform renderiza dinámicamente la plantilla `terraform/templates/hosts.tpl` mediante la función nativa `templatefile()`.
* El recurso `local_file` genera el inventario `ansible/inventory/hosts.yml` con la IP pública asignada por AWS.
* Ansible se ejecuta de forma independiente sobre dicho inventario, garantizando trazabilidad y facilidad de depuración.

### 2. Inmutabilidad y Búsqueda Dinámica de AMI
No se queman identificadores estáticos de imágenes (*hardcoding*). El bloque `data "aws_ami" "ubuntu"` consulta la API de AWS para obtener siempre la versión LTS más reciente publicada por Canonical (`owner: 099720109477`).

### 3. Aislamiento de Base de Datos
Siguiendo los principios de seguridad de la práctica:
* El puerto **3306 (MySQL/MariaDB)** **NO** está expuesto en el Security Group de AWS.
* La comunicación entre WordPress y MariaDB se realiza exclusivamente a través de una red interna de puente (*bridge network*) de Docker.

---

## 📂 Estructura del Repositorio

```text
cloud-1/
├── Makefile                     # Orquestador principal (GNU Make Standard)
├── .gitignore                   # Exclusión estricta de credenciales y estados
├── README.md                    # Documentación técnica del proyecto
├── terraform/                   # Infraestructura como Código (IaC)
│   ├── providers.tf             # Proveedores requeridos (AWS >= 5.0, Local >= 2.4)
│   ├── variables.tf             # Parametrización (región, CIDRs, tipo instancia)
│   ├── network.tf               # Topología VPC, Subnet, IGW y Route Tables
│   ├── security.tf              # Security Group (puertos 22, 80 y 443)
│   ├── compute.tf               # Clave SSH, AMI dinámica y máquina EC2
│   ├── outputs.tf               # Salidas de terminal y renderizado de inventario
│   └── templates/
│       └── hosts.tpl            # Plantilla del inventario para Ansible
└── ansible/                     # Gestión de Configuración
    ├── ansible.cfg              # Configuración de conexiones y roles
    ├── site.yml                 # Playbook principal
    ├── inventory/
    │   └── hosts.yml            # Inventario (autogenerado por Terraform)
    ├── group_vars/
    │   └── all/
    │       └── vault.yml        # Secretos cifrados con Ansible Vault
    └── roles/
        ├── common/              # Actualización de SO y dependencias base
        ├── docker/              # Instalación de Docker y Docker Compose
        ├── app/                 # Despliegue de WordPress, MariaDB y Nginx
        └── testing/             # Suite de verificación automatizada
```

---

## ⚙️ Requisitos Previos

* **Terraform** >= 1.5.0
* **Ansible** >= 2.14
* **AWS CLI** v2 (configurado con `aws configure`)
* **GNU Make** >= 4.0
* **OpenSSH Client** y clave generada en `~/.ssh/id_rsa`

---

## 🔐 Seguridad y Gestión de Secretos

* **Políticas de Repositorio:** El archivo `.gitignore` prohíbe el seguimiento de archivos `.tfstate`, variables locales `.tfvars`, claves privadas `.pem`/`id_rsa` e inventarios autogenerados.
* **Cifrado de Variables:** Todas las contraseñas de base de datos y administradores de WordPress están cifradas en `ansible/group_vars/all/vault.yml` mediante **Ansible Vault (AES-256)**.
* **Sin Credenciales en Código:** La autenticación de Terraform se realiza mediante variables de entorno del sistema o el perfil local de AWS CLI.

---

## 🚀 Ciclo de Vida y Despliegue

La gestión completa se realiza mediante el `Makefile` en la raíz del proyecto:

### 1. Verificación y Calidad de Código
Comprueba la validez sintáctica de Terraform y Ansible sin realizar llamadas a la nube:
```bash
make check
```

### 2. Formateo de Código HCL
```bash
make fmt
```

### 3. Despliegue Completo
Aprovisiona la infraestructura en AWS, genera el inventario y lanza el playbook de Ansible:
```bash
make all
```
*(Nota: Se solicitará interactivamente la contraseña de Ansible Vault para descifrar los secretos).*

### 4. Despliegue por Fases (Opcional)
Si se desea ejecutar paso a paso:
```bash
make init     # Descarga proveedores de Terraform
make plan     # Revisa los cambios previstos en AWS
make apply    # Despliega la infraestructura y genera el inventario
make deploy   # Ejecuta el aprovisionamiento de Ansible
```

---

## 🧪 Pruebas y Verificación

El rol `testing` de Ansible ejecuta comprobaciones automatizadas:
* Verificación del estado de los contenedores Docker (`docker ps`).
* Comprobación del puerto 80 (código HTTP 301/302 hacia HTTPS o respuesta correcta).
* Comprobación del puerto 443 (servicio Nginx y certificado SSL activo).
* Verificación de conectividad con WordPress.

Para ejecutar exclusivamente las pruebas sobre una infraestructura ya desplegada:
```bash
make test
```

---

## 💰 Control de Costes (Free Tier)

Para evitar cargos imprevistos en la cuenta de AWS y cumplir con las directrices de entrega:
* Instancia limitada a **`t2.micro`** (750 horas/mes gratuitas en Free Tier).
* Disco de almacenamiento EBS de **20 GB** (límite gratuito de 30 GB).
* Una sola IP elástica/pública asociada a la VPC.

### Destrucción de Recursos
Al finalizar las pruebas o la evaluación, ejecute:
```bash
make clean
```
Para realizar una limpieza exhaustiva (destrucción en AWS + borrado de archivos locales de estado e inventario):
```bash
make distclean
```
