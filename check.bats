#!/usr/bin/env bats
# Checks your nightly-backup.sh by running it for real, the way cron would:
# from the / folder, with cron's short PATH and no keyboard.
# Every test runs a copy of your script in a throwaway folder of its own, with
# made-up school work, so nothing in this exercise folder (or anywhere else) is
# changed. Run it from this folder with:  bats check.bats
# You don't need to change this file.

setup() {
  dir="$BATS_TEST_TMPDIR/exercise"
  mkdir -p "$dir/school-work/english" "$dir/school-work/history" "$dir/school-work/science"
  printf 'Why the Town Library Matters\nFirst draft\n' > "$dir/school-work/english/essay.txt"
  printf 'Hatchet\nThe Giver\n' > "$dir/school-work/english/reading-list.txt"
  printf 'Chapter 4: the river towns\n' > "$dir/school-work/history/notes.txt"
  printf 'Plant growth, day 1: 2 cm\n' > "$dir/school-work/science/lab-report.txt"
  if [[ -f "$BATS_TEST_DIRNAME/nightly-backup.sh" ]]; then
    cp "$BATS_TEST_DIRNAME/nightly-backup.sh" "$dir/nightly-backup.sh"
    chmod +x "$dir/nightly-backup.sh"
  fi
  script="$dir/nightly-backup.sh"
  log="$dir/logs/backup.log"
}

# Runs the copy of your script the way cron does: from /, with only HOME,
# LOGNAME, SHELL and cron's PATH, and nothing to read from the keyboard.
as_cron() {
  env -i HOME="$HOME" LOGNAME="${USER:-sam}" PATH=/usr/bin:/bin SHELL=/bin/sh \
    /bin/sh -c 'cd / && "$0" "$@"' "$script" "$@" < /dev/null
}

# The lines the last run added to the log: everything from its last
# "started" line to the end.
last_run() {
  [[ -f "$log" ]] || return 0
  awk '/ (Backup|Dry run) started$/ { run = "" } { run = run $0 "\n" } END { printf "%s", run }' "$log"
}

# Fails with a message when the first run made no backup, so the tests that
# change school-work afterwards have something to compare.
expect_first_backup() {
  if [[ ! -f "$dir/backup/english/essay.txt" ]]; then
    echo "The first run made no backup in backup/, so this job can't be checked yet. Finish job 7 first."
    return 1
  fi
}

@test "the script is here and bash can read it" {
  if [[ ! -f "$script" ]]; then
    echo "nightly-backup.sh is missing. Download the exercise again to get it back."
    return 1
  fi
  errors="$(bash -n "$script" 2>&1)" || {
    echo "bash found a mistake in nightly-backup.sh before running it:"
    echo "$errors" | head -n 1
    echo "Look at the line it names. Common causes: a missing fi, a missing } at the end of the log function, or no space inside [[ ]]."
    return 1
  }
}

@test "rsync and flock are installed" {
  for tool in rsync flock; do
    if ! PATH="/opt/homebrew/bin:/usr/local/bin:$PATH" command -v "$tool" > /dev/null; then
      echo "$tool isn't installed. On Ubuntu: sudo apt install $tool. On a Mac: brew install $tool."
      return 1
    fi
  done
}

@test "1) it finds its commands with a PATH of its own" {
  run env -i HOME="$HOME" PATH=/no-such-folder /bin/bash "$script" < /dev/null
  if [[ ! -f "$dir/backup/english/essay.txt" ]]; then
    echo "Run with a PATH that holds none of the usual folders, the script couldn't find its commands, so nothing was backed up."
    echo "Set PATH=/usr/local/bin:/usr/bin:/bin near the top, before the here= line: dirname, mkdir, date, flock and rsync are all found through it."
    [[ -n "$output" ]] && echo "It printed: $output"
    return 1
  fi
}

@test "2) everything goes into logs/backup.log, and nothing to the screen" {
  run as_cron
  if [[ ! -f "$log" ]]; then
    echo "There's no logs/backup.log after a run. Make the logs folder with mkdir -p \"\$here/logs\", then exec >> \"\$here/logs/backup.log\" 2>&1."
    [[ -n "$output" ]] && echo "It printed: $output"
    return 1
  fi
  if [[ -n "$output" ]]; then
    echo "Under cron, nobody sees the screen, so everything should go into the log. The script still printed: $output"
    echo "Put exec >> \"\$here/logs/backup.log\" 2>&1 above everything that prints."
    return 1
  fi
}

@test "3) each log line starts with the date and the time" {
  run as_cron
  line="$(grep -m 1 'Backup started' "$log" 2>/dev/null || true)"
  if [[ ! "$line" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}\ Backup\ started$ ]]; then
    echo "The log should have a line like: 2026-11-09 18:00:01 Backup started"
    echo "Its line was: ${line:-(no Backup started line at all)}"
    echo "A log function that runs echo \"\$(date '+%F %T') \$*\" prints exactly that."
    return 1
  fi
}

@test "4) a second copy finds the lock taken, and skips" {
  mkdir -p "$dir/logs"
  exec 8> "$dir/logs/backup.lock"
  if ! flock -n 8; then
    echo "The check couldn't take the lock itself. Is flock installed?"
    return 1
  fi
  run as_cron
  exec 8>&-
  if [[ "$status" -ne 0 ]]; then
    echo "Another copy running isn't a mistake, so the script should stop with exit 0 (it gave $status)."
    return 1
  fi
  if ! grep -q 'Another backup is running. Skipping.$' "$log" 2>/dev/null; then
    echo "While another copy holds logs/backup.lock, the log should say \"Another backup is running. Skipping.\""
    echo "Open the lock with exec 9> \"\$here/logs/backup.lock\" and take it with flock -n 9."
    return 1
  fi
  if [[ -e "$dir/backup" ]]; then
    echo "The script backed up anyway, while another copy held the lock. Stop with exit 0 when flock -n 9 fails."
    return 1
  fi
}

@test "5) a missing school-work folder: it says so and backs up nothing" {
  run as_cron
  expect_first_backup || return 1
  mv "$dir/school-work" "$dir/school-work-away"
  run as_cron
  if [[ "$status" -ne 1 ]]; then
    echo "With no school-work folder, the script should stop with exit 1 (it gave $status)."
    return 1
  fi
  if ! grep -q 'No school-work folder. Nothing was backed up.$' "$log" 2>/dev/null; then
    echo "The log should say \"No school-work folder. Nothing was backed up.\" Test with ! -d before rsync."
    return 1
  fi
  if [[ ! -f "$dir/backup/english/essay.txt" ]]; then
    echo "The last good backup was emptied. With no school-work folder, stop before rsync runs."
    return 1
  fi
}

@test "5) an empty school-work folder: it says so and keeps the backup" {
  run as_cron
  expect_first_backup || return 1
  rm -r "$dir/school-work"
  mkdir "$dir/school-work"
  run as_cron
  if [[ "$status" -ne 1 ]]; then
    echo "With an empty school-work folder, the script should stop with exit 1 (it gave $status)."
    return 1
  fi
  if ! grep -q 'school-work is empty. Nothing was backed up.$' "$log" 2>/dev/null; then
    echo "The log should say \"school-work is empty. Nothing was backed up.\" Test whether ls -A prints anything, with -z."
    return 1
  fi
  if [[ ! -f "$dir/backup/english/essay.txt" ]]; then
    echo "rsync --delete mirrored the empty folder and emptied the backup. Stop before rsync when school-work is empty."
    return 1
  fi
}

@test "6) --dry-run changes nothing" {
  run as_cron --dry-run
  if [[ -e "$dir/backup" ]]; then
    echo "After --dry-run, there should still be no backup folder. Add -n to rsync's options when \$1 is --dry-run."
    return 1
  fi
  if ! grep -q ' Dry run finished$' "$log" 2>/dev/null; then
    echo "The log should say \"Dry run started\" and \"Dry run finished\" for a rehearsal."
    return 1
  fi
}

