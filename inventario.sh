#!/bin/bash

# --- CORES ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função para alinhar texto
print_line() { printf "${BLUE}====================================================${NC}\n"; }

print_line
echo -e "          ${BLUE}RELATÓRIO TÉCNICO: SAGE - SYNALEIRA${NC}      "
echo -e "          GERADO EM: $(date '+%d/%m/%Y %H:%M:%S')  "
print_line

# 1. HARDWARE (RAM e HD em GB)
echo -e "${GREEN}[1] CARACTERÍSTICAS E HARDWARE${NC}"
printf "%-20s %s\n" "Sistema:" "$(hostnamectl | grep "Operating System" | cut -d: -f2- | xargs)"
printf "%-20s %s\n" "CPU:" "$(nproc) Núcleos"

# RAM em GB (Padronizado)
RAM_TOTAL=$(free -g | grep Mem | awk '{print $2}')
RAM_USO=$(free -g | grep Mem | awk '{print $3}')
printf "%-20s %-10s %s\n" "Memória RAM:" "${RAM_TOTAL} GB" "(Em uso: ${RAM_USO} GB)"

# Armazenamento (Soma + Identificação de Thin/Thick)
TOTAL_GB=$(lsblk -dnbo SIZE,TYPE | grep disk | awk '{s+=$1} END {printf "%.0f", s/1024/1024/1024}')
DISC_MAIN=$(lsblk -dno NAME | grep -E '^sd|^nvme|^vd' | head -n 1)
DISCARD=$(cat /sys/block/$DISC_MAIN/queue/discard_max_bytes 2>/dev/null || echo 0)

# Se DISCARD > 0 é Thin, caso contrário é Thick
if [ "$DISCARD" -gt 0 ]; then PROV="Thin"; else PROV="Thick"; fi

printf "%-20s %-10s %s\n" "Armazenamento:" "${TOTAL_GB} GB" "($PROV Provisioning)"
echo -n "Discos detectados: "
lsblk -dno NAME,SIZE | awk '{printf "[%s: %s] ", $1, $2}'
echo -e "\n"

# 2. REDE DA MÁQUINA
echo -e "${GREEN}[2] ENDEREÇOS DE REDE (IPs)${NC}"
ip -4 addr show | grep inet | grep -v "127.0.0.1" | awk '{printf "  %-12s %-18s %s\n", "IPv4", $2, "("$NF")"}'
ip -6 addr show scope global | grep inet6 | awk '{printf "  %-12s %-18s %s\n", "IPv6", $2, "("$NF")"}'
echo ""

# 3. ENTRADA (INBOUND)
echo -e "${GREEN}[3] QUEM CONECTA NESTE SERVIDOR (ENTRADA)${NC}"
printf "  %-18s %-20s %-10s\n" "IP ORIGEM" "NOME/HOST" "PORTA LOCAL"
ss -ntu state established | grep -v "127.0.0.1" | while read -r line; do
    L_PORT=$(echo "$line" | awk '{print $4}' | awk -F: '{print $NF}')
    R_IP=$(echo "$line" | awk '{print $5}' | awk -F: '{print $(NF-1)}' | sed 's/\[//;s/\]//')
    
    if [[ "$L_PORT" =~ ^[0-9]+$ ]] && [ "$L_PORT" -lt 15000 ]; then
        R_NAME=$(getent hosts "$R_IP" | awk '{print $2}')
        [ -z "$R_NAME" ] && R_NAME="--"
        printf "  %-18s %-20s ${GREEN}%-10s${NC}\n" "$R_IP" "$R_NAME" "$L_PORT"
    fi
done | sort -u
echo ""

# 4. SAÍDA (OUTBOUND)
echo -e "${GREEN}[4] PARA ONDE O SERVIDOR ENVIA DADOS (SAÍDA)${NC}"
printf "  %-18s %-20s %-10s %-5s\n" "IP DESTINO" "NOME/HOST" "PORTA REM" "TIPO"
ss -ntu state established | grep -v "127.0.0.1" | while read -r line; do
    L_PORT=$(echo "$line" | awk '{print $4}' | awk -F: '{print $NF}')
    R_IP_PORT=$(echo "$line" | awk '{print $5}')
    R_IP=$(echo "$R_IP_PORT" | awk -F: '{print $(NF-1)}' | sed 's/\[//;s/\]//')
    R_PORT=$(echo "$R_IP_PORT" | awk -F: '{print $NF}')

    if [[ "$L_PORT" =~ ^[0-9]+$ ]] && [ "$L_PORT" -ge 15000 ]; then
        R_NAME=$(getent hosts "$R_IP" | awk '{print $2}')
        [ -z "$R_NAME" ] && R_NAME="--"
        BGP_TAG=$([ "$R_PORT" == "179" ] && echo "BGP" || echo "")
        printf "  %-18s %-20s ${GREEN}%-10s${NC} %-5s\n" "$R_IP" "$R_NAME" "$R_PORT" "$BGP_TAG"
    fi
done | sort | uniq | sort -nr
echo ""

# 5. SERVIÇOS
echo -e "${GREEN}[5] SERVIÇOS ATIVOS${NC}"
[[ $(pgrep -f mariadbd) ]] && printf "  %-25s %s\n" "Banco de Dados:" "MariaDB Online"
[[ $(pgrep -f gobgpd) ]]   && printf "  %-25s %s\n" "Protocolo BGP:" "GoBGP Ativo"
[[ $(pgrep -f gunicorn) ]] && printf "  %-25s %s\n" "App Python:" "Gunicorn Rodando"

print_line
