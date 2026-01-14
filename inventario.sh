#!/bin/bash

# --- CORES ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}          RELATÓRIO TÉCNICO: SAGE - SYNALEIRA      ${NC}"
echo -e "${BLUE}          GERADO EM: $(date '+%d/%m/%Y %H:%M:%S')  ${NC}"
echo -e "${BLUE}====================================================${NC}"

# 1. CARACTERÍSTICAS DA MÁQUINA
echo -e "${GREEN}[1] CARACTERÍSTICAS E HARDWARE${NC}"
echo -e "OS:           $(hostnamectl | grep "Operating System" | cut -d: -f2- | xargs)"
echo -e "CPU:          $(nproc) Núcleos | RAM: $(free -h | grep Mem | awk '{print $2}')"
TOTAL_GB=$(lsblk -dnbo SIZE,TYPE | grep disk | awk '{s+=$1} END {printf "%.0f", s/1024/1024/1024}')
echo -e "Armazenamento: ${TOTAL_GB} GB"
echo ""

# 2. ENDEREÇOS DE REDE DA MÁQUINA
echo -e "${GREEN}[2] ENDEREÇOS DE REDE (INTERFACE | IP)${NC}"
ip -4 addr show | grep inet | grep -v "127.0.0.1" | awk '{print "  - IPv4 ("$NF"): "$2}'
ip -6 addr show scope global | grep inet6 | awk '{print "  - IPv6 ("$NF"): "$2}'
echo ""

# 3. QUEM CONECTA NESTE SERVIDOR (ENTRADA)
echo -e "${GREEN}[3] QUEM CONECTA NESTE SERVIDOR (ENTRADA)${NC}"
# -n garante IP, -t tcp, -u udp, state established
ss -ntu state established | grep -v "127.0.0.1" | while read -r line; do
    # Extrai porta local e IP remoto de forma robusta
    L_PORT=$(echo "$line" | awk '{print $4}' | awk -F: '{print $NF}')
    R_IP=$(echo "$line" | awk '{print $5}' | awk -F: '{print $(NF-1)}' | sed 's/\[//;s/\]//')
    
    if [[ "$L_PORT" =~ ^[0-9]+$ ]] && [ "$L_PORT" -lt 15000 ]; then
        # Resolve o nome do IP
        R_NAME=$(getent hosts "$R_IP" | awk '{print $2}')
        [ -z "$R_NAME" ] && R_NAME="IP Externo"
        echo -e "  <- IP: ${YELLOW}$R_IP${NC} (${R_NAME}) na porta local: ${GREEN}$L_PORT${NC}"
    fi
done | sort -u
echo ""

# 4. PARA ONDE O SERVIDOR ENVIA DADOS (SAÍDA)
echo -e "${GREEN}[4] PARA ONDE O SERVIDOR ENVIA DADOS (SAÍDA)${NC}"
ss -ntu state established | grep -v "127.0.0.1" | while read -r line; do
    L_PORT=$(echo "$line" | awk '{print $4}' | awk -F: '{print $NF}')
    R_ADDR=$(echo "$line" | awk '{print $5}')
    R_IP=$(echo "$R_ADDR" | awk -F: '{print $(NF-1)}' | sed 's/\[//;s/\]//')
    R_PORT=$(echo "$R_ADDR" | awk -F: '{print $NF}')

    if [[ "$L_PORT" =~ ^[0-9]+$ ]] && [ "$L_PORT" -ge 15000 ]; then
        R_NAME=$(getent hosts "$R_IP" | awk '{print $2}')
        [ -z "$R_NAME" ] && R_NAME="Servidor Remoto"
        
        # Tag especial se for BGP
        BGP_TAG=$([ "$R_PORT" == "179" ] && echo -e " ${RED}[BGP]${NC}" || echo "")
        echo -e "  -> Destino: ${YELLOW}$R_IP${NC} (${R_NAME}) na Porta Remota: ${GREEN}$R_PORT${NC}$BGP_TAG"
    fi
done | sort | uniq -c | sort -nr
echo ""

# 5. SERVIÇOS
echo -e "${GREEN}[5] SERVIÇOS ATIVOS${NC}"
[[ $(pgrep -f mariadbd) ]] && echo "  - MariaDB (Banco de Dados)"
[[ $(pgrep -f gobgpd) ]]   && echo "  - GoBGP (Roteador BGP)"
[[ $(pgrep -f gunicorn) ]] && echo "  - Gunicorn (App Python)"

echo -e "${BLUE}====================================================${NC}"
