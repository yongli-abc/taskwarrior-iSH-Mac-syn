#!/bin/sh
# Forces a git pull immediately.

LAST_PULL_FILE="$HOME/.task/last_pull_time"

echo "\n"
echo "----- Trickle-pull triggered at $(date) -----"
echo "\n"

cd ~/taskwarrior-sync-data || { echo "Failed to cd to repo directory"; exit 1; }

# Force git pull
if git pull --no-rebase; then
    echo $(date +%s) > "$LAST_PULL_FILE"  # Update last pull timestamp
    echo "Trickle-pull completed."
else
    echo "Failed to pull changes. Please check for conflicts."
    exit 1
fi

# Import tasks.json into Taskwarrior
task rc.hooks=off rc.json.array=on import tasks.json

echo "Trickle pull completed successfully."
exit 0
