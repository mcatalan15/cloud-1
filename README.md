# Despliegue Automatizado de WordPress, phpMyAdmin y MySQL con Ansible y Docker

Este proyecto contiene la automatización completa en **Ansible** para el aprovisionamiento, configuración, despliegue y verificación de una infraestructura web basada en **WordPress**, **phpMyAdmin**, **MySQL 8.0** y un proxy inverso **Nginx**, todo ejecutado en contenedores **Docker** aislados sobre servidores Ubuntu 22.04 LTS.

---

## 📐 Arquitectura del Sistema

La solución está diseñada siguiendo el principio de **1 proceso = 1 contenedor**, utilizando una red privada interna de Docker (`internal_net`) para aislar los componentes sensibles del exterior.

```text
                  +-----------------------------------+
                  |        Cliente / Navegador        |
                  +-----------------------------------+
                                    |
                                HTTP (80)
                                    v
+-------------------------------------------------------------------+
| Servidor Host (Ubuntu 22.04 LTS) - UFW: Puertos 22, 80, 443       |
|                                                                   |
|  +-------------------------------------------------------------+  |
|  | Contenedor 1: wp_nginx (Proxy Inverso Nginx)               |  |
|  +-------------------------------------------------------------+  |
|                 /                               \                 |
|       Ruta: /  /                                 \ Ruta: /phpmyadmin/
|               v                                   v               |
|  +-------------------------+         +-------------------------+  |
|  | Contenedor 2: wp_app    |         | Contenedor 4:           |  |
|  | (WordPress PHP-FPM)     |         | wp_phpmyadmin           |  |
|  +-------------------------+         +-------------------------+  |
|               \                                   /               |
|                \   Red Interna Docker (internal_net) /                |
|                 v                               v                 |
|  +-------------------------------------------------------------+  |
|  | Contenedor 3: wp_db (MySQL 8.0 - Sin puerto público expuesto)|  |
|  +-------------------------------------------------------------+  |
|                                                                   |
+-------------------------------------------------------------------+
```

---

## 📁 Estructura del Proyecto Ansible

El código está estructurado en **roles modulares** de Ansible para maximizar la mantenibilidad, reutilización e idempotencia:

```text
cloud_1/
├── group_vars/
│   └── all/
│       ├── vars.yml          # Variables generales de configuración (rutas, dominio, BD)
│       └── vault.yml         # Secretos cifrados con Ansible Vault (contraseñas BD)
├── inventory.ini             # Inventario de servidores objetivo
├── site.yml                  # Playbook principal de orquestación
└── roles/
    ├── common/               # Preparación del SO base y firewall UFW
    │   └── tasks/
    │       └── main.yml
    ├── docker/               # Instalación del motor Docker y complemento Compose v2
    │   └── tasks/
    │       └── main.yml
    ├── app/                  # Plantillas Jinja2, despliegue Docker Compose y Handlers
    │   ├── handlers/
    │   │   └── main.yml      # Handler para reinicio automático de Nginx
    │   ├── tasks/
    │   │   └── main.yml
    │   └── templates/
    │       ├── docker-compose.yml.j2
    │       └── nginx.conf.j2
    └── testing/              # Suite de pruebas unitarias e integración
        └── tasks/
            ├── main.yml      # Orquestador maestro de tests
            ├── test_docker.yml # Prueba unitaria 1: Estado de los contenedores
            ├── test_http.yml   # Prueba unitaria 2: Respuestas HTTP (200 OK)
            └── test_db.yml     # Prueba unitaria 3: Salud de MySQL (ping)
```

---

## 🚀 Requisitos Previos

En el **nodo de control** (tu máquina local):
* Ansible `2.15+`
* Python `3.10+`

En los **nodes gestionados** (servidores remotos):
* Ubuntu 22.04 LTS (o similar)
* Acceso SSH con permisos de `sudo`
* Python instalado (incluido por defecto en Ubuntu)

---

## ⚙️ Configuración

### 1. Inventario (`inventory.ini`)
Define las direcciones IP o nombres de host de los servidores objetivo:

