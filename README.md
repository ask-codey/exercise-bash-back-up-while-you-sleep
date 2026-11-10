# Exercise: Back Up While You Sleep

Exercise code for the lesson **Exercise: Back Up While You Sleep** in Bash in Depth on [ask-codey.com](https://www.ask-codey.com).

Finish `nightly-backup.sh`, a backup that cron can run every evening while nobody is at the keyboard. It mirrors the `school-work` folder into `backup` with rsync, works from any folder with a PATH of its own, writes everything into a log with the date and time, lets only one copy run at a time, refuses to mirror a missing or empty folder, and can rehearse with `--dry-run`. Then write the crontab line that runs it at 18:00. A check script runs your script the way cron would and tells you what's done.

## Before you start

You need a terminal (the Terminal app on a Mac, Ubuntu on Linux or in WSL on Windows), and three tools: **bats** runs the check, **rsync** makes the backup and **flock** takes the lock. If `bats --version` or `rsync --version` doesn't print a version, or `command -v flock` prints nothing, install what's missing:

```bash
sudo apt install bats rsync       # Ubuntu, and Ubuntu in WSL (flock is already there)
brew install bats-core rsync flock   # a Mac, with Homebrew
```

## What's here

- `nightly-backup.sh`: the script, with seven jobs, each a comment saying what to do and exactly what to log. For you to finish.
- `crontab.txt`: job 8, the crontab line that runs the script every evening. For you to write.
- `school-work/`: practice files to back up.
- `check.bats`: the check. You don't need to change it.
- `.gitignore`: keeps the `backup/`, `logs/` and `restore-test/` folders out of your repo.

## Run it

Open a terminal in this folder (the one with `nightly-backup.sh` in it), let the script run, and open it:

```bash
chmod +x nightly-backup.sh
nano nightly-backup.sh
```

Write your code under each job's comment, save with Ctrl+O and Enter, and quit with Ctrl+X. Then try it, rehearsal first, and read the log:

```bash
./nightly-backup.sh --dry-run
./nightly-backup.sh
cat logs/backup.log
```

The eight jobs:

1. **A PATH of its own**, set before anything else: `/usr/local/bin:/usr/bin:/bin`, with `/opt/homebrew/bin` at the front on a Mac.
2. **Everything into the log**: make `logs/` if it's missing, then send all output and errors to the end of `logs/backup.log`.
3. **A `log` function** that puts the date and time in front of each line: `2026-11-09 18:00:01 Backup started`.
4. **One copy at a time**: open `logs/backup.lock` as file 9 and take it with `flock -n`; if it's taken, log `Another backup is running. Skipping.` and stop with exit code 0.
5. **Never mirror nothing**: with no `school-work` folder, log `No school-work folder. Nothing was backed up.`; with an empty one, `school-work is empty. Nothing was backed up.`; either way, exit code 1.
6. **`--dry-run`**: add `-n` to rsync's options, and say `Dry run` instead of `Backup` in job 7's messages.
7. **The mirror**: log `Backup started`, run `rsync -av --delete` from `school-work/` into `backup/`, then log `Backup finished`, or `Backup failed` and exit code 1.
8. **`crontab.txt`**: one line, the five time fields for 18:00 every day, then the script's full path.

## Check your work

From this folder:

```bash
bats check.bats
```

At first most checks fail: that is expected. Each job you finish turns its checks into a ✓. A failing check's message says what it expected and what to look at. The check runs a copy of your script in a throwaway folder of its own, from the `/` folder with cron's short PATH, so your practice files, your backup and your log are never touched.

## The rules

- Keep the script in `nightly-backup.sh`, and keep the `here=` line as it is.
- Use `"$here/..."` for every file and folder, so the script works from any folder.
- Log each message exactly as its job gives it: the check compares them word for word.
- Don't install the crontab line from `crontab.txt` until every check passes.

## Tips

- `exec >> "$here/logs/backup.log" 2>&1` sends everything after it into the log.
- `date '+%F %T'` prints the date and the time, such as `2026-11-09 18:00:01`.
- `[[ -z "$(ls -A "$here/school-work")" ]]` passes when the folder is empty.
- An array keeps rsync's options tidy: `options=(-av --delete)`, then `options+=(-n)`, then `rsync "${options[@]}" ...`.
- Keep the slash at the end of both folders: `"$here/school-work/" "$here/backup/"`.
- To try a run the way cron does, use `as-cron.sh` from *Scripts That Run Without You*, with the script's full path.

## When it passes

Do a restore test: copy the backup into a new folder and compare it with the original.

```bash
rsync -a backup/ restore-test/
diff -r school-work restore-test && echo "The restore matches."
```

Then, if you'd like it to run every evening for real, copy your line from `crontab.txt` into your crontab with `crontab -e`. That changes your computer: it runs until you delete the line again.

## Hand it in

When it works, push your solution to a public repo of your own on GitHub, then paste that repo's address into **Submit your exercise** on the lesson page at [ask-codey.com](https://www.ask-codey.com). That's what completes the lesson. The lesson page shows the Git commands, step by step.
