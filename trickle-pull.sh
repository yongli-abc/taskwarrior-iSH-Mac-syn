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
LOGFILE="$HOME/taskwarrior-sync-data/${SUFFIX}.log"
MAX_LOG_SIZE=1048576  # 1 MB

# Rotate log if it exceeds max size.
ARCHIVE_DIR="$HOME/taskwarrior-sync-data/archive"
mkdir -p "$ARCHIVE_DIR"

if [ -f "$LOGFILE" ]; then
    filesize=$(wc -c < "$LOGFILE")
    if [ "$filesize" -ge "$MAX_LOG_SIZE" ]; then
        mv "$LOGFILE" "$ARCHIVE_DIR/$(basename "$LOGFILE").$(date +%Y%m%d%H%M%S)"
    fi
fi

# Determine invocation type.
if [ "$CRON" = "1" ]; then
    INVOCATION="cron"
else
    INVOCATION="manual"
fi

exec >> "$LOGFILE" 2>&1
echo "\n"
echo "----- Trickle-pull by ${INVOCATION} triggered at $(date) -----"
echo "\n"

cd ~/taskwarrior-sync-data || { echo "Failed to cd to repo directory"; exit 1; }

# Optionally update last pull timestamp here if needed
LAST_PULL_FILE="$HOME/.task/last_pull_time"

# Force git pull
if git pull --no-rebase; then
    echo $(date +%s) > "$LAST_PULL_FILE"  # Update timestamp on success
    echo "Git pull succeeded."
else
    echo "Failed to pull changes. Please check for conflicts."
    exit 1
fi

# Import tasks.json into Taskwarrior (disable hooks to prevent recursion)
task rc.hooks=off rc.json.array=on import tasks.json

echo "Trickle-pull completed successfully."
exit 0
