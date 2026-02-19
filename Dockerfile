FROM ubuntu:20.04

# Evitar interacciones durante la instalación
ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependencias necesarias
RUN apt-get update && \
    apt-get install -y \
    wget \
    libaio1 \
    libncurses5 \
    libnuma1 \
    perl \
    pwgen \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Descargar e instalar MySQL 5.5.48
RUN mkdir -p /tmp/mysql && \
    cd /tmp/mysql && \
    wget https://downloads.mysql.com/archives/get/p/23/file/mysql-5.5.48-linux2.6-x86_64.tar.gz && \
    tar -xzf mysql-5.5.48-linux2.6-x86_64.tar.gz && \
    mv mysql-5.5.48-linux2.6-x86_64 /usr/local/mysql && \
    rm -rf /tmp/mysql

# Crear usuario y grupo mysql
RUN groupadd -r mysql && useradd -r -g mysql mysql

# Crear directorios necesarios
RUN mkdir -p /var/lib/mysql /var/run/mysqld /var/log/mysql /docker-entrypoint-initdb.d && \
    chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql && \
    chmod 775 /var/run/mysqld

# Configurar PATH
ENV PATH=/usr/local/mysql/bin:/usr/local/mysql/scripts:$PATH

# Copiar script de inicialización
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
    ln -s /usr/local/bin/docker-entrypoint.sh /entrypoint.sh

VOLUME /var/lib/mysql

EXPOSE 3306

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["mysqld"]
