#!/bin/bash
set -Eeuo pipefail
shopt -s nullglob

docker_log() {
    echo "[Entrypoint] $*"
}

docker_error() {
    echo "[Entrypoint][ERROR] $*" >&2
}

# file_env VAR [DEFAULT]
# Allows passing secrets using VAR_FILE.
file_env() {
    local var="$1"
    local file_var="${var}_FILE"
    local def="${2:-}"
    local val="$def"

    if [ "${!var:-}" ] && [ "${!file_var:-}" ]; then
        docker_error "Both ${var} and ${file_var} are set (mutually exclusive)"
        exit 1
    fi

    if [ "${!var:-}" ]; then
        val="${!var}"
    elif [ "${!file_var:-}" ]; then
        val="$(< "${!file_var}")"
    fi

    export "$var"="$val"
    unset "$file_var"
}

mysql_escape_string() {
    printf "%s" "$1" | sed "s/'/''/g"
}

generate_random_password() {
    head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | cut -c1-32
}

mysql_socket=(/usr/local/mysql/bin/mysql --protocol=socket --socket=/var/run/mysqld/mysqld.sock -uroot)
mysqladmin_socket=(/usr/local/mysql/bin/mysqladmin --protocol=socket --socket=/var/run/mysqld/mysqld.sock -uroot)

if [ "${1:-}" = "mysqld" ]; then
    file_env "MYSQL_ROOT_PASSWORD"
    file_env "MYSQL_ALLOW_EMPTY_PASSWORD"
    file_env "MYSQL_RANDOM_ROOT_PASSWORD"
    file_env "MYSQL_ROOT_HOST"
    file_env "MYSQL_DATABASE"
    file_env "MYSQL_USER"
    file_env "MYSQL_PASSWORD"

    if [ -n "${MYSQL_USER:-}" ] && [ -z "${MYSQL_PASSWORD:-}" ]; then
        docker_error "MYSQL_USER is set but MYSQL_PASSWORD is not set"
        exit 1
    fi

    if [ -z "${MYSQL_USER:-}" ] && [ -n "${MYSQL_PASSWORD:-}" ]; then
        docker_log "MYSQL_PASSWORD is set but MYSQL_USER is not set; ignoring MYSQL_PASSWORD"
    fi

    if [ "${MYSQL_USER:-}" = "root" ]; then
        docker_error "MYSQL_USER cannot be 'root'; use MYSQL_ROOT_PASSWORD instead"
        exit 1
    fi

    if [ ! -d /var/lib/mysql/mysql ]; then
        if [ -z "${MYSQL_ROOT_PASSWORD:-}" ] && [ -z "${MYSQL_ALLOW_EMPTY_PASSWORD:-}" ] && [ -z "${MYSQL_RANDOM_ROOT_PASSWORD:-}" ]; then
            docker_error "Database is uninitialized and password option is not specified."
            docker_error "Set one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD or MYSQL_RANDOM_ROOT_PASSWORD."
            exit 1
        fi

        if [ -z "${MYSQL_ROOT_PASSWORD:-}" ] && [ -n "${MYSQL_RANDOM_ROOT_PASSWORD:-}" ]; then
            MYSQL_ROOT_PASSWORD="$(generate_random_password)"
            export MYSQL_ROOT_PASSWORD
            docker_log "GENERATED ROOT PASSWORD: ${MYSQL_ROOT_PASSWORD}"
        fi

        docker_log "Initializing database..."
        chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql

        /usr/local/mysql/scripts/mysql_install_db \
            --user=mysql \
            --datadir=/var/lib/mysql \
            --basedir=/usr/local/mysql

        docker_log "Starting temporary MySQL server..."
        /usr/local/mysql/bin/mysqld \
            --user=mysql \
            --datadir=/var/lib/mysql \
            --skip-networking \
            --socket=/var/run/mysqld/mysqld.sock &
        pid="$!"

        for i in {30..0}; do
            if "${mysqladmin_socket[@]}" ping --silent >/dev/null 2>&1; then
                break
            fi
            sleep 1
        done

        if [ "$i" = 0 ]; then
            docker_error "Unable to start temporary MySQL server."
            wait "$pid" || true
            exit 1
        fi

        docker_log "Configuring root user and optional database..."
        root_host="${MYSQL_ROOT_HOST:-%}"
        escaped_root_password="$(mysql_escape_string "${MYSQL_ROOT_PASSWORD:-}")"
        escaped_root_host="$(mysql_escape_string "$root_host")"

        root_password_sql=""
        root_remote_sql=""
        if [ -n "${MYSQL_ROOT_PASSWORD:-}" ]; then
            root_password_sql="SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${escaped_root_password}');"
            root_remote_sql="GRANT ALL ON *.* TO 'root'@'${escaped_root_host}' IDENTIFIED BY '${escaped_root_password}' WITH GRANT OPTION;"
        else
            root_remote_sql="GRANT ALL ON *.* TO 'root'@'${escaped_root_host}' WITH GRANT OPTION;"
        fi

        "${mysql_socket[@]}" <<-EOSQL
            DELETE FROM mysql.user WHERE user = '';
            DELETE FROM mysql.user WHERE user = 'root' AND host NOT IN ('localhost', '127.0.0.1', '::1');
            DROP DATABASE IF EXISTS test;
            DELETE FROM mysql.db WHERE Db = 'test' OR Db = 'test\\_%';
            ${root_password_sql}
            ${root_remote_sql}
            FLUSH PRIVILEGES;
