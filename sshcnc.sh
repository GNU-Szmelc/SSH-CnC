#!/bin/bash

# Simple SSH Manager / Command n Control Panel in Bash
# Entries in config.conf use `name:login:ip` eg `server:root:0.0.0.0`
# by D-Fens for Entropy Linux ~ [Szmelc.INC]

# === Configurables ===

# Paths:
CONFIG_FILE="config.conf"
SCRIPTS_FILE="scripts.conf"
SSH="/usr/bin/ssh"
LOG_DIR="Logs"

# Colors:
GREEN='\033[0;32m'
RED='\033[0;31m'
ORANGE='\033[0;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file '$CONFIG_FILE' not found."
    exit 1
fi

clear
# Figlet "logo"
echo -e ${CYAN}" ____ ____  _   _        ____        ____ \n/ ___/ ___|| | | |      / ___|_ __  / ___|\n\___ \___ \| |_| |_____| |   | '_ \| |    \n ___) |__) |  _  |_____| |___| | | | |___ \n|____/____/|_| |_|      \____|_| |_|\____|\n"
echo -e ${NC}"---------------------------------"

mkdir -p "$LOG_DIR"

function show_menu {
    echo "Main Menu:" && echo ""
    echo "1. Control"
    echo "2. Status"
    echo "3. Modules" && echo ""
    echo "q. Exit" && echo ""
    echo "Select option:"
    read -p "> " option
    case $option in
        1) control_connection ;;
        2) show_status ;;
        3) show_modules_menu ;;
        q) exit 0 ;;
        *) echo "Invalid option."
           show_menu ;;
    esac
}

function show_status {
    clear && echo "[STATUS]"
    echo -e "${PURPLE}Device Name - ${CYAN}User${NC}@${ORANGE}IP/Hostname - ${NC}Status${NC}" 
    echo "---------------------------------" && echo ""
    while IFS=':' read -r name user host; do
        if ping -c 1 -W 1 $host &> /dev/null; then
            status="${GREEN}Alive${NC}"
        else
            status="${RED}Dead${NC}"
        fi
        echo -e "${PURPLE}$name${NC} - ${CYAN}$user${NC}@${ORANGE}$host${NC} - $status"
    done < "$CONFIG_FILE"
    echo ""
    read -p "[Press any button to continue]"
    clear && show_menu
}

function control_connection {
    clear && echo "[CONTROL MACHINE]"
    echo "---------------------------------"
    echo "Available Servers:" && echo ""
    local i=1
    declare -A connections
    while IFS=':' read -r name user host; do
        echo -e "${i}. ${PURPLE}$name${NC} at ${CYAN}$user${NC}@${ORANGE}$host${NC}"
        connections[$i]="$user@$host"
        ((i++))
    done < "$CONFIG_FILE" && echo ""
    echo "Select a device (or '0' to cancel):"
    echo "---------------------------------"
    read -p "> " selection
    if [ "$selection" -eq 0 ]; then
        echo "Cancelled."
        show_menu
        return
    fi
    local connection=${connections[$selection]}
    if [ -z "$connection" ]; then
        echo "Invalid selection."
    else
        clear
        echo "Connecting to $connection..."
        $SSH -o ControlMaster=auto -o ControlPath=~/.ssh/ctrl-%r@%h:%p $connection
    fi
    show_menu
}

function show_modules_menu {
    clear
    echo "[MODULES]" 
    echo "---------------------------------" && echo ""
    echo "1. Transfer files"
    echo "2. Dump Info"
    echo "3. Run Script" && echo ""
    echo "q. Back" && echo ""
    echo "Select option:"
    read -p "> " module_option
    case $module_option in
        1) select_server
           while true; do
               display_transfer_menu
               read -p "> " transfer_choice
               case $transfer_choice in
                   1) transfer_s2c
                      show_menu ;;
                   2) transfer_c2s
                      show_menu ;;
                   q) clear && show_modules_menu ;;
                   *) echo "Invalid option. Please select again." ;;
               esac
           done ;;
        2) clear && echo "DUMP INFO" && echo "" && select_server
           dump_info
           read -p "[Press any button to continue]"
           clear && show_menu ;;
        3) clear && select_server
           run_script
           read -p "[Press any button to continue]"
           clear && show_menu ;;
        q) clear && show_menu ;;
        *) echo "Invalid option."
           clear && show_modules_menu ;;
    esac
}

function display_transfer_menu {
    clear
    echo "[TRANSFER FILES]"
    echo "---------------------------------" && echo ""
    echo "1. Server -> Client (Download)"
    echo "2. Client -> Server (Upload)" && echo ""
    echo "q. Back"
}

