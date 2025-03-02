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
echo "----- on-exit-git-sync triggered at $(date) -----"
echo "\n"

cd ~/taskwarrior-sync-data || { echo "Failed to cd to repo directory"; exit 1; }

# Export tasks to JSON
task rc.hooks=off rc.json.array=on export > tasks.json

# Pull latest changes
git pull --no-rebase || { echo "Merge conflict or error during git pull"; exit 1; }

# Stage and commit changes if any
git add tasks.json "$LOGFILE"*

if ! git diff-index --quiet HEAD --; then
    commit_msg="Auto-sync: tasks update on $(date '+%Y-%m-%d %H:%M:%S')"
    git commit -m "$commit_msg" || { echo "Failed to commit changes"; exit 1; }
    git push origin main || { echo "Failed to push changes"; exit 1; }
fi

exit 0
