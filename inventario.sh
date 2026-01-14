#!/bin/bash

# --- CORES ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}          RELATÓRIO DE INVENTÁRIO COMPLETO         ${NC}"
echo -e "${BLUE}          GERADO EM: $(date '+%d/%m/%Y %H:%M:%S')  ${NC}"
echo -e "${BLUE}====================================================${NC}"

# 1. ESPECIFICAÇÕES DE HARDWARE
echo -e "${GREEN}[1] ESPECIFICAÇÕES DE HARDWARE${NC}"
echo -e "Sistema Operacional:  $(hostnamectl | grep "Operating System" | cut -d: -f2- | xargs)"
echo -e "Provisionamento CPU:  $(nproc) Núcleos (vCPUs)"
echo -e "Memória RAM Total:    $(free -h | grep Mem | awk '{print $2}')"

# Soma de HD inteligente (apenas discos reais)
TOTAL_GB=$(lsblk -dnbo SIZE,TYPE | grep disk | awk '{s+=$1} END {printf "%.0f", s/1024/1024/1024}')
DISC_MAIN=$(lsblk -dno NAME | head -n 1)
DISCARD=$(cat /sys/block/$DISC_MAIN/queue/discard_max_bytes 2>/dev/null || echo 0)
PROV=$([ "$DISCARD" -gt 0 ] && echo "Thin" || echo "Thick")
echo -e "Armazenamento (HD):   ${TOTAL_GB} GB - $PROV Provisioning"
echo ""

# 2. ENDEREÇOS DE REDE
echo -e "${GREEN}[2] ENDEREÇOS DE REDE${NC}"
ip -4 addr show | grep inet | grep -v "127.0.0.1" | awk '{print "  - IPv4: " $2 " ("$NF")"}'
ip -6 addr show scope global | grep inet6 | awk '{print "  - IPv6: " $2}'
echo ""

# 3. FLUXO DE CONEXÕES COM RESOLUÇÃO DE NOMES
echo -e "${GREEN}[3] FLUXO DE COMUNICAÇÃO DE REDE${NC}"

echo -e "${BLUE}<- QUEM CONECTA NESTE SERVIDOR (ENTRADA):${NC}"
# Extrai conexões, resolve nomes e organiza
ss -tunp state established | grep -vE "Netid|127.0.0.1" | while read -r line; do
    L_PORT=$(echo "$line" | awk '{print $5}' | awk -F: '{print $NF}')
    R_IP=$(echo "$line" | awk '{print $6}' | awk -F: '{print $(NF-1)}' | sed 's/\[//;s/\]//')
    
    # Se a porta local for de serviço (SSH, DB, BGP...)
    if [[ "$L_PORT" =~ ^[0-9]+$ ]] && [ "$L_PORT" -lt 15000 ]; then
        # Tenta resolver o nome da máquina (DNS ou /etc/hosts)
        HOSTNAME_REMOTO=$(getent hosts "$R_IP" | awk '{print $2}')
        INFO_REMOTO="${YELLOW}$R_IP${NC}"
        [ ! -z "$HOSTNAME_REMOTO" ] && INFO_REMOTO="${YELLOW}$R_IP${NC} ($HOSTNAME_REMOTO)"
        
        echo -e "  - Origem: $INFO_REMOTO -> na nossa Porta: ${GREEN}$L_PORT${NC}"
    fi
done | sort -u

echo -e "\n${BLUE}-> ONDE ESTE SERVIDOR SE CONECTA (SAÍDA):${NC}"
ss -tunp state established | grep -vE "Netid|127.0.0.1" | while read -r line; do
    L_PORT=$(echo "$line" | awk '{print $5}' | awk -F: '{print $NF}')
    R_IP_PORT=$(echo "$line" | awk '{print $6}')
    R_IP=$(echo "$R_IP_PORT" | awk -F: '{print $(NF-1)}' | sed 's/\[//;s/\]//')
    R_PORT=$(echo "$R_IP_PORT" | awk -F: '{print $NF}')
    
    # Se a porta local for alta, nós iniciamos a conexão
    if [[ "$L_PORT" =~ ^[0-9]+$ ]] && [ "$L_PORT" -gt 15000 ]; then
        HOSTNAME_REMOTO=$(getent hosts "$R_IP" | awk '{print $2}')
        INFO_REMOTO="${YELLOW}$R_IP${NC}"
        [ ! -z "$HOSTNAME_REMOTO" ] && INFO_REMOTO="${YELLOW}$R_IP${NC} ($HOSTNAME_REMOTO)"
        
        echo -e "  - Destino: $INFO_REMOTO -> na Porta Remota: ${GREEN}$R_PORT${NC}"
    fi
done | sort | uniq -c | sort -nr
echo ""

# 4. FUNÇÃO E ALERTAS
echo -e "${GREEN}[4] FUNÇÃO DA MÁQUINA E ALERTAS${NC}"
[[ $(pgrep -f mariadbd) ]] && echo -e "Função: ${BLUE}Banco de Dados (MariaDB/MySQL)${NC}"
[[ $(pgrep -f gobgpd) ]] && echo -e "Função: ${BLUE}Roteamento BGP (GoBGP)${NC}"
[[ $(pgrep -f gunicorn) ]] && echo -e "Função: ${BLUE}Servidor de Aplicação (Gunicorn)${NC}"

if [ -s /var/mail/root ]; then
    LAST_MAIL=$(grep "Subject:" /var/mail/root | tail -n 1)
    echo -e "${RED}AVISO MAIL:${NC} ${YELLOW}${LAST_MAIL}${NC}"
fi

echo -e "Carga do Sistema (Load): $(uptime | awk -F'load average:' '{print $2}')"
echo -e "${BLUE}====================================================${NC}"
