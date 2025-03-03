#!/bin/sh
# Trickle a git push immediately.

LAST_PUSH_FILE="$HOME/.task/last_push_time"

echo "\n"
echo "----- Trickle-push triggered at $(date) -----"
echo "\n"

cd ~/taskwarrior-sync-data || { echo "Failed to cd to repo directory"; exit 1; }

# Export tasks to JSON (disable hooks to prevent recursion)
task rc.hooks=off rc.json.array=on export > tasks.json

# Stage tasks.json and any log files (using a wildcard for logs)
git add tasks.json "$HOME/taskwarrior-sync-data/taskhook-"*

# If there are any changes, commit them.
if ! git diff-index --quiet HEAD --; then
    commit_msg="Trickle push: tasks update on $(date '+%Y-%m-%d %H:%M:%S')"
    if ! git commit -m "$commit_msg"; then
        echo "Failed to commit changes."
        exit 1
    fi
fi

# Push to remote.
if git push origin main; then
    echo $(date +%s) > "$LAST_PUSH_FILE"  # Update last push timestamp
    echo "Trickle-push completed."
else
    echo "Failed to push changes. Please check for conflicts."
    exit 1
fi

echo "Trickle push completed successfully."
exit 0
