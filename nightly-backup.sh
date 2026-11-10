#!/usr/bin/env bash
# nightly-backup.sh: mirrors school-work/ into backup/ every evening, from cron.
#
#   ./nightly-backup.sh            back up now
#   ./nightly-backup.sh --dry-run  rehearse: log what would change, and change nothing
#
# cron runs it from your home folder, with a short PATH and no keyboard, so it
# has to work from anywhere and write everything into logs/backup.log.
#
# Each numbered comment below is a job for you. The messages are given exactly,
# because the check compares them word for word.

# 1. Give the script a PATH of its own, before anything else, so its commands
#    are found under cron: /usr/local/bin:/usr/bin:/bin. On a Mac, put
#    /opt/homebrew/bin at the front: it's where Homebrew puts flock and rsync.


# The folder this script is in, as a full path, wherever it's run from.
# Use it for every file and folder below: "$here/school-work/", "$here/backup/",
# "$here/logs/backup.log" and "$here/logs/backup.lock".
here="$(cd "$(dirname "$0")" && pwd)"

# 2. Make the logs folder if it isn't there yet, then send everything the
#    script prints, errors included, to the end of logs/backup.log.


# 3. Write a function named log that prints the date and the time, a space,
#    then what it was given, as in:  2026-11-09 18:00:01 Backup started


# 4. One copy at a time: open logs/backup.lock as file 9 and take the lock with
#    flock -n. If another copy has it, log "Another backup is running. Skipping."
#    and stop with exit code 0.


# 5. Never mirror a missing or empty folder (--delete would empty the backup).
#    No school-work folder: log "No school-work folder. Nothing was backed up."
#    An empty one: log "school-work is empty. Nothing was backed up."
#    Either way, stop with exit code 1.


# 6. --dry-run: when the first argument is --dry-run, add -n to rsync's options,
#    and use "Dry run" instead of "Backup" in job 7's two messages.


# 7. Log "Backup started". Then mirror school-work/ into backup/ with
#    rsync -av --delete. When rsync works, log "Backup finished"; when it
#    fails, log "Backup failed" and stop with exit code 1.