```ini
[webservers]
server-test ansible_host=192.168.1.53 ansible_user=osg
```

### 2. Variables Generales (`group_vars/all/vars.yml`)
```yaml
app_dir: "/opt/wordpress_app"
db_name: "wordpress_db"
db_user: "wp_user"
domain_name: "192.168.1.53" # O "_" para aceptar cualquier cabecera Host
```

### 3. Secretos Cifrados (`group_vars/all/vault.yml`)
Las contraseñas se almacenan cifradas utilizando **Ansible Vault**:

```bash
ansible-vault create group_vars/all/vault.yml
```

Contenido cifrado:
```yaml
db_root_password: "TuPasswordSuperSeguroRoot"
db_password: "TuPasswordSuperSeguroUsuario"
```

---

## 🛠️ Despliegue de la Infraestructura

Para ejecutar el despliegue completo de extremo a extremo:

```bash
ansible-playbook site.yml --ask-vault-pass
```

Este comando ejecutará en secuencia:
1. **Rol `common`**: Actualiza el sistema e instala paquetes básicos. Configura el firewall **UFW** permitiendo solo los puertos `22` (SSH), `80` (HTTP) y `443` (HTTPS).
2. **Rol `docker`**: Instala Docker Engine, el plugin Docker Compose v2 y habilita el demonio para arranque automático.
3. **Rol `app`**: Genera dinámicamente las plantillas `docker-compose.yml` y `nginx.conf`, levanta la pila de contenedores y configura los *handlers* de reinicio.
4. **Rol `testing`**: Ejecuta las pruebas de verificación integradas.

---

## 🧪 Pruebas Unitarias y de Integración

El proyecto incluye un rol dedicado (`testing`) estructurado en pruebas unitarias modulares.

### Ejecución de todas las pruebas
```bash
ansible-playbook site.yml --tags test --ask-vault-pass
```

### Ejecución de pruebas unitarias específicas por etiqueta

* **Estado de Contenedores Docker**:
  ```bash
  ansible-playbook site.yml --tags test_docker --ask-vault-pass
  ```
* **Endpoints y Redirecciones HTTP**:
  ```bash
  ansible-playbook site.yml --tags test_http --ask-vault-pass
  ```
* **Salud de la Base de Datos MySQL**:
  ```bash
  ansible-playbook site.yml --tags test_db --ask-vault-pass
  ```

---

## 📋 Cumplimiento de Requisitos del Proyecto

| Requisito | Estado | Implementación |
| :--- | :---: | :--- |
| **Reinicio Automático** | ✅ | Directiva `restart: unless-stopped` en Docker Compose y `systemctl enable docker`. |
| **Persistencia de Datos** | ✅ | Volúmenes persistentes y *bind mounts* para MySQL y uploads de WordPress. |
| **Despliegue Paralelo** | ✅ | Soportado nativamente por Ansible a través del inventario `[webservers]`. |
| **1 Proceso = 1 Contenedor** | ✅ | 4 contenedores aislados: Nginx, WordPress, MySQL y phpMyAdmin. |
| **Aislamiento de BD** | ✅ | MySQL expuesto solo en la red interna de Docker (`internal_net`), sin mapeo de puerto público. |
| **Seguridad de Puertos** | ✅ | Firewall UFW configurado para permitir únicamente los puertos 22, 80 y 443. |
| **Enrutamiento por URL** | ✅ | Nginx redirige `/` a WordPress y `/phpmyadmin/` a phpMyAdmin con `proxy_pass`. |
| **Organización en Roles** | ✅ | Estructura modular dividida en `common`, `docker`, `app` y `testing`. |
| **Gestión de Secretos** | ✅ | Contraseñas cifradas con **Ansible Vault** sin credenciales en código plano. |
| **Idempotencia** | ✅ | Uso exclusivo de módulos declarativos nativos de Ansible. |

---

## 🌐 Verificación Manual en Navegador

Una vez completado el despliegue, puedes acceder a los servicios desde tu navegador:

* **Sitio Web WordPress**: `http://192.168.1.53/`
* **Interfaz phpMyAdmin**: `http://192.168.1.53/phpmyadmin/`