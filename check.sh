#!/bin/bash

DOMAIN="example.com"
OUTPUT="valid_ips.txt"

> $OUTPUT

while read ip; do
    echo "Testing $ip..."

    response=$(curl -s --resolve "$DOMAIN:443:$ip" "https://$DOMAIN" --max-time 5)

    if echo "$response" | grep -q "Example Domain"; then
        echo "OK: $ip"
        echo "$ip" >> $OUTPUT
    else
        echo "FAIL: $ip"
    fi

done < ip.txt
