#!/bin/bash

# ==============================================================================
# Dockge Stack Update Checker
# ==============================================================================
# A companion script for Dockge (https://github.com/louislam/dockge).
#
# It iterates through your Dockge stacks directory, pulls new images silently,
# checks if the running containers are outdated, and sends a notification.
#
# It does NOT restart containers. It lets you decide when to click "Update"
# in the Dockge UI.
# ==============================================================================

# --- Configuration ---
# Default Dockge stacks location is /opt/stacks. Change if yours differs.
STACKS_DIR="${STACKS_DIR:-/opt/stacks}"

# Path to the environment file containing the 'send_notif' function.
NOTIF_FILE="${NOTIF_FILE:-/opt/stacks/notification.env}"

# --- Colors for Output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- 1. Load Notification Function ---
if [ -f "$NOTIF_FILE" ]; then
    source "$NOTIF_FILE"
else
    # Define a dummy function to prevent errors if file is missing
    send_notif() { :; }
    # Only warn if the file is explicitly missing (optional)
    # echo -e "${YELLOW}Notice: Notification file $NOTIF_FILE not found.${NC}"
fi

# Initialize array to track updates
declare -a updates_list=()

echo -e "${BLUE}=== Checking for Docker Updates (Dockge) ===${NC}"

# Check if STACKS_DIR exists
if [ ! -d "$STACKS_DIR" ]; then
    echo -e "${RED}Error: Directory $STACKS_DIR does not exist.${NC}"
    echo -e "Please check your Dockge stacks path."
    exit 1
fi

# --- Main Loop ---
while read -r stack_path; do
    stack_name=$(basename "$stack_path")
    
    # Dockge prefers compose.yaml, but supports docker-compose.yml
    if [[ -f "$stack_path/compose.yaml" ]]; then
        compose_file="compose.yaml"
    elif [[ -f "$stack_path/docker-compose.yml" ]]; then
        compose_file="docker-compose.yml"
    else
        continue
    fi

    cd "$stack_path" || continue

    echo -n -e "Analyzing [${YELLOW}$stack_name${NC}]... "

    # Silent Pull (Downloads new layers without restarting)
    docker compose pull -q 2>/dev/null
    
    services=$(docker compose ps --services 2>/dev/null)

    if [ -z "$services" ]; then
        echo -e "${RED}Inactive (Skipped)${NC}"
        cd "$STACKS_DIR" || exit
        continue
    fi

    local_has_update=false
    
    for service in $services; do
        container_id=$(docker compose ps -q "$service")
        if [ -z "$container_id" ]; then continue; fi

        image_name=$(docker inspect --format '{{.Config.Image}}' "$container_id")
        running_image_id=$(docker inspect --format '{{.Image}}' "$container_id")
        local_image_id=$(docker image inspect --format '{{.Id}}' "$image_name" 2>/dev/null)

        if [ -z "$local_image_id" ]; then continue; fi

        # Compare Running Hash vs Local Disk Hash (freshly pulled)
        if [ "$running_image_id" != "$local_image_id" ]; then
            if [ "$local_has_update" = false ]; then
                echo -e "${RED}Update found!${NC}"
                local_has_update=true
            fi
            echo -e "  └─ ${CYAN}$service${NC}"
            updates_list+=("$stack_name|$service")
        fi
    done

    if [ "$local_has_update" = false ]; then
        echo -e "${GREEN}OK${NC}"
    fi
    
    cd "$STACKS_DIR" || exit

done < <(find "$STACKS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

# --- CLEANUP (PRUNE) ---

echo -e "\n${BLUE}=== Cleaning up Orphan Images ===${NC}"
# Prune dangling images created by the 'pull' process to save space.
prune_output=$(docker image prune -f)

if [ -z "$prune_output" ]; then
    echo -e "${GREEN}Nothing to clean.${NC}"
else
    echo -e "${YELLOW}Space reclaimed:${NC}"
    echo "$prune_output"
fi

# --- SUMMARY AND NOTIFICATION ---

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}          UPDATE SUMMARY                ${NC}"
echo -e "${BLUE}========================================${NC}"

if [ ${#updates_list[@]} -gt 0 ]; then
    # Terminal Output
    echo -e "The following Dockge stacks have updates ready:\n"
    printf "%-25s | %-25s\n" "STACK" "SERVICE"
    printf "%s\n" "--------------------------+--------------------------"
    
    for item in "${updates_list[@]}"; do
        IFS='|' read -r stack service <<< "$item"
        printf "${YELLOW}%-25s${NC} | ${CYAN}%-25s${NC}\n" "$stack" "$service"
    done
    
    # --- NOTIFICATION ---
    stacks_formatted=$(printf "%s\n" "${updates_list[@]}" | cut -d'|' -f1 | sort -u | sed 's/^/- /')
    msg="🐋 Dockge Updates Available:"$'\n'"$stacks_formatted"
    
    if declare -f send_notif > /dev/null; then
        echo -e "\n${BLUE}Sending notification...${NC}"
        send_notif "$msg"
    fi

    echo -e "\n${RED}-> To apply: Go to your Dockge Dashboard and update the stacks.${NC}"
else
    echo -e "${GREEN}No updates detected. All stacks are up to date!${NC}"
fi
