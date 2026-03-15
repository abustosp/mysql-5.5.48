#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VERSIONS=("v1" "v2" "v3")
TIMEOUT=120
PASSED=0
FAILED=0

log_info() { echo -e "${YELLOW}[INFO]${NC} $*"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; }

wait_for_mysql() {
    local cid=$1
    local elapsed=0
    log_info "Esperando que MySQL esté listo..."
    while [ $elapsed -lt $TIMEOUT ]; do
        if docker exec "$cid" mysqladmin --protocol=tcp -h127.0.0.1 -P3306 -uroot -proot ping 2>/dev/null; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    return 1
}

test_version() {
    local VERSION=$1
    local IMAGE="abustosp/mysql:5.5.48-optimized-${VERSION}"
    
    echo ""
    echo "========================================"
    echo "  Testeando MySQL 5.5.48-${VERSION}"
    echo "  Imagen: ${IMAGE}"
    echo "========================================"
    
    echo ""
    log_info "Test 1: Verificar binario mysqld --version"
    if docker run --rm --entrypoint /usr/local/mysql/bin/mysqld "$IMAGE" --version 2>&1 | grep -q "5.5.48"; then
        log_pass "Version correcta: 5.5.48"
        ((PASSED++))
    else
        log_fail "Version incorrecta"
        ((FAILED++))
    fi
    
    echo ""
    log_info "Test 2: Inicializacion y primera conexion"
    local cid=""
    cid=$(docker run -d --rm \
        -e MYSQL_ROOT_PASSWORD=root \
        -e MYSQL_DATABASE=testdb \
        -e MYSQL_USER=testuser \
        -e MYSQL_PASSWORD=testpass \
        --name "mysql-test-${VERSION}" \
        "$IMAGE")
    
    if wait_for_mysql "$cid"; then
        log_pass "MySQL inicio correctamente"
        ((PASSED++))
    else
        log_fail "MySQL no inicio en ${TIMEOUT}s"
        docker rm -f "$cid" 2>/dev/null || true
        ((FAILED++))
        return 1
    fi
    
    echo ""
    log_info "Test 3: Conexion y consulta VERSION()"
    if docker exec "$cid" mysql --protocol=tcp -h127.0.0.1 -P3306 -uroot -proot -e "SELECT VERSION();" 2>&1 | grep -q "5.5.48"; then
        log_pass "Consulta VERSION() exitosa"
        ((PASSED++))
    else
        log_fail "Consulta VERSION() fallida"
        ((FAILED++))
    fi
    
    echo ""
    log_info "Test 4: Verificar base de datos creada"
    if docker exec "$cid" mysql --protocol=tcp -h127.0.0.1 -P3306 -uroot -proot -e "SHOW DATABASES;" 2>&1 | grep -q "testdb"; then
        log_pass "Base de datos testdb creada"
        ((PASSED++))
    else
        log_fail "Base de datos testdb no encontrada"
        ((FAILED++))
    fi
    
    echo ""
    log_info "Test 5: Verificar usuario creado"
    if docker exec "$cid" mysql --protocol=tcp -h127.0.0.1 -P3306 -uroot -proot -e "SELECT user FROM mysql.user WHERE user='testuser';" 2>&1 | grep -q "testuser"; then
        log_pass "Usuario testuser creado"
        ((PASSED++))
    else
        log_fail "Usuario testuser no encontrado"
        ((FAILED++))
    fi
    
    echo ""
    log_info "Test 6: Conexion con usuario no-root"
    if docker exec "$cid" mysql --protocol=tcp -h127.0.0.1 -P3306 -utestuser -ptestpass testdb -e "SELECT 1;" 2>&1 | grep -q "1"; then
        log_pass "Conexion con usuario testuser exitosa"
        ((PASSED++))
    else
        log_fail "Conexion con usuario testuser fallida"
        ((FAILED++))
    fi
    
    echo ""
    log_info "Test 7: Persistencia - reiniciar contenedor"
    docker restart "$cid" >/dev/null 2>&1
    sleep 5
    if wait_for_mysql "$cid"; then
        log_pass "Contenedor reinicio correctamente"
        ((PASSED++))
    else
        log_fail "Contenedor no reinicio correctamente"
        ((FAILED++))
    fi
    
    echo ""
    log_info "Test 8: Verificar datos persistidos"
    docker exec "$cid" mysql --protocol=tcp -h127.0.0.1 -P3306 -uroot -proot -e "CREATE TABLE IF NOT EXISTS testdb.persistance_test (id INT);" 2>/dev/null
    docker restart "$cid" >/dev/null 2>&1
    sleep 5
    wait_for_mysql "$cid" || true
    if docker exec "$cid" mysql --protocol=tcp -h127.0.0.1 -P3306 -uroot -proot -e "SHOW TABLES FROM testdb;" 2>&1 | grep -q "persistance_test"; then
        log_pass "Datos persistidos correctamente"
        ((PASSED++))
    else
        log_fail "Datos no persistidos"
        ((FAILED++))
    fi
    
    echo ""
    log_info "Test 9: MYSQL_RANDOM_ROOT_PASSWORD"
    local cid_rand=""
    cid_rand=$(docker run -d --rm \
        -e MYSQL_RANDOM_ROOT_PASSWORD=yes \
        --name "mysql-test-rand-${VERSION}" \
        "$IMAGE")
    
    sleep 8
    local rand_pass=""
    rand_pass=$(docker logs "$cid_rand" 2>&1 | grep "GENERATED ROOT PASSWORD" | sed 's/.*GENERATED ROOT PASSWORD: //')
    
    if [ -n "$rand_pass" ]; then
        if wait_for_mysql "$cid_rand"; then
            if docker exec "$cid_rand" mysql --protocol=tcp -h127.0.0.1 -P3306 -uroot -p"$rand_pass" -e "SELECT 1;" 2>&1 | grep -q "1"; then
                log_pass "MYSQL_RANDOM_ROOT_PASSWORD funciona"
                ((PASSED++))
            else
                log_fail "Password aleatorio no funciona"
                ((FAILED++))
            fi
        else
            log_fail "MySQL no inicio con password aleatorio"
            ((FAILED++))
        fi
        docker rm -f "$cid_rand" 2>/dev/null || true
    else
        log_fail "No se genero password aleatorio"
        ((FAILED++))
        docker rm -f "$cid_rand" 2>/dev/null || true
    fi
    
    echo ""
    log_info "Test 10: MYSQL_ALLOW_EMPTY_PASSWORD"
    local cid_empty=""
    cid_empty=$(docker run -d --rm \
        -e MYSQL_ALLOW_EMPTY_PASSWORD=yes \
        --name "mysql-test-empty-${VERSION}" \
        "$IMAGE")
    
    if wait_for_mysql "$cid_empty"; then
        if docker exec "$cid_empty" mysql --protocol=tcp -h127.0.0.1 -P3306 -uroot -e "SELECT 1;" 2>&1 | grep -q "1"; then
            log_pass "MYSQL_ALLOW_EMPTY_PASSWORD funciona"
            ((PASSED++))
        else
            log_fail "Conexion con empty password fallida"
            ((FAILED++))
        fi
    else
        log_fail "MySQL no inicio con empty password"
        ((FAILED++))
    fi
    docker rm -f "$cid_empty" 2>/dev/null || true
    
    docker rm -f "$cid" 2>/dev/null || true
    echo ""
}

echo "=============================================="
echo "  TEST SUITE: MySQL 5.5.48 (v1, v2, v3)"
echo "=============================================="

for VERSION in "${VERSIONS[@]}"; do
    test_version "$VERSION" || true
done

echo ""
echo "=============================================="
echo "  RESUMEN DE TESTS"
echo "=============================================="
echo -e "${GREEN}Pasados: ${PASSED}${NC}"
echo -e "${RED}Fallidos: ${FAILED}${NC}"
echo "=============================================="

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}Todos los tests pasaron!${NC}"
    exit 0
else
    echo -e "${RED}Algunos tests fallaron${NC}"
    exit 1
fi
