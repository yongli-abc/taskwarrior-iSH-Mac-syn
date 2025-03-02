#!/bin/sh
# Determine the OS type.
OS=$(uname)
if [ "$OS" = "Darwin" ]; then
    SUFFIX="mac"
elif [ "$OS" = "Linux" ]; then
    SUFFIX="iSH"
else
    SUFFIX="unknown"
fi

# Define the log file with OS suffix.
LOGFILE="$HOME/taskwarrior-sync-data/taskhook-${SUFFIX}.log"
MAX_LOG_SIZE=1048576  # 1 MB
LAST_SYNC_FILE="$HOME/.task/last_pull_time"
THRESHOLD_SECONDS=300   # 5 minutes

# Rotate log if it exceeds max size.
if [ -f "$LOGFILE" ]; then
    filesize=$(wc -c < "$LOGFILE")
    if [ "$filesize" -ge "$MAX_LOG_SIZE" ]; then
        mv "$LOGFILE" "${LOGFILE}.$(date +%Y%m%d%H%M%S)"
    fi
fi
exec >> "$LOGFILE" 2>&1
echo "\n"
echo "----- on-launch-git-sync triggered at $(date) -----"
echo "\n"

cd ~/taskwarrior-sync-data || { echo "Failed to cd to repo directory"; exit 1; }

# Ensure the timestamp file exists (initialize it if missing)
[ ! -f "$LAST_SYNC_FILE" ] && echo 0 > "$LAST_SYNC_FILE"
LAST_SYNC=$(cat "$LAST_SYNC_FILE")
NOW=$(date +%s)

# Only pull if more than 5 minutes have passed since the last pull.
if [ $((NOW - LAST_SYNC)) -ge $THRESHOLD_SECONDS ]; then
    echo "Performing scheduled git pull..."
    if git pull --no-rebase; then
        echo $(date +%s) > "$LAST_SYNC_FILE"  # Update timestamp only on success

        # Import tasks.json into Taskwarrior. Disable hooks to prevent recursion.
        task rc.hooks=off rc.json.array=on import tasks.json
    else
        echo "Error during git pull. Please resolve any merge conflicts."
        exit 1
    fi
else
    echo "Skipping git pull: Last pull was less than 5 minutes ago."
fi

exit 0
