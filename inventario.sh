#!/bin/bash

# --- CORES ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}          INVENTÁRIO COMPLETO: SAGE - SYNALEIRA    ${NC}"
echo -e "${BLUE}          GERADO EM: $(date '+%d/%m/%Y %H:%M:%S')  ${NC}"
echo -e "${BLUE}====================================================${NC}"

# 1. HARDWARE E PERFORMANCE
echo -e "${GREEN}[1] ESPECIFICAÇÕES DE HARDWARE E CARGA${NC}"
echo -e "Sistema:        $(hostnamectl | grep "Operating System" | cut -d: -f2- | xargs)"
echo -e "CPU:            $(nproc) Núcleos | RAM: $(free -h | grep Mem | awk '{print $2}')"
TOTAL_GB=$(lsblk -dnbo SIZE,TYPE | grep disk | awk '{s+=$1} END {printf "%.0f", s/1024/1024/1024}')
DISC_MAIN=$(lsblk -dno NAME | head -n 1)
DISCARD=$(cat /sys/block/$DISC_MAIN/queue/discard_max_bytes 2>/dev/null || echo 0)
PROV=$([ "$DISCARD" -gt 0 ] && echo "Thin" || echo "Thick")
echo -e "Disco Total:    ${TOTAL_GB} GB - $PROV Provisioning"
echo -e "Load Average:   $(uptime | awk -F'load average:' '{print $2}')"
echo ""

# 2. IDENTIFICAÇÃO DE PEERS BGP (GO-BGP)
echo -e "${GREEN}[2] VIZINHOS DE ROTEAMENTO (BGP PEERS)${NC}"
declare -A PEER_NAMES
if command -v gobgp &> /dev/null; then
    while read -r p_ip p_as p_state; do
        # Busca nome no /etc/hosts para o peer
        p_name=$(getent hosts "$p_ip" | awk '{print $2}')
        [ -z "$p_name" ] && p_name="Peer-Desconhecido"
        PEER_NAMES["$p_ip"]=$p_name # Armazena para usar no passo 3
        echo -e "  - Peer: ${YELLOW}$p_ip${NC} (${p_name}) | AS: $p_as | Status: $p_state"
    done < <(gobgp neighbor 2>/dev/null | grep -vE "Peer|ID" | awk '{print $1, $2, $5}')
else
    echo -e "${RED}  - GoBGP não detectado ou sem permissão.${NC}"
fi
echo ""

# 3. FLUXO DE REDE (COM IDENTIFICAÇÃO DE PEER)
echo -e "${GREEN}[3] FLUXO DE CONEXÕES ATIVAS${NC}"

echo -e "${BLUE}<- QUEM CONECTA NELE (INBOUND):${NC}"
ss -tunp state established | grep -vE "Netid|127.0.0.1" | while read -r line; do
    L_PORT=$(echo "$line" | awk '{print $5}' | awk -F: '{print $NF}')
    R_IP=$(echo "$line" | awk '{print $6}' | awk -F: '{print $(NF-1)}' | sed 's/\[//;s/\]//')
    
    if [[ "$L_PORT" =~ ^[0-9]+$ ]] && [ "$L_PORT" -lt 20000 ]; then
        # Verifica se o IP é um Peer BGP conhecido
        NOME="${PEER_NAMES[$R_IP]}"
        [ -z "$NOME" ] && NOME=$(getent hosts "$R_IP" | awk '{print $2}')
        [ -z "$NOME" ] && NOME="IP-Externo"
        
        echo -e "  - Origem: ${YELLOW}$R_IP${NC} ($NOME) -> Porta Local: ${GREEN}$L_PORT${NC}"
    fi
done | sort -u

echo -e "\n${BLUE}-> ONDE ELE SE CONECTA (OUTBOUND):${NC}"
ss -tunp state established | grep -vE "Netid|127.0.0.1" | while read -r line; do
    L_PORT=$(echo "$line" | awk '{print $5}' | awk -F: '{print $NF}')
    R_IP_PORT=$(echo "$line" | awk '{print $6}')
    R_IP=$(echo "$R_IP_PORT" | awk -F: '{print $(NF-1)}' | sed 's/\[//;s/\]//')
    R_PORT=$(echo "$R_IP_PORT" | awk -F: '{print $NF}')
    
    if [[ "$L_PORT" =~ ^[0-9]+$ ]] && [ "$L_PORT" -gt 20000 ]; then
        NOME="${PEER_NAMES[$R_IP]}"
        [ -z "$NOME" ] && NOME=$(getent hosts "$R_IP" | awk '{print $2}')
        [ -z "$NOME" ] && NOME="Servidor-Remoto"
        
        BGP_TAG=$([ "$R_PORT" == "179" ] && echo -e "${RED}[SESSÃO BGP]${NC}" || echo "")
        echo -e "  - Destino: ${YELLOW}$R_IP${NC} ($NOME) -> Porta Remota: ${GREEN}$R_PORT${NC} $BGP_TAG"
    fi
done | sort | uniq -c | sort -nr
echo ""

# 4. FUNÇÕES ATIVAS E ALERTAS
echo -e "${GREEN}[4] SERVIÇOS E ALERTAS DO SISTEMA${NC}"
[[ $(pgrep -f mariadbd) ]] && echo -e "  - Função: ${BLUE}Database MariaDB${NC}"
[[ $(pgrep -f gobgpd) ]] && echo -e "  - Função: ${BLUE}Router BGP (GoBGP)${NC}"
[[ $(pgrep -f gunicorn) ]] && echo -e "  - Função: ${BLUE}App Python (Gunicorn)${NC}"

if [ -s /var/mail/root ]; then
    LAST_MAIL=$(grep "Subject:" /var/mail/root | tail -n 1)
    echo -e "${RED}  - Alerta Mail:${NC} ${YELLOW}${LAST_MAIL}${NC}"
fi

echo -e "${BLUE}====================================================${NC}"
