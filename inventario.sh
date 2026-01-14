#!/bin/bash

# --- CONFIGURAÇÃO DE CORES PARA MELHOR LEITURA ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}          RELATÓRIO DE INVENTÁRIO COMPLETO         ${NC}"
echo -e "${BLUE}          GERADO EM: $(date '+%d/%m/%Y %H:%M:%S')  ${NC}"
echo -e "${BLUE}====================================================${NC}"

# 1. CARACTERÍSTICAS E HARDWARE
echo -e "${GREEN}[1] ESPECIFICAÇÕES DE HARDWARE${NC}"
echo -e "Sistema Operacional:  $(hostnamectl | grep "Operating System" | cut -d: -f2- | xargs)"
echo -e "Provisionamento CPU:  $(nproc) Núcleos (vCPUs)"
echo -e "Memória RAM Total:    $(free -h | grep Mem | awk '{print $2}')"

# Soma de HD (Ignora sr0/CD-ROM e foca em discos reais)
TOTAL_GB=$(lsblk -dnbo SIZE,TYPE | grep disk | awk '{s+=$1} END {printf "%.0f", s/1024/1024/1024}')
DISC_MAIN=$(lsblk -dno NAME | head -n 1)
DISCARD=$(cat /sys/block/$DISC_MAIN/queue/discard_max_bytes 2>/dev/null || echo 0)
PROV=$([ "$DISCARD" -gt 0 ] && echo "Thin" || echo "Thick")

echo -e "Armazenamento (HD):   ${TOTAL_GB} GB - $PROV Provisioning"
echo ""

# 2. ENDEREÇOS DE REDE (IDENTIDADE)
echo -e "${GREEN}[2] ENDEREÇOS DE REDE (INTERFACES ATIVAS)${NC}"
echo "IPv4:"
ip -4 addr show | grep inet | grep -v "127.0.0.1" | awk '{print "  - " $2 " ("$NF")"}'
echo "IPv6 Global:"
ip -6 addr show scope global | grep inet6 | awk '{print "  - " $2}'
echo ""

# 3. FLUXO DE CONEXÕES (QUEM CONECTA VS ONDE CONECTAMOS)
echo -e "${GREEN}[3] FLUXO DE COMUNICAÇÃO DE REDE${NC}"

echo -e "${BLUE}<- QUEM CONECTA NESTE SERVIDOR (ENTRADA):${NC}"
ss -tunp state established | grep -v "127.0.0.1" | while read line; do
    L_PORT=$(echo $line | awk '{print $5}' | rev | cut -d: -f1 | rev)
    R_IP=$(echo $line | awk '{print $6}' | cut -d] -f1 | sed 's/\[//' | cut -d: -f1)
    if [ "$L_PORT" -lt 10000 ]; then
        R_HOST=$(getent hosts $R_IP | awk '{print $2}')
        echo -e "  - Origem: ${YELLOW}$R_IP${NC} (${R_HOST:-Externo}) -> Porta Local: ${GREEN}$L_PORT${NC}"
    fi
done | sort | uniq

echo -e "\n${BLUE}-> ONDE ESTE SERVIDOR SE CONECTA (SAÍDA):${NC}"
ss -tunp state established | grep -v "127.0.0.1" | while read line; do
    L_PORT=$(echo $line | awk '{print $5}' | rev | cut -d: -f1 | rev)
    R_IP_PORT=$(echo $line | awk '{print $6}')
    R_IP=$(echo $R_IP_PORT | cut -d] -f1 | sed 's/\[//' | cut -d: -f1)
    R_PORT=$(echo $R_IP_PORT | rev | cut -d: -f1 | rev)
    if [ "$L_PORT" -gt 10000 ]; then
        R_HOST=$(getent hosts $R_IP | awk '{print $2}')
        echo -e "  - Destino: ${YELLOW}$R_IP${NC} (${R_HOST:-Servidor Externo}) -> Na Porta: ${GREEN}$R_PORT${NC}"
    fi
done | sort | uniq -c | sort -nr
echo ""

# 4. FUNÇÃO E SAÚDE DO SISTEMA
echo -e "${GREEN}[4] FUNÇÃO DA MÁQUINA E ALERTAS${NC}"

# Identificação de Função
if pgrep -f gunicorn > /dev/null; then
    echo -e "Função Detectada: ${BLUE}Servidor de Aplicação Python (Gunicorn)${NC}"
fi

if systemctl is-active --quiet docker; then
    echo -e "Função Detectada: ${BLUE}Docker Host${NC}"
    echo "Containers Ativos:"
    docker ps --format "  > {{.Names}} (Imagem: {{.Image}})"
fi

# Alerta de E-mail do Root
if [ -s /var/mail/root ]; then
    LAST_MAIL=$(grep "Subject:" /var/mail/root | tail -n 1)
    echo -e "${RED}AVISO:${NC} Mensagens de sistema pendentes: ${YELLOW}${LAST_MAIL:-Sem Assunto}${NC}"
fi

# Load Average
LOAD=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1)
echo -e "Carga do Sistema (Load): $LOAD"

echo -e "${BLUE}====================================================${NC}"