EOSQL

        mysql_root_auth=("${mysql_socket[@]}")
        mysqladmin_root_auth=("${mysqladmin_socket[@]}")
        if [ -n "${MYSQL_ROOT_PASSWORD:-}" ]; then
            mysql_root_auth+=("-p${MYSQL_ROOT_PASSWORD}")
            mysqladmin_root_auth+=("-p${MYSQL_ROOT_PASSWORD}")
        fi

        if [ -n "${MYSQL_DATABASE:-}" ]; then
            docker_log "Creating database ${MYSQL_DATABASE}"
            escaped_database="$(printf "%s" "${MYSQL_DATABASE}" | sed 's/`/``/g')"
            "${mysql_root_auth[@]}" <<-EOSQL
                CREATE DATABASE IF NOT EXISTS \`${escaped_database}\`;
EOSQL
        fi

        if [ -n "${MYSQL_USER:-}" ] && [ -n "${MYSQL_PASSWORD:-}" ]; then
            docker_log "Creating user ${MYSQL_USER}"
            escaped_user="$(mysql_escape_string "${MYSQL_USER}")"
            escaped_password="$(mysql_escape_string "${MYSQL_PASSWORD}")"
            "${mysql_root_auth[@]}" <<-EOSQL
                CREATE USER '${escaped_user}'@'%' IDENTIFIED BY '${escaped_password}';
EOSQL

            if [ -n "${MYSQL_DATABASE:-}" ]; then
                escaped_database="$(printf "%s" "${MYSQL_DATABASE}" | sed 's/`/``/g')"
                "${mysql_root_auth[@]}" <<-EOSQL
                    GRANT ALL ON \`${escaped_database}\`.* TO '${escaped_user}'@'%';
                    FLUSH PRIVILEGES;
EOSQL
            fi
        fi

        for f in /docker-entrypoint-initdb.d/*; do
            case "$f" in
                *.sh)
                    docker_log "Running $f"
                    . "$f"
                    ;;
                *.sql)
                    docker_log "Running $f"
                    "${mysql_root_auth[@]}" < "$f"
                    ;;
                *.sql.gz)
                    docker_log "Running $f"
                    gunzip -c "$f" | "${mysql_root_auth[@]}"
                    ;;
                *)
                    docker_log "Ignoring $f"
                    ;;
            esac
        done

        docker_log "Stopping temporary MySQL server..."
        "${mysqladmin_root_auth[@]}" shutdown
        wait "$pid"
        docker_log "MySQL initialization complete"
    else
        chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql
    fi

    docker_log "Starting MySQL server..."
    exec /usr/local/mysql/bin/mysqld --datadir=/var/lib/mysql --user=mysql --socket=/var/run/mysqld/mysqld.sock
fi

exec "$@"
