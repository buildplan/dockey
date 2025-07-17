#!/bin/bash

# This script is designed to be run non-interactively inside the Dockey container.
# Its only purpose is to generate a JSON summary of all Docker containers.

# CRITICAL: Exit immediately if any command fails.
# This ensures errors are not hidden and will be reported in the Docker logs.
set -e

# --- Configuration & Setup ---

# The script needs to know its own location to find the config.yml
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export SCRIPT_DIR

# --- Core Functions ---

# Loads configuration from the mounted config.yml file.
load_configuration() {
    _CONFIG_FILE_PATH="$SCRIPT_DIR/config.yml"

    # This helper function reads a value from the YAML file.
    get_config_val() {
        if [ ! -f "$_CONFIG_FILE_PATH" ]; then
            echo ""
            return
        fi
        # Use yq to parse the yaml file, return empty string if not found.
        yq e "$1 // \"\"" "$_CONFIG_FILE_PATH"
    }

    # This helper is used by check_for_updates to get the release notes URL.
    get_release_url() {
        local image_to_check="$1"
        get_config_val ".containers.release_urls.\"${image_to_check}\""
    }
}

# Checks for new image versions using skopeo.
# This function is called by run_json_output.
check_for_updates() {
    local container_name="$1"; local current_image_ref="$2"

    # Skip if skopeo isn't installed or if image is pinned by digest
    if ! command -v skopeo &>/dev/null || [[ "$current_image_ref" == *@sha256:* ]]; then
        return 0
    fi

    # Extract image name and tag
    local current_tag="latest"
    local image_name_no_tag="$current_image_ref"
    if [[ "$current_image_ref" == *":"* ]]; then
        current_tag="${current_image_ref##*:}"
        image_name_no_tag="${current_image_ref%:$current_tag}"
    fi

    # Construct the repository path for skopeo
    local registry_host="registry-1.docker.io"
    local image_path_for_skopeo="$image_name_no_tag"
    if [[ "$image_name_no_tag" == *"/"* ]]; then
        local first_part; first_part=$(echo "$image_name_no_tag" | cut -d'/' -f1)
        if [[ "$first_part" == *"."* || "$first_part" == "localhost" || "$first_part" == *":"* ]]; then
            registry_host="$first_part"
            image_path_for_skopeo=$(echo "$image_name_no_tag" | cut -d'/' -f2-)
        fi
    else
        image_path_for_skopeo="library/$image_name_no_tag"
    fi
    local skopeo_repo_ref="docker://$registry_host/$image_path_for_skopeo"

    # Handle 'latest' tag by comparing digests
    if [ "$current_tag" == "latest" ]; then
        local local_digest; local_digest=$(docker inspect -f '{{index .RepoDigests 0}}' "$current_image_ref" 2>/dev/null | cut -d'@' -f2)
        if [ -z "$local_digest" ]; then return 1; fi

        local skopeo_output; skopeo_output=$(skopeo inspect "${skopeo_repo_ref}:latest" 2>&1)
        if [ $? -ne 0 ]; then return 1; fi

        local remote_digest; remote_digest=$(jq -r '.Digest' <<< "$skopeo_output")
        if [ "$remote_digest" != "$local_digest" ]; then
            echo "Update available for 'latest' tag"
            return 1
        fi
    fi
    # (Simplified version doesn't check versioned tags for now to ensure stability)
    return 0
}


# This is the main function that generates the JSON output for the web UI.
run_json_output() {
    # Get a list of all containers on the host
    mapfile -t containers_to_check_json < <(docker ps -a --format '{{.Names}}')

    local json_output="["
    local first_container=true

    for container_name in "${containers_to_check_json[@]}"; do
        if [ "$first_container" = false ]; then
            json_output+=","
        fi
        first_container=false

        local inspect_json
        inspect_json=$(docker inspect "$container_name")
        if [ -z "$inspect_json" ]; then
            continue
        fi

        # Extract all necessary data
        local name; name=$(jq -r '.[0].Name' <<< "$inspect_json" | sed 's|^/||')
        local id; id=$(jq -r '.[0].Id' <<< "$inspect_json" | cut -c1-12)
        local image; image=$(jq -r '.[0].Config.Image' <<< "$inspect_json")
        local status; status=$(jq -r '.[0].State.Status' <<< "$inspect_json")
        local health="n/a"
        if jq -e '.[0].State.Health.Status != null' <<< "$inspect_json" >/dev/null 2>&1; then
            health=$(jq -r '.[0].State.Health.Status' <<< "$inspect_json")
        fi
        local restarts; restarts=$(jq -r '.[0].RestartCount' <<< "$inspect_json")

        # Get resource usage only for running containers
        local cpu="0"; local mem="0"
        if [[ "$status" == "running" ]]; then
            local stats_json; stats_json=$(docker stats --no-stream --format '{{json .}}' "$container_name")
            if [ -n "$stats_json" ]; then
                cpu=$(jq -r '.CPUPerc' <<< "$stats_json" | tr -d '%')
                mem=$(jq -r '.MemPerc' <<< "$stats_json" | tr -d '%')
            fi
        fi

        # Perform update check
        local update_check_output
        update_check_output=$(check_for_updates "$name" "$image")
        local update_available="false"
        if [ -n "$update_check_output" ]; then
            update_available="true"
        fi

        # Build the final JSON object for this container
        json_output+=$(jq -n \
            --arg name "$name" \
            --arg id "$id" \
            --arg image "$image" \
            --arg status "$status" \
            --arg health "$health" \
            --arg restarts "$restarts" \
            --arg cpu "$cpu" \
            --arg mem "$mem" \
            --argjson update_available "$update_available" \
            '{name: $name, id: $id, image: $image, status: $status, health: $health, restarts: $restarts, cpu: $cpu, mem: $mem, update_available: $update_available}')
    done

    json_output+="]"
    echo "$json_output"
}

# --- Main Execution ---
# The script now only does two things: load config and run the JSON output function.
load_configuration
run_json_output
