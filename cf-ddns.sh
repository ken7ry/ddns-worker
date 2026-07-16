#!/bin/sh

# ==================== 极简多域名配置区 ====================
API_TOKEN="0H"
# 域名用空格隔开，不要加括号
DOMAINS="h.f tv.cf"
# ========================================================

IP_CACHE_FILE="/tmp/current_ip.txt"

# 1. 获取公网 IP (针对当前网络环境，使用最稳的全球纯净 IP 接口)
CURRENT_IP=$(curl -s --connect-timeout 5 http://ifconfig.me)

if [ -z "$CURRENT_IP" ]; then
    # 备用通道：ipify 纯净 API
    CURRENT_IP=$(curl -s --connect-timeout 5 https://api.ipify.org)
fi

if [ -z "$CURRENT_IP" ]; then
    echo "$(date): 错误 - 获取公网 IP 失败"
    exit 1
fi

# 2. 对比本地内存缓存，IP 没变直接零消耗退出
if [ -f "$IP_CACHE_FILE" ] && [ "$CURRENT_IP" = "$(cat $IP_CACHE_FILE)" ]; then
    exit 0
fi

# 3. 循环更新每个域名
for DOMAIN in $DOMAINS; do
    ROOT_DOMAIN=$(echo "$DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')

    ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ROOT_DOMAIN" \
         -H "Authorization: Bearer $API_TOKEN" \
         -H "Content-Type: application/json" | grep -o '"id":"[^"]*' | head -n 1 | cut -d'"' -f4)

    if [ -z "$ZONE_ID" ]; then
        echo "$(date): [$DOMAIN] 获取 ZONE_ID 失败"
        continue
    fi

    RECORD_RES=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$DOMAIN&type=A" \
         -H "Authorization: Bearer $API_TOKEN" \
         -H "Content-Type: application/json")

    RECORD_ID=$(echo "$RECORD_RES" | grep -o '"id":"[^"]*' | head -n 1 | cut -d'"' -f4)

    if [ -z "$RECORD_ID" ]; then
        RESULT=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
             -H "Authorization: Bearer $API_TOKEN" \
             -H "Content-Type: application/json" \
             --data "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$CURRENT_IP\",\"ttl\":120,\"proxied\":false}")
    else
        RESULT=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
             -H "Authorization: Bearer $API_TOKEN" \
             -H "Content-Type: application/json" \
             --data "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$CURRENT_IP\",\"ttl\":120,\"proxied\":false}")
    fi

    if echo "$RESULT" | grep -q '"success":true'; then
        echo "$(date): [$DOMAIN] 成功同步新 IP: $CURRENT_IP"
    else
        echo "$(date): [$DOMAIN] 更新失败"
    fi
done

# 更新完毕，记录新 IP 到缓存
echo "$CURRENT_IP" > "$IP_CACHE_FILE"
