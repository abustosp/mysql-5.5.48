# MySQL 5.5.48 Optimized Docker Image

Proyecto para ejecutar MySQL `5.5.48` en Docker moderno con foco en compatibilidad legacy y reducción agresiva de tamaño de imagen.

## Objetivo

- Mantener MySQL 5.5.48 funcional en entornos Docker actuales.
- Ofrecer variantes `v1`, `v2` y `v3` con documentacion clara de diferencias.
- Proveer un entrypoint compatible con variables estilo imagen oficial de `mysql`.

## Requisitos

- Docker Engine 20.10 o superior
- Docker Compose v2 o superior

## Resumen Rapido

- Imagen por defecto en `docker-compose.yml`: `abustosp/mysql:5.5.48-optimized-v3`
- Tag recomendada: `abustosp/mysql:5.5.48-optimized-v3`
- Puerto: `3306`
- Data dir: `/var/lib/mysql`
- Archivos versionados disponibles: `Dockerfile.v1`, `Dockerfile.v2`, `Dockerfile.v3`

## Diferencias Entre Versiones

| Variante | Tag Docker Hub | Tamaño aprox | Cambios principales | Estado |
|---|---|---:|---|---|
| `optimized-v1` | `abustosp/mysql:5.5.48-optimized-v1` | `~700MB+` | Build simple de una etapa, sin optimizacion agresiva | Lista para build/publicacion |
| `optimized-v2` | `abustosp/mysql:5.5.48-optimized-v2` | `~662MB` | Multi-stage, limpieza de artefactos, runtime reducido | Publicada |
| `optimized-v3` | `abustosp/mysql:5.5.48-optimized-v3` | `~258MB` | Todo lo de v2 + `strip` de binarios + runtime mas minimo + arranque directo `mysqld` | Publicada y recomendada |

### Benchmark de Arranque (referencia)

Medicion de readiness con `mysqladmin ping`:

- `optimized-v2`: promedio `~5.50s`
- `optimized-v3`: promedio `~5.00s`

Los valores pueden variar segun CPU, disco y cache local.

## Tags Publicadas

- `abustosp/mysql:5.5.48-optimized-v1`
- `abustosp/mysql:5.5.48-optimized-v2`
- `abustosp/mysql:5.5.48-optimized-v3`

Digests de referencia:

- `abustosp/mysql:5.5.48-optimized-v2` -> `sha256:ba61ded762970b32964a1a96fc25650c38ce56847f5b1365e82948f338318d5e`
- `abustosp/mysql:5.5.48-optimized-v3` -> `sha256:09d7fe9719a45a7e8b52cb04dc1c28b7d7e2b86af8391022a6da4b0742745f8c`

## Uso Con Docker Compose

`docker-compose.yml` ya apunta a `v3`.

Si quieres parametrizar credenciales/DB, copia `.env.example` a `.env` y ajusta valores.

```bash
docker compose up -d
docker compose logs -f mysql
```

Detener:

```bash
docker compose down
```

Eliminar tambien datos:

```bash
docker compose down -v
```

## Uso Con Docker Run

```bash
docker run -d \
  --name mysql-5.5.48 \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=mydb \
  -e MYSQL_USER=user \
  -e MYSQL_PASSWORD=password \
  -p 3306:3306 \
  -v mysql_data:/var/lib/mysql \
  abustosp/mysql:5.5.48-optimized-v3
```

Conexion desde host:

```bash
mysql -h 127.0.0.1 -P 3306 -uuser -ppassword mydb
```

## Variables De Entorno Soportadas

Compatibles con el estilo de la imagen oficial:

- `MYSQL_ROOT_PASSWORD`
- `MYSQL_ALLOW_EMPTY_PASSWORD`
- `MYSQL_RANDOM_ROOT_PASSWORD`
- `MYSQL_ROOT_HOST`
- `MYSQL_DATABASE`
- `MYSQL_USER`
- `MYSQL_PASSWORD`
- `*_FILE` para secretos, por ejemplo `MYSQL_ROOT_PASSWORD_FILE`

Regla de inicializacion:

- Debes definir una de estas opciones: `MYSQL_ROOT_PASSWORD` o `MYSQL_ALLOW_EMPTY_PASSWORD` o `MYSQL_RANDOM_ROOT_PASSWORD`.

Notas:

- Si defines `MYSQL_USER`, debes definir `MYSQL_PASSWORD`.
- `MYSQL_USER=root` no esta permitido.

## Inicializacion Con Scripts SQL

Los archivos en `/docker-entrypoint-initdb.d` se ejecutan solo en el primer arranque (cuando el datadir esta vacio):

- `*.sh`
- `*.sql`
- `*.sql.gz`

En este repo existe `init/01-init.sql` como ejemplo.

Importante:

