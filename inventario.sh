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
echo -e "Sistema Operacional:  $(hostnamectl | grep "Operating System" | cut -d: -f2- | xargs)"
echo -e "Provisionamento CPU:  $(nproc) Núcleos (vCPUs)"
echo -e "Memória RAM Total:    $(free -h | grep Mem | awk '{print $2}')"

# Soma de todos os discos físicos (GB)
TOTAL_GB=$(lsblk -dnbo SIZE,TYPE | grep disk | awk '{s+=$1} END {printf "%.0f", s/1024/1024/1024}')
# Verificação de Thin/Thick no disco principal
DISC_MAIN=$(lsblk -dno NAME | head -n 1)
DISCARD=$(cat /sys/block/$DISC_MAIN/queue/discard_max_bytes 2>/dev/null || echo 0)
PROV=$([ "$DISCARD" -gt 0 ] && echo "Thin" || echo "Thick")

echo -e "Armazenamento (HD):   ${TOTAL_GB} GB - $PROV Provisioning"
echo ""

# 2. ENDEREÇOS DE REDE DA MÁQUINA (IPS CONFIGURADOS)
echo -e "${GREEN}[2] ENDEREÇOS DE REDE (INTERFACE | IP)${NC}"
echo "IPv4:"
ip -4 -o addr show | grep -v "lo" | awk '{print "  - Interface: " $2 " | IP: " $4}'
echo "IPv6:"
ip -6 -o addr show scope global | awk '{print "  - Interface: " $2 " | IP: " $4}'
echo ""

# 3. QUEM CONECTA NA GENTE (ENTRADA - INBOUND)
echo -e "${GREEN}[3] QUEM CONECTA NESTE SERVIDOR (ENTRADA)${NC}"
# Filtra conexões estabelecidas em portas de serviço comuns
ss -tunp state established | grep -v "127.0.0.1" | while read -r line; do
    L_PORT=$(echo "$line" | awk '{print $5}' | awk -F: '{print $NF}')
    R_IP=$(echo "$line" | awk '{print $6}' | awk -F: '{print $(NF-1)}' | sed 's/\[//;s/\]//')
    
    # Se a porta local for baixa, é alguém acessando nosso serviço
    if [[ "$L_PORT" =~ ^[0-9]+$ ]] && [ "$L_PORT" -lt 15000 ]; then
        R_HOST=$(getent hosts "$R_IP" | awk '{print $2}')
        echo -e "  <- ORIGEM: ${YELLOW}$R_IP${NC} (${R_HOST:-Externo}) -> Porta Local: ${GREEN}$L_PORT${NC}"
    fi
done | sort -u
echo ""

# 4. ONDE NÓS NOS CONECTAMOS (SAÍDA - OUTBOUND)
echo -e "${GREEN}[4] PARA ONDE O SERVIDOR ENVIA DADOS (SAÍDA)${NC}"
ss -tunp state established | grep -v "127.0.0.1" | while read -r line; do
    L_PORT=$(echo "$line" | awk '{print $5}' | awk -F: '{print $NF}')
    R_IP_PORT=$(echo "$line" | awk '{print $6}')
    R_IP=$(echo "$R_IP_PORT" | awk -F: '{print $(NF-1)}' | sed 's/\[//;s/\]//')
    R_PORT=$(echo "$R_IP_PORT" | awk -F: '{print $NF}')

    # Se a porta local for alta, a conexão partiu de nós
    if [[ "$L_PORT" =~ ^[0-9]+$ ]] && [ "$L_PORT" -gt 15000 ]; then
        R_HOST=$(getent hosts "$R_IP" | awk '{print $2}')
        echo -e "  -> DESTINO: ${YELLOW}$R_IP${NC} (${R_HOST:-Servidor Remoto}) -> Porta Remota: ${GREEN}$R_PORT${NC}"
    fi
done | sort | uniq -c | sort -nr
echo ""

# 5. SERVIÇOS ATIVOS (O QUE A MÁQUINA FAZ)
echo -e "${GREEN}[5] SERVIÇOS EM EXECUÇÃO (FUNÇÃO)${NC}"
[[ $(pgrep -f mariadbd) ]] && echo -e "  - SERVIÇO: Banco de Dados (MariaDB/MySQL)"
[[ $(pgrep -f gobgpd) ]]  && echo -e "  - SERVIÇO: Roteador BGP (GoBGP)"
[[ $(pgrep -f gunicorn) ]] && echo -e "  - SERVIÇO: Aplicação Python (Gunicorn)"
[[ $(pgrep -f nginx) ]]    && echo -e "  - SERVIÇO: Proxy Reverso (Nginx)"
[[ $(pgrep -f dockerd) ]]  && echo -e "  - SERVIÇO: Container Host (Docker)"

echo -e "${BLUE}====================================================${NC}"
