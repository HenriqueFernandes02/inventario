#!/bin/bash

# --- CORES ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}          RELATÓRIO DE INVENTÁRIO TÉCNICO          ${NC}"
echo -e "${BLUE}====================================================${NC}"

# 1. CARACTERÍSTICAS E HARDWARE
echo -e "${GREEN}[1] CARACTERÍSTICAS E HARDWARE${NC}"
echo -e "Sistema Operacional:  $(hostnamectl | grep "Operating System" | cut -d: -f2- | xargs)"
echo -e "Provisionamento CPU:  $(nproc) Núcleos (vCPUs)"
echo -e "Memória RAM Total:    $(free -g | grep Mem | awk '{print $2 " GB"}')"

# Lógica de Soma de HD e Provisionamento em GB
TOTAL_GB=$(lsblk -dnbo SIZE | awk '{s+=$1} END {printf "%.0f", s/1024/1024/1024}')

# Verifica o tipo de provisionamento (Thin ou Thick)
DISC_MAIN=$(lsblk -dno NAME | head -n 1)
DISCARD=$(cat /sys/block/$DISC_MAIN/queue/discard_max_bytes 2>/dev/null || echo 0)

if [ "$DISCARD" -gt 0 ]; then
    PROV="Thin"
else
    PROV="Thick"
fi

echo -e "Armazenamento (HD):   ${TOTAL_GB} GB - $PROV"
echo ""

# 2. ENDEREÇOS DE REDE (IPV4/IPV6)
echo -e "${GREEN}[2] ENDEREÇOS DE REDE (IPV4/IPV6)${NC}"
echo "IPv4:"
ip -4 addr show | grep inet | grep -v "127.0.0.1" | awk '{print "  - " $2}'

echo "IPv6:"
# Mantendo o IPv6 Global (o seu cafe:c0de) e limpando os fe80 irrelevantes
ip -6 addr show | grep inet6 | grep "global" | awk '{print "  - " $2}'
echo ""

# 3. CONEXÕES ATIVAS
echo -e "${GREEN}[3] FLUXO DE CONEXÕES ATIVAS${NC}"
ss -tunp | grep ESTAB | grep -v "127.0.0.1" | while read line; do
    R_IP=$(echo $line | awk '{print $6}' | cut -d] -f1 | sed 's/\[//' | cut -d: -f1)
    R_HOST=$(getent hosts $R_IP | awk '{print $2}')
    [ -z "$R_HOST" ] && R_HOST="Host Externo"
    echo -e "  - Destino: $R_IP (${YELLOW}$R_HOST${NC})"
done
echo ""

# 4. FUNÇÃO DA MÁQUINA
echo -e "${GREEN}[4] FUNÇÃO E SERVIÇOS EM EXECUÇÃO${NC}"
if systemctl is-active --quiet docker; then
    echo -e "Função Primária: ${BLUE}Docker Host / Swarm Node${NC}"
    echo "Containers ativos agora:"
    docker ps --format "  - {{.Names}} ({{.Image}})"
fi

if ps aux | grep -iq "gunicorn"; then
    echo -e "Serviço Detectado: ${BLUE}Aplicação Python (Gunicorn)${NC}"
fi

echo -e "${BLUE}====================================================${NC}"
