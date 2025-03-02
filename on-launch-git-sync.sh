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

# Pull latest changes (without quiet mode to display conflicts)
if ! git pull --no-rebase; then
    echo "Error during git pull. Please resolve any merge conflicts."
    exit 1
fi

# Import tasks.json into Taskwarrior. Disable hooks to prevent recursion.
task rc.hooks=off rc.json.array=on import tasks.json
exit 0
