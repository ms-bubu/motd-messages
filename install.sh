#!/bin/bash

# Цвета для вывода в консоль при установке
G='\033[0;32m'
NC='\033[0m'

echo -e "${G}Начинаю установку кастомного MOTD...${NC}"

# 1. Отключаем все стандартные скрипты MOTD
echo "Отключаю стандартные скрипты Ubuntu..."
sudo chmod -x /etc/update-motd.d/* 2>/dev/null

# 2. Создаем наш новый скрипт
echo "Создаю новый скрипт приветствия..."
cat << 'EOF' | sudo tee /etc/update-motd.d/01-custom-info > /dev/null
#!/bin/bash

# Цвета
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- 1. ОСНОВНАЯ ИНФОРМАЦИЯ ---
OS_NAME=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2)
echo -e "${CYAN}--- СИСТЕМНЫЙ СТАТУС ---${NC}"
echo -e "ОС:           ${GREEN}${OS_NAME}${NC}"
echo -e "Пользователь: ${GREEN}$(whoami)${NC} | Хост: ${GREEN}$(hostname)${NC}"

# Аптайм
UPTIME_RAW=$(uptime -p)
UPTIME_TEXT=$(echo "$UPTIME_RAW" | sed 's/up/работает/g' | sed 's/minutes/минут/g' | sed 's/minute/минуту/g' | sed 's/hours/часов/g' | sed 's/hour/час/g' | sed 's/days/дней/g' | sed 's/day/день/g' | sed 's/weeks/недель/g' | sed 's/week/неделю/g')
echo -e "Аптайм:       ${GREEN}${UPTIME_TEXT}${NC}"

# Процессор
CPU_CORES=$(nproc)
CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
echo -e "Процессор:    ${GREEN}${CPU_CORES} ядр(а)${NC} | Нагрузка: ${YELLOW}${CPU_LOAD}%${NC}"

# Память
MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEM_FREE=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
MEM_USED=$(( (MEM_TOTAL - MEM_FREE) / 1024 ))
MEM_TOTAL_MB=$(( MEM_TOTAL / 1024 ))
echo -e "Память:       ${YELLOW}${MEM_USED}MB / ${MEM_TOTAL_MB}MB${NC}"

# Диск
DISK_INFO=$(df -h / | awk 'NR==2 {printf "%s/%s (%s)", $3, $2, $5}')
echo -e "Диск /:       ${RED}${DISK_INFO}${NC}"

echo -e "IP адрес:     ${CYAN}$(hostname -I | awk '{print $1}')${NC}"
echo -e "${CYAN}------------------------${NC}"

# --- 2. СЕРВИСЫ ---
SERVICES_FOUND=0

if command -v docker >/dev/null 2>&1; then
    CONTAINERS=$(docker ps --format "{{.Names}}#{{.Status}}" 2>/dev/null)
    if [ ! -z "$CONTAINERS" ]; then
        ((SERVICES_FOUND++))
        echo -e "🐳 ${CYAN}DOCKER:${NC}"
        echo "$CONTAINERS" | while IFS='#' read -r name status; do
            CLEAN_STATUS=$(echo "$status" | sed 's/Up //' | sed 's/about //')
            echo -e "  🟢 ${name} (${CLEAN_STATUS})"
        done
    fi
fi

if [ -f /etc/caddy/Caddyfile ]; then
    DOMAINS=$(grep -vE '^\s|^#|^\}|^\{|import|root|file_server|encode|admin' /etc/caddy/Caddyfile | grep "\." | awk '{print $1}' | sort -u)
    if [ ! -z "$DOMAINS" ]; then
        ((SERVICES_FOUND++))
        echo -e "🌐 ${CYAN}CADDY (Сайты):${NC}"
        for domain in $DOMAINS; do
            if curl -s -m 2 -o /dev/null "http://localhost" -H "Host: $domain" >/dev/null 2>&1; then
                echo -e "  🟢 ${domain}"
            else
                echo -e "  🔴 ${domain}"
            fi
        done
    fi
fi

if [ $SERVICES_FOUND -gt 0 ]; then
    echo -e "${CYAN}------------------------${NC}"
fi
EOF

# 3. Делаем новый скрипт исполняемым
sudo chmod +x /etc/update-motd.d/01-custom-info

# 4. Удаляем старый кеш сообщений (чтобы убрать ESM спам)
sudo rm -f /var/lib/update-notifier/motd-messages

echo -e "${G}Готово! Перезайдите в терминал или введите 'run-parts /etc/update-motd.d/' для проверки.${NC}"