@test "6) --dry-run lists what would be deleted" {
  run as_cron
  expect_first_backup || return 1
  rm "$dir/school-work/history/notes.txt"
  run as_cron --dry-run
  if [[ ! -f "$dir/backup/history/notes.txt" ]]; then
    echo "--dry-run deleted history/notes.txt from the backup. A rehearsal changes nothing: add -n."
    return 1
  fi
  if ! last_run | grep -q 'deleting history/notes.txt'; then
    echo "The rehearsal's lines in the log should list deleting history/notes.txt. Use rsync -av --delete, with -n added."
    return 1
  fi
}

@test "7) run the cron way, it mirrors school-work into backup" {
  run as_cron
  if [[ "$status" -ne 0 ]]; then
    echo "The script should finish with exit 0 (it gave $status). The log says:"
    cat "$log" 2>/dev/null | tail -n 5
    return 1
  fi
  if ! diff -r "$dir/school-work" "$dir/backup" > /dev/null 2>&1; then
    echo "backup/ should hold exactly what school-work/ holds, run from the / folder as cron does."
    echo "Use the full paths \"\$here/school-work/\" and \"\$here/backup/\", with the slash at the end of both."
    return 1
  fi
  if ! grep -q ' Backup finished$' "$log" 2>/dev/null; then
    echo "After a good backup, the log should say \"Backup finished\"."
    return 1
  fi
}

@test "7) a second run copies only what changed" {
  run as_cron
  expect_first_backup || return 1
  printf 'Second draft: added the library'"'"'s history\n' >> "$dir/school-work/english/essay.txt"
  run as_cron
  copied="$(last_run)"
  if [[ "$copied" != *english/essay.txt* ]]; then
    echo "The second run's lines in the log should list english/essay.txt, the file that changed. Use rsync -av, so it lists what it copies."
    return 1
  fi
  if [[ "$copied" == *history/notes.txt* ]]; then
    echo "The second run copied history/notes.txt again, though it hadn't changed. rsync -a copies only what changed."
    return 1
  fi
}

@test "7) a file deleted from school-work is deleted from the backup" {
  run as_cron
  expect_first_backup || return 1
  rm "$dir/school-work/english/reading-list.txt"
  run as_cron
  if [[ -e "$dir/backup/english/reading-list.txt" ]]; then
    echo "reading-list.txt is gone from school-work, so the mirror should delete it from backup too: rsync --delete."
    return 1
  fi
}

@test "7) a backup that fails says so" {
  # A file named backup, where the backup folder should be, makes rsync fail.
  printf 'not a folder
' > "$dir/backup"
  run as_cron
  if [[ "$status" -ne 1 ]]; then
    echo "When rsync fails (here, backup is a file, not a folder), the script should stop with exit 1 (it gave $status). Put rsync itself after if."
    return 1
  fi
  if ! grep -q ' Backup failed$' "$log" 2>/dev/null; then
    echo "When rsync fails, the log should say \"Backup failed\"."
    return 1
  fi
  if grep -q ' Backup finished$' "$log" 2>/dev/null; then
    echo "The log says \"Backup finished\" though rsync failed. Log it only in the then part of if rsync ...; then."
    return 1
  fi
}

@test "8) crontab.txt runs the script at 18:00 every day, by its full path" {
  line="$(grep -v '^[[:space:]]*#' "$BATS_TEST_DIRNAME/crontab.txt" 2>/dev/null | grep -m 1 '[^[:space:]]' || true)"
  if [[ -z "$line" ]]; then
    echo "crontab.txt has no line yet, only comments. Write the line under them."
    return 1
  fi
  read -r minute hour day month weekday command <<< "$line"
  if [[ ! "$minute" =~ ^0?0$ || ! "$hour" =~ ^18$ ]]; then
    echo "The first two fields are the minute and the hour: 0 18 is 18:00. The line is: $line"
    return 1
  fi
  if [[ "$day" != "*" || "$month" != "*" || "$weekday" != "*" ]]; then
    echo "Every evening means every day of the month, every month and every day of the week: * * *. The line is: $line"
    return 1
  fi
  if [[ ! " $command" =~ \ /[^[:space:]]*/nightly-backup\.sh($|[[:space:]]) ]]; then
    echo "After the five fields comes the script's full path, starting at / and ending in /nightly-backup.sh (no ~ or ./). The line is: $line"
    return 1
  fi
}
