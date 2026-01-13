#!/usr/bin/env sh

KERNEL="paper"
MINECRAFT_VERSION="1.21.11"

AVAILABLE_KERNELS=("bukkit" "spigot" "paper" "folia")
AVAILABLE_CHANNELS=("STABLE" "BETA" "ALPHA")

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed" >&2
    exit 1
fi

is_valid_kernel() {
    local kernel="$1"
    for valid in "${AVAILABLE_KERNELS[@]}"; do
        if [[ "$kernel" == "$valid" ]]; then
            return 0
        fi
    done
    return 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --kernel)
            if [[ -n "$2" && "$2" != --* ]]; then
                if is_valid_kernel "$2"; then
                    KERNEL="$2"
                    shift 2
                else
                    echo "Error: Unknown kernel '$2'. Available: ${AVAILABLE_KERNELS[*]}" >&2
                    exit 1
                fi
            else
                echo "Error: --kernel requires a kernel argument" >&2
                exit 1
            fi
            ;;
        --version)
            if [[ -n "$2" && "$2" != --* ]]; then
                MINECRAFT_VERSION="$2"
                shift 2
                continue
            fi
            ;;
        -h|--help)
            echo "Usage: $0 [--version VERSION | --kernel KERNEL]"
            echo ""
            echo "Options:"
            echo "  --version VERSION    download specified version (default: $MINECRAFT_VERSION)"
			echo "  --kernel KERNEL      download specified kernel (available: ${AVAILABLE_KERNELS[*]})"
            echo "  -h, --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

SERVER_FOLDER="${KERNEL}_${MINECRAFT_VERSION}"

if [[ "$KERNEL" == "paper" || "$KERNEL" == "folia" ]]; then
    USER_AGENT="cool-project/1.0.0"
    # First check if the requested version has a stable build
    BUILDS_RESPONSE=$(curl -s -H "User-Agent: $USER_AGENT" https://fill.papermc.io/v3/projects/${KERNEL}/versions/${MINECRAFT_VERSION}/builds)

    # Check if the API returned an error
    if echo "$BUILDS_RESPONSE" | jq -e '.ok == false' > /dev/null 2>&1; then
		ERROR_MSG=$(echo "$BUILDS_RESPONSE" | jq -r '.message // "Unknown error"')
		echo "Error: $ERROR_MSG"
		exit 1
    fi

	for channel in "${AVAILABLE_CHANNELS[@]}"; do
		PAPERMC_URL=$(echo "$BUILDS_RESPONSE" | jq -r 'first(.[] | select(.channel == "'${channel}'") | .downloads."server:default".url) // "null"')
		if [ "$PAPERMC_URL" != "null" ]; then
			echo "Founded build from channel: $channel"
			break
		fi
	done

    if [ "$PAPERMC_URL" != "null" ]; then
		mkdir "$SERVER_FOLDER"
		curl -o "$SERVER_FOLDER/server.jar" $PAPERMC_URL
		echo "Download completed (version: $MINECRAFT_VERSION)"
    else
		echo "No builds available for this version"
		exit 1
    fi
fi
if [[ "$KERNEL" == "bukkit" || "$KERNEL" == "spigot" ]]; then
	if [[ "$KERNEL" == "bukkit" ]]; then
		KERNEL="craftbukkit"
	fi
	mkdir "$SERVER_FOLDER"
	if ! curl -o "$SERVER_FOLDER/server.jar" https://cdn.getbukkit.org/$KERNEL/$KERNEL-$MINECRAFT_VERSION.jar; then
        echo "Error: Failed to download minecraft $KERNEL version $MINECRAFT_VERSION from getbukkit.org" >&2
        exit 1
    fi
fi

# Setup EULA
echo "eula=true" > "$SERVER_FOLDER/eula.txt"
mkdir "$SERVER_FOLDER/plugins"
echo "java -jar server.jar --nogui" > "$SERVER_FOLDER/start.sh"
exit
