#!/bin/bash

task export > ~/tmp/task_backup.json && rclone copy ~/tmp/task_backup.json remote:taskwarrior-sync/tasks_mac.json
