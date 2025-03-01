#!/bin/bash
# taskwarrior_sync_mac.sh – Sync Taskwarrior tasks between Mac and iSH
# Requirements: Taskwarrior 3.x, rclone configured (same remote), jq installed.

RCLONE_REMOTE="remote:taskwarrior-sync"    # Remote path on Google Drive (same folder as iSH)
LOCAL_EXPORT="/tmp/tasks_mac_local.json"   # Local export of Mac tasks
REMOTE_EXPORT="/tmp/tasks_ish_remote.json" # File to store tasks pulled from iSH
MERGED="/tmp/tasks_merged.json"

# 1. Export local (Mac) tasks to JSON
task rc.json.array=on export > "$LOCAL_EXPORT" 2>/dev/null

# 2. Fetch latest tasks JSON from iOS (if available)
rclone copy "$RCLONE_REMOTE/tasks_ish.json" "$REMOTE_EXPORT" -q

# 3. Merge local and remote tasks JSON (prefer newer modified timestamps)
if [ -s "$REMOTE_EXPORT" ]; then
    jq -s '.[0] + .[1] | group_by(.uuid) | map(max_by(.modified))' \
       "$LOCAL_EXPORT" "$REMOTE_EXPORT" > "$MERGED"
else
    cp "$LOCAL_EXPORT" "$MERGED"
fi

# 4. Import merged tasks into local Taskwarrior
if [ -s "$MERGED" ]; then
    task import "$MERGED" 2>/dev/null
fi

# 5. Export again and upload the updated tasks file to Drive
task rc.json.array=on export > "$LOCAL_EXPORT" 2>/dev/null
rclone copy "$LOCAL_EXPORT" "$RCLONE_REMOTE/tasks_mac.json" -q

# (Optional) cleanup temp files
# rm -f "$LOCAL_EXPORT" "$REMOTE_EXPORT" "$MERGED"
