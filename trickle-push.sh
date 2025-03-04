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
LOGFILE="$HOME/taskwarrior-sync-data/trickle-${SUFFIX}.log"
MAX_LOG_SIZE=1048576  # 1 MB

# Rotate log if it exceeds max size.
if [ -f "$LOGFILE" ]; then
    filesize=$(wc -c < "$LOGFILE")
    if [ "$filesize" -ge "$MAX_LOG_SIZE" ]; then
        mv "$LOGFILE" "${LOGFILE}.$(date +%Y%m%d%H%M%S)"
    fi
fi

# Determine invocation type.
if [ "$CRON" = "1" ]; then
    INVOCATION="cron"
else
    INVOCATION="manual"
fi

# Redirect all output (stdout and stderr) to the log file.
exec >> "$LOGFILE" 2>&1
echo "\n"
echo "----- Trickle-push by ${INVOCATION} triggered at $(date) -----"
echo "\n"

cd ~/taskwarrior-sync-data || { echo "Failed to cd to repo directory"; exit 1; }

# Export tasks to JSON (disable hooks to prevent recursion)
# Remove the 'urgency' field to prevent spurious changes.
# 'urgency' field can be re-computed during import.
task rc.hooks=off rc.json.array=on export | jq 'sort_by(.entry) | reverse | map(del(.urgency))' > tasks.json

# Check if tasks.json has any changes compared to HEAD.
if git diff --quiet tasks.json; then
    echo "No change in tasks.json; skipping commit and push."
    exit 0
fi

# Stage tasks.json and any log files matching trickle-*
git add tasks.json "$HOME/taskwarrior-sync-data/trickle-${SUFFIX}.log"*

# Create a commit message that includes the invocation type.
commit_msg="Trickle push (${INVOCATION}): tasks update on $(date '+%Y-%m-%d %H:%M:%S')"
if ! git commit -m "$commit_msg"; then
    echo "Failed to commit changes."
    exit 1
fi

# Force push to remote.
if git push origin main; then
    LAST_PUSH_FILE="$HOME/.task/last_push_time"
    echo $(date +%s) > "$LAST_PUSH_FILE"  # Update last push timestamp
    echo "Trickle-push completed successfully."
else
    echo "Failed to push changes. Please check for conflicts."
    exit 1
fi

exit 0
