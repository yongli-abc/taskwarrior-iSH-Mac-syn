#!/bin/sh
# Read JSON input from Taskwarrior on exit (added/modified tasks)
CHANGES=$(cat)
if [ -z "$CHANGES" ]; then
  # No task changes detected – exit without syncing.
  exit 0
fi

# Determine the OS type.
OS=$(uname)
if [ "$OS" = "Darwin" ]; then
    SUFFIX="mac"
elif [ "$OS" = "Linux" ]; then
    SUFFIX="iSH"
else
    SUFFIX="unknown"
fi

# Define the log file (or trickle log) with OS suffix.
LOGFILE="$HOME/taskwarrior-sync-data/taskhook-${SUFFIX}.log"
MAX_LOG_SIZE=1048576  # 1 MB

# Rotate log if it exceeds max size.
if [ -f "$LOGFILE" ]; then
    filesize=$(wc -c < "$LOGFILE")
    if [ "$filesize" -ge "$MAX_LOG_SIZE" ]; then
        mv "$LOGFILE" "${LOGFILE}.$(date +%Y%m%d%H%M%S)"
    fi
fi

# Redirect all output (stdout and stderr) to the log file.
exec >> "$LOGFILE" 2>&1
echo "\n"
echo "----- on-exit-git-sync triggered at $(date) -----"
echo "\n"

# Check last push timestamp.
THRESHOLD_SECONDS=660   # 11 minutes
LAST_PUSH_FILE="$HOME/.task/last_push_time"
[ ! -f "$LAST_PUSH_FILE" ] && echo 0 > "$LAST_PUSH_FILE"
LAST_PUSH=$(cat "$LAST_PUSH_FILE")
NOW=$(date +%s)

if [ $((NOW - LAST_PUSH)) -lt $THRESHOLD_SECONDS ]; then
    echo "Skipping sync: Last push was less than ${THRESHOLD_SECONDS} seconds ago."
    exit 0
fi

cd ~/taskwarrior-sync-data || { echo "Failed to cd to repo directory"; exit 1; }

# Pull latest changes from remote.
if ! git pull --no-rebase; then
    echo "Merge conflict or error during git pull."
    exit 1
fi

# Export tasks to JSON (disable hooks to prevent recursion).
task rc.hooks=off rc.json.array=on export > tasks.json

# Stage all changes (e.g. tasks.json, log files, etc.).
git add -A

# Commit changes if there are any.
if ! git diff-index --quiet HEAD --; then
    commit_msg="Auto-sync: tasks update on $(date '+%Y-%m-%d %H:%M:%S')"
    if ! git commit -m "$commit_msg"; then
        echo "Failed to commit changes."
        exit 1
    fi
fi

# Push changes only if commit succeeded.
if git push origin main; then
    echo $(date +%s) > "$LAST_PUSH_FILE"  # Update last push timestamp.
else
    echo "Failed to push changes. Please check your network or resolve conflicts."
    exit 1
fi

exit 0