- `init/01-init.sql` usa `USE mydb;`.
- Si cambias `MYSQL_DATABASE`, ajusta ese script o agrega uno propio.

## Crear V1 V2 V3

### Opcion 1: Script unico

```bash
./build-versions.sh
```

### Opcion 2: Build manual por version

```bash
docker build -f Dockerfile.v1 -t mysql-5.5.48:optimized-v1 -t abustosp/mysql:5.5.48-optimized-v1 .
docker build -f Dockerfile.v2 -t mysql-5.5.48:optimized-v2 -t abustosp/mysql:5.5.48-optimized-v2 .
docker build -f Dockerfile.v3 -t mysql-5.5.48:optimized-v3 -t abustosp/mysql:5.5.48-optimized-v3 .
```

### Opcion 3: Compose solo para build

```bash
docker compose -f docker-compose.versions.yml build
```

## Publicar Nuevas Versiones En Docker Hub

### Push con script

```bash
./push-versions.sh
```

### Push manual

```bash
docker push abustosp/mysql:5.5.48-optimized-v1
docker push abustosp/mysql:5.5.48-optimized-v2
docker push abustosp/mysql:5.5.48-optimized-v3
```

## Verificacion Rapida De Funcionamiento

```bash
docker run --rm --entrypoint /usr/local/mysql/bin/mysqld \
  abustosp/mysql:5.5.48-optimized-v3 --version
```

Prueba funcional basica:

```bash
cid=$(docker run -d --rm -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=benchdb abustosp/mysql:5.5.48-optimized-v3)
for t in $(seq 1 120); do
  docker exec "$cid" /usr/local/mysql/bin/mysqladmin --protocol=tcp -h127.0.0.1 -P3306 -uroot -proot ping && break
  sleep 1
done
docker exec "$cid" /usr/local/mysql/bin/mysql --protocol=tcp -h127.0.0.1 -P3306 -uroot -proot -e "SELECT VERSION();"
docker rm -f "$cid"
```

## Estructura Del Repositorio

```text
.
├── Dockerfile
├── Dockerfile.v1
├── Dockerfile.v2
├── Dockerfile.v3
├── docker-compose.yml
├── docker-compose.versions.yml
├── docker-entrypoint.sh
├── .dockerignore
├── .env.example
├── build-versions.sh
├── push-versions.sh
├── README.md
└── init/
    └── 01-init.sql
```

Descripcion:

- `Dockerfile`: build multi-stage y optimizaciones de tamano.
- `Dockerfile.v1`: variante base con menor optimizacion.
- `Dockerfile.v2`: variante multi-stage optimizada.
- `Dockerfile.v3`: variante mas optimizada (recomendada).
- `docker-entrypoint.sh`: inicializacion del datadir, usuarios, DB y scripts `initdb.d`.
- `docker-compose.yml`: stack local con tag `abustosp/mysql:5.5.48-optimized-v3`.
- `docker-compose.versions.yml`: definicion de build para V1, V2 y V3.
- `.env.example`: variables sugeridas.
- `.dockerignore`: reduce contexto de build (evita incluir `mysql_data/`, `.git/`, etc.).
- `build-versions.sh`: construye V1, V2 y V3 en un solo paso.
- `push-versions.sh`: publica V1, V2 y V3 en Docker Hub.
- `init/01-init.sql`: script SQL de ejemplo para primer arranque.

## Detalles Tecnicos

- Build multi-stage.
- Base runtime: `ubuntu:20.04`.
- Binario MySQL: `mysql-5.5.48-linux2.6-x86_64` (oficial legacy).
- Optimizaciones clave: `apt --no-install-recommends`, eliminacion de `mysql-test/sql-bench/docs/man/include`, `strip --strip-unneeded`, runtime sin `mysqld_safe` ni `perl`.
- Persistencia: volumen en `/var/lib/mysql`.

## Troubleshooting

### Error de inicializacion por password

Si aparece:

`Database is uninitialized and password option is not specified`

Define una de estas variables:

- `MYSQL_ROOT_PASSWORD`
- `MYSQL_ALLOW_EMPTY_PASSWORD=yes` (solo desarrollo)
- `MYSQL_RANDOM_ROOT_PASSWORD=yes`

### Scripts SQL no se ejecutan

- Solo se ejecutan en primer arranque con datadir vacio.
- Si ya hay datos en `mysql_data/`, elimina el volumen/carpeta y recrea.

### No conecta desde host

- Verifica mapeo `3306:3306`.
- Revisa que el contenedor este listo en logs.

## Seguridad Y Limitaciones

- MySQL 5.5.48 es EOL (sin soporte y sin parches de seguridad).
- Recomendado para entornos legacy, pruebas o migracion temporal.
- No recomendado para nuevas cargas productivas.
