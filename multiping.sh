#!/bin/bash

sort_addresses() {
    sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n
}

process_mask() {
    start_ip=$(ipcalc -n "$1" | awk '/HostMin:/ {print $2}')
    end_ip=$(ipcalc -n "$1" | awk '/HostMax:/ {print $2}')
    start=$(echo "$start_ip" | awk -F. '{print $NF}')
    end=$(echo "$end_ip" | awk -F. '{print $NF}')
    common=$(echo "$start_ip" | sed "s/$start\$//")

    for ((i = start; i <= end; i++)); do
        echo "$common$i"
    done
}

process_range() {
    start_ip=$(echo "$1" | cut -d'-' -f1)
    end_ip=$(echo "$1" | cut -d'-' -f2)
    start=$(echo "$start_ip" | awk -F. '{print $NF}')
    end=$(echo "$end_ip" | awk -F. '{print $NF}')
    common=$(echo "$start_ip" | sed "s/$start\$//")

    for ((i = start; i <= end; i++)); do
        echo "$common$i"
    done
}

process_commas() {
    prefix=$(echo "$1" | awk -F',' '{print $1}')
    nums=$(echo "$1" | awk -F',' '{for (i=2; i<=NF; i++) print $i}')
    
    for num in $nums; do
        full_ip=$(echo "$prefix" | awk -F. '{print $1"."$2"."$3}')
        echo "$prefix"
        echo "$full_ip.$num"
    done
}

process_argument() {
    if [[ $1 == *"/"* ]]; then
        process_mask "$1"
    elif [[ $1 == *-* ]]; then
        process_range "$1"
    elif [[ $1 == *","* ]]; then
        process_commas "$1"
    else
        echo "$1"
    fi
}

check_ip() {
    fping -c 1 -t 100 "$1" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "$1 is UP"
    else
        echo "$1 is DOWN"
    fi
}

print_usage() {
    echo "Данный скрипт предназначен для массовой проверки доступности."
    echo "Вызовите его с передачей в качестве аргументов набора IP-адресов в следующем формате:"
    echo "bash multiping.sh 10.0.0.5/28 10.1.2.3-7 10.8.8.9,15,82"
    echo ""
    echo "Для корректной работы скрипта требуется установка утилит ipcalc и fping."
}

addresses=()
for arg in "$@"; do
    addresses+=($(process_argument "$arg"))
done

if [ ${#addresses[@]} -eq 0 ]; then
    print_usage
    exit 1
fi

for address in "${addresses[@]}"; do
    echo "$address"
done | sort_addresses | while read -r address; do
    check_ip "$address"
done