function select_server {
    echo "Available servers:"
    local i=1
    while IFS= read -r line; do
        echo -e "${i}. ${PURPLE}$(echo "$line" | cut -d':' -f1)${NC} at ${CYAN}$(echo "$line" | cut -d':' -f2)${NC}@${ORANGE}$(echo "$line" | cut -d':' -f3)${NC}"
        i=$((i+1))
    done < "$CONFIG_FILE"
    echo "Select server (number):"
    read -r server_number
    local selected_server=$(sed -n "${server_number}p" "$CONFIG_FILE")
    SERVER_NAME=$(echo "$selected_server" | cut -d':' -f1)
    LOGIN=$(echo "$selected_server" | cut -d':' -f2)
    IP=$(echo "$selected_server" | cut -d':' -f3)
}

function connect_server {
    ssh -o ControlMaster=auto -o ControlPath=~/.ssh/ctrl-%r@%h:%p "${LOGIN}@${IP}"
}

function transfer_s2c {
    echo "Enter the remote file path to download (default: current working directory):"
    read -r remote_file
    remote_file=${remote_file:-"."}
    echo "Enter the local path to save the file (default: current working directory):"
    read -r local_path
    local_path=${local_path:-"."}
    scp -o ControlPath=~/.ssh/ctrl-%r@%h:%p "${LOGIN}@${IP}:${remote_file}" "${local_path}"
}

function transfer_c2s {
    echo "Enter the local file path to upload (default: current working directory):"
    read -r local_file
    local_file=${local_file:-"."}
    echo "Enter the remote path to save the file (default: current working directory):"
    read -r remote_path
    remote_path=${remote_path:-"."}
    scp -o ControlPath=~/.ssh/ctrl-%r@%h:%p "${local_file}" "${LOGIN}@${IP}:${remote_path}"
}

function dump_info {
    clear
    info=$(ssh -o ControlPath=~/.ssh/ctrl-%r@%h:%p "${LOGIN}@${IP}" << EOF
        echo "User: $(whoami)"
        echo "Uptime: $(uptime)" 
        echo "Pwd: $(pwd)"
EOF
    )
    clear
    echo "$info"
    read -p "Save dumped info as local dump-${SERVER_NAME}-$(date +%F-%T).txt file? (y/N): " save_choice
    save_choice=${save_choice:-N}
    if [[ $save_choice =~ ^[Yy]$ ]]; then
        echo "$info" > "$LOG_DIR/dump-${SERVER_NAME}-$(date +%F-%T).txt"
        echo "Info saved."
    fi
}

function run_script {
    clear
    echo "Run Script:" && echo ""
    echo "1. Run from favourites"
    echo "2. Enter path manually"
    echo ""
    echo "Select option:"
    read -p "> " run_option
    case $run_option in
        1)
            if [ ! -f "$SCRIPTS_FILE" ]; then
                clear
                echo "No favourite scripts found." && echo ""
                run_script_from_path
                return
            fi
            clear
            echo "Favourite scripts:" && echo ""
            local i=1
            declare -A scripts
            while IFS=':' read -r script_name script_path; do
                echo -e "${i}. ${script_name}"
                scripts[$i]="$script_path"
                ((i++))
            done < "$SCRIPTS_FILE"
            echo ""
            echo "Select a script (number):"
            read -p "> " script_selection
            script_path=${scripts[$script_selection]}
            ;;
        2)
            run_script_from_path
            return
            ;;
        *)
            echo "Invalid option."
            return
            ;;
    esac

    if [ -z "$script_path" ]; then
        echo "No script selected."
        return
    fi

    if [ ! -f "$script_path" ]; then
        echo "Error: Script '$script_path' not found."
        return
    fi

    execute_script "$script_path"
}

function run_script_from_path {
    clear
    echo "Enter the local path for script to run on server:"
    read -r script_path

    if [ ! -f "$script_path" ]; then
        echo "Error: Script '$script_path' not found."
        return
    fi

    execute_script "$script_path"
}

function execute_script {
    local script_path=$1
    local script_name=$(basename "$script_path")
    scp -o ControlPath=~/.ssh/ctrl-%r@%h:%p "$script_path" "${LOGIN}@${IP}:/tmp/${script_name}"
    local output=$(ssh -o ControlPath=~/.ssh/ctrl-%r@%h:%p "${LOGIN}@${IP}" "bash /tmp/${script_name}")
    echo "$output" && echo ""
    read -p "Save terminal log as local output-${SERVER_NAME}-$(date +%F-%T).txt file? (y/N): " save_log
    save_log=${save_log:-N}
    if [[ $save_log =~ ^[Yy]$ ]]; then
        echo "$output" > "$LOG_DIR/output-${SERVER_NAME}-$(date +%F-%T).txt"
        echo "Log saved."
    fi
}

# Main execution loop
while true; do
    show_menu
done
