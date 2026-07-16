#!/bin/sh

# === CONFIG ===
API_TOKEN="0baWX3EQlPHNBMe6iTBrZAiToXtFSFiDwDWykI5H"
DOMAINS="hktsw.hkgtv.cf tsw.hkgtv.cf"
# ==============

IP_CACHE="/tmp/current_ip.txt"
CURRENT_IP=$(curl -s --connect-timeout 5 http://ifconfig.me)

if [ -z "$CURRENT_IP" ]; then
    CURRENT_IP=$(curl -s --connect-timeout 5 https://api.ipify.org)
fi

if [ -z "$CURRENT_IP" ]; then
    exit 1
fi

if [ -f "$IP_CACHE" ] && [ "$CURRENT_IP" = "$(cat $IP_CACHE)" ]; then
    exit 0
fi

for DOMAIN in $DOMAINS; do
    ROOT_DOMAIN=$(echo "$DOMAIN" | awk -F. '{print $(NF-1)"."$NF}')
    ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ROOT_DOMAIN" -H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/json" | grep -o '"id":"[^"]*' | head -n 1 | cut -d'"' -f4)
    
    if [ -z "$ZONE_ID" ]; then
        continue
    fi

    RECORD_RES=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$DOMAIN&type=A" -H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/json")
    RECORD_ID=$(echo "$RECORD_RES" | grep -o '"id":"[^"]*' | head -n 1 | cut -d'"' -f4)

    if [ -z "$RECORD_ID" ]; then
        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" -H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/json" --data "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$CURRENT_IP\",\"ttl\":120,\"proxied\":false}" > /dev/null
    else
        curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" -H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/json" --data "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$CURRENT_IP\",\"ttl\":120,\"proxied\":false}" > /dev/null
    fi
done

# Active hkgtv.cf update
#curl -4 -s "http://ddns.hkgtv.cf/update?name=hktsw.hkgtv.cf&key=kyt595" > /dev/null 2>&1

echo "$CURRENT_IP" > "$IP_CACHE"
