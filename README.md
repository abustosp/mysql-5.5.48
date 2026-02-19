# MySQL 5.5.48 Docker Project

Este proyecto dockeriza MySQL versión 5.5.48 con una imagen base moderna de Ubuntu 20.04 para compatibilidad con Docker Engine v28.2+.

## Requisitos

- Docker Engine 20.10 o superior
- Docker Compose v2 o superior

## Configuración

La imagen soporta las mismas variables de entorno principales de los contenedores oficiales de `mysql`:

- `MYSQL_ROOT_PASSWORD`
- `MYSQL_ALLOW_EMPTY_PASSWORD`
- `MYSQL_RANDOM_ROOT_PASSWORD`
- `MYSQL_ROOT_HOST`
- `MYSQL_DATABASE`
- `MYSQL_USER`
- `MYSQL_PASSWORD`
- variantes `*_FILE` para secretos (por ejemplo `MYSQL_ROOT_PASSWORD_FILE`)

Para una base vacía, debes usar una de estas opciones:

- `MYSQL_ROOT_PASSWORD`, o
- `MYSQL_ALLOW_EMPTY_PASSWORD`, o
- `MYSQL_RANDOM_ROOT_PASSWORD`

## Uso

### Construir y ejecutar con Docker Compose

```bash
docker compose up -d
```

### Construir imagen manualmente

```bash
docker build -t mysql-5.5.48 .
```

### Ejecutar contenedor manualmente

```bash
docker run -d \
  --name mysql-5.5.48 \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=mydb \
  -e MYSQL_USER=user \
  -e MYSQL_PASSWORD=password \
  -p 3306:3306 \
  -v mysql_data:/var/lib/mysql \
  mysql-5.5.48
```

También puedes usar, igual que en la imagen oficial:

```bash
# Permitir root sin password (solo desarrollo)
-e MYSQL_ALLOW_EMPTY_PASSWORD=yes

# Generar password aleatorio para root
-e MYSQL_RANDOM_ROOT_PASSWORD=yes

# Cargar secretos desde archivos
-e MYSQL_ROOT_PASSWORD_FILE=/run/secrets/mysql_root_password
```

### Conectarse a MySQL

```bash
docker exec -it mysql-5.5.48 mysql -uroot -proot
```

O desde el host:

```bash
mysql -h 127.0.0.1 -P 3306 -uuser -ppassword mydb
```

### Detener el contenedor

```bash
docker compose down
```

### Detener y eliminar volúmenes

```bash
docker compose down -v
```

### Ver logs del contenedor

```bash
docker compose logs -f mysql
```

## Scripts de inicialización

Puedes agregar scripts SQL en el directorio `init/` para que se ejecuten automáticamente al iniciar el contenedor por primera vez. Los archivos se procesan en orden alfabético.

Ejemplo de script incluido: `init/01-init.sql`

## Estructura del proyecto

```
.
├── Dockerfile              # Imagen basada en Ubuntu 20.04 con MySQL 5.5.48
├── docker-compose.yml      # Configuración de Docker Compose
├── docker-entrypoint.sh    # Script de inicialización y arranque
├── README.md               # Este archivo
├── .env.example            # Plantilla de variables de entorno
├── .gitignore              # Archivos a ignorar en Git
└── init/                   # Scripts de inicialización SQL
    └── 01-init.sql         # Script de ejemplo
```

## Detalles técnicos

- **Imagen base**: Ubuntu 20.04 LTS (compatible con Docker moderno)
- **MySQL**: Binarios oficiales precompilados versión 5.5.48
- **Formato de imagen**: Docker Image Format v2, Schema 2 (compatible con Docker Engine v28.2+)
- **Persistencia**: Volumen Docker para datos de MySQL
- **Reinicio automático**: El contenedor se reinicia automáticamente en caso de fallo

## Notas importantes

- MySQL 5.5.48 es una versión antigua (lanzada en 2015) que ya no recibe soporte oficial
- Se recomienda usar solo para desarrollo, pruebas o compatibilidad con sistemas legacy
- Para producción, considere actualizar a MySQL 8.0 o superior
- Los datos persisten en un volumen Docker llamado `mysql_data`
- El script `docker-entrypoint.sh` maneja la inicialización automática de la base de datos
