#!/bin/bash

#Script displays your system info
#More detailed info

#colors
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"
RESET="\033[0m"

#ascii
print_logo() {
    echo -e "${GREEN}"
    echo '                    c.'
    echo '                 ,xNMM.'
    echo '               .OMMMMo'
    echo '               OMMM0,'
    echo '     .;loddo:. loolloddol;.'
    echo '   cKMMMMMMMMMMNWMMMMMMMMMM0:'
    echo ' .KMMMMMMMMMMMMMMMMMMMMMMMWd.'
    echo ' XMMMMMMMMMMMMMMMMMMMMMMMX.'
    echo ';MMMMMMMMMMMMMMMMMMMMMMMM:'
    echo ':MMMMMMMMMMMMMMMMMMMMMMMM:'
    echo '.MMMMMMMMMMMMMMMMMMMMMMMMX.'
    echo ' kMMMMMMMMMMMMMMMMMMMMMMMMWd.'
    echo ' .XMMMMMMMMMMMMMMMMMMMMMMMMMMk'
    echo '  .XMMMMMMMMMMMMMMMMMMMMMMMMK.'
    echo '    kMMMMMMMMMMMMMMMMMMMMMMd'
    echo '     ;KMMMMMMMWXXWMMMMMMMk.'
    echo '       .cooc,.    .,coo:.'
    echo -e "${RESET}"
}

#System info
get_os_info() {
    echo -e "${BOLD}${BLUE}OS:${RESET} $(sw_vers -productName) $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
    echo -e "${BOLD}${BLUE}Kernel:${RESET} $(uname -sr)"
}

get_host_info() {
    local model=$(system_profiler SPHardwareDataType | grep "Model Name" | sed 's/.*: //')
    local serial=$(system_profiler SPHardwareDataType | grep "Serial Number" | sed 's/.*: //')
    echo -e "${BOLD}${MAGENTA}Host:${RESET} $model"
    echo -e "${BOLD}${MAGENTA}Serial:${RESET} $serial"
}

get_cpu_info() {
    local cpu_name=$(sysctl -n machdep.cpu.brand_string)
    local cpu_cores=$(sysctl -n hw.physicalcpu)
    local cpu_threads=$(sysctl -n hw.logicalcpu)
    local cpu_speed=$(sysctl -n hw.cpufrequency | awk '{print $0 / 1000000000 " GHz"}')
    
    echo -e "${BOLD}${RED}CPU:${RESET} $cpu_name"
    echo -e "${BOLD}${RED}CPU Cores:${RESET} $cpu_cores physical, $cpu_threads logical"
    
    #CPU temp
    if command -v "istats" &> /dev/null; then
        local cpu_temp=$(istats cpu temp --value-only 2>/dev/null)
        if [ ! -z "$cpu_temp" ]; then
            echo -e "${BOLD}${RED}CPU Temp:${RESET} ${cpu_temp}°C"
        fi
    fi
}

get_memory_info() {
    #memory info
    local total_mem=$(sysctl -n hw.memsize | awk '{print $0 / 1073741824 " GB"}')
    local mem_info=$(vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages free: (\d+)/ and print "Free Memory: " . $1 * $size / 1048576, " MB\n"')
    local used_mem=$(vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages (active|wired down|occupied by compressor): (\d+)/ and $used+=$2; END { printf "Used Memory: %.2f GB\n", $used * $size / 1073741824}')
    
    echo -e "${BOLD}${GREEN}Memory:${RESET} $total_mem Total"
    echo -e "${BOLD}${GREEN}$used_mem${RESET}"
}

get_disk_info() {
    local disk_info=$(df -h / | awk 'NR==2 {print "Total: " $2 ", Used: " $3 " (" $5 "), Free: " $4}')
    echo -e "${BOLD}${YELLOW}Disk:${RESET} $disk_info"
    
    #Mounted volumes
    echo -e "${BOLD}${YELLOW}Mounted Volumes:${RESET}"
    df -h | grep "/Volumes/" | awk '{print "  - " $9 ": " $2 " Total, " $3 " Used, " $4 " Free (" $5 ")"}'
}

get_gpu_info() {
    echo -e "${BOLD}${CYAN}GPU:${RESET} $(system_profiler SPDisplaysDataType | grep "Chipset Model" | sed 's/.*: //')"
    
    #VRAM info
    local vram=$(system_profiler SPDisplaysDataType | grep "VRAM" | head -n 1 | sed 's/.*: //')
    if [ ! -z "$vram" ]; then
        echo -e "${BOLD}${CYAN}VRAM:${RESET} $vram"
    fi
}

get_network_info() {
    echo -e "${BOLD}${MAGENTA}Network:${RESET}"
    
    #Network info
    if [ "$(networksetup -getairportpower en0 | awk '{print $4}')" == "On" ]; then
        local wifi_info=$(/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I)
        local wifi_ssid=$(echo "$wifi_info" | awk -F': ' '/ SSID/ {print $2}')
        local wifi_bssid=$(echo "$wifi_info" | awk -F': ' '/ BSSID/ {print $2}')
        local wifi_channel=$(echo "$wifi_info" | awk -F': ' '/ channel/ {print $2}')
        
        echo -e "  ${BOLD}Wi-Fi:${RESET} $wifi_ssid (Channel: $wifi_channel)"
    fi
    
    #Get IP addresses
    echo -e "  ${BOLD}IP (Local):${RESET} $(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n 1)"
    
    #Get public IP (if network is available)
    if ping -c 1 google.com &>/dev/null; then
        echo -e "  ${BOLD}IP (Public):${RESET} $(curl -s https://api.ipify.org)"
    fi
}

get_battery_info() {
    #Only run on laptops
    if system_profiler SPPowerDataType | grep -q "Battery Information"; then
        local batt_percent=$(pmset -g batt | grep -o '[0-9]*%' | tr -d '%')
        local batt_status=$(pmset -g batt | grep -o 'discharging|charging|AC attached' | head -n 1)
        local batt_cycles=$(system_profiler SPPowerDataType | grep "Cycle Count" | awk '{print $3}')
        
        echo -e "${BOLD}${GREEN}Battery:${RESET} ${batt_percent}% ($batt_status)"
        echo -e "${BOLD}${GREEN}Cycles:${RESET} $batt_cycles"
    fi
}

get_uptime_info() {
    echo -e "${BOLD}${BLUE}Uptime:${RESET} $(uptime | sed 's/.*up \([^,]*\), .*/\1/')"
}

get_user_info() {
    echo -e "${BOLD}${CYAN}User:${RESET} $(whoami) ($(id -F))"
    echo -e "${BOLD}${CYAN}Shell:${RESET} $(basename $SHELL)"
}

#Main function
main() {
    clear
    print_logo
    
    #Display
    echo
    get_os_info
    get_host_info
    get_cpu_info
    get_memory_info
    get_disk_info
    get_gpu_info
    get_network_info
    get_battery_info
    get_uptime_info
    get_user_info
    
    echo
    echo -e "${BOLD}${YELLOW}macinfo.sh - $(date)${RESET}"
    echo
}

#Execute main
main

