#!/bin/bash
snapper -c root create --type single --description "Weekly Automated Backup" --cleanup-algorithm number
