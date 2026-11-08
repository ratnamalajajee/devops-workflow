# Bash Scripting for DevOps

Bash scripts glue DevOps work together: health checks, backups, log analysis, deployment steps, clean-up jobs and the commands inside every CI pipeline. This guide teaches Bash from your first script to real automation, with **easy example programs** you can copy and adapt, the **free resources** worth learning from, and the **interview questions** DevOps candidates are asked most.

> **Note:** You need a Linux shell: WSL on Windows, the macOS terminal, or the in-browser terminal in the [Practice lab](#/lab). Complete the [Linux guide](#/tool/linux) first if commands like `grep`, `chmod` and `ps` are new to you.

## Start here: scripting in simple words

> **In simple words:** A script is a **text file of commands** that run one after another. Anything you type more than twice belongs in a script: it runs the same way every time, anyone on the team can use it, and you can run it on a schedule.

### Bash or Python?

| Use **Bash** when… | Use **Python** when… |
|---|---|
| You're mostly running other commands (`kubectl`, `aws`, `docker`, `git`) | You need real data structures, logic or calculations |
| The script is short (up to ~100 lines) | The script is growing large, or needs tests |
| It's a CI step, a container entrypoint, or a cron job | You call APIs, parse JSON or YAML heavily, or use SDKs like **boto3** |
| Every Linux machine must run it with nothing installed | You need good error handling and reusable modules |

Most DevOps engineers use **both**. See [Python for DevOps](#/tool/python-devops).

### What to learn, in order

| Stage | Topics |
|---|---|
| 1. Basics | Shebang, `chmod +x`, variables, quoting, `echo` / `printf`, arguments (`$1`, `$@`), exit codes (`$?`) |
| 2. Logic | `if` / `[[ ]]` tests, `case`, `for` / `while` loops, functions, `local` |
| 3. Text tools | Pipes, `grep`, `sed`, `awk`, `cut`, `sort`, `uniq`, `xargs`, `jq` for JSON |
| 4. Robust scripts | `set -euo pipefail`, `trap`, logging, input validation, idempotency, `shellcheck` |
| 5. DevOps use | Scripts around `aws`, `kubectl`, `docker`; cron and systemd timers; scripts in CI |

### Check yourself

1. Name two signs a task should become a script.
2. Your script calls `kubectl` five times and parses nothing. Bash or Python?
3. What does a script return to tell the caller it failed?

> **Tip:** Answers: 1) You repeat it often, other people need to run it, or it must run on a schedule. 2) Bash: it's mostly running commands. 3) A non-zero exit code (`exit 1`).

## Your first script

> **In simple words:** The first line (the **shebang**) says which program runs the file. Make the file executable, then run it. One extra line, `set -euo pipefail`, makes scripts stop on errors instead of carrying on silently.

```bash
mkdir -p ~/scripts && cd ~/scripts
cat > hello.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail       # stop on errors, undefined variables, and failed pipes

# Comments start with #
name="${1:-DevOps}"      # first argument, or "DevOps" if none given
echo "Hello, ${name}! Today is $(date +%A)."
echo "You are $(whoami) on $(hostname)"
EOF

chmod +x hello.sh
./hello.sh
./hello.sh Asha
```

| Line | Meaning |
|---|---|
| `#!/usr/bin/env bash` | Run this file with Bash, wherever it's installed |
| `set -e` | Exit as soon as a command fails |
| `set -u` | Treat unset variables as errors (catches typos) |
| `set -o pipefail` | A pipeline fails if **any** command in it fails, not only the last |
| `$(command)` | Command substitution: insert the command's output |

## Variables, quoting and arguments

> **In simple words:** Variables store values. **Always put variables in double quotes** (`"$file"`), so names with spaces don't break your script. Arguments passed to the script arrive as `$1`, `$2` and so on.

```bash
#!/usr/bin/env bash
set -euo pipefail

env="dev"                          # no spaces around =
count=3
today=$(date +%F)                  # 2026-11-08
log_dir="/var/log/my app"          # contains a space

echo "Deploying to ${env}"         # ${} makes the variable name clear
echo "Files: $(ls "$log_dir" 2>/dev/null | wc -l)"   # quotes keep "my app" as one argument
echo 'Single quotes are literal: $env'

# Arguments
echo "Script: $0"
echo "First arg: ${1:-none}"       # default if missing
echo "Number of args: $#"
echo "All args: $@"

# Arithmetic
total=$(( count * 2 + 1 ))
echo "Total: $total"

# Read input from the user
read -rp "Continue? (y/n) " answer
[[ "$answer" == "y" ]] || { echo "Aborted"; exit 1; }
```

| Syntax | Meaning |
|---|---|
| `"$var"` | Value, with spaces kept safe |
| `${var:-default}` | Value, or `default` if unset or empty |
| `${var:?message}` | Value, or exit with `message` if unset (great for required settings) |
| `${#var}` | Length of the string |
| `${file%.log}` / `${path##*/}` | Strip a suffix / keep only the file name |
| `$?` | Exit code of the last command (0 = success) |
| `$$` | PID of the current script |

## Conditions and decisions

> **In simple words:** `if` runs commands only when a test is true. `[[ ... ]]` is Bash's test command: it checks files, strings and numbers. `case` is a neat way to handle several options.

```bash
#!/usr/bin/env bash
set -euo pipefail

file="${1:?usage: $0 <file>}"

if [[ -f "$file" ]]; then
  echo "$file exists ($(wc -l < "$file") lines)"
elif [[ -d "$file" ]]; then
  echo "$file is a directory"
else
  echo "$file not found" >&2
  exit 1
fi

usage=$(df / --output=pcent | tail -1 | tr -dc '0-9')
if (( usage > 80 )); then
  echo "WARNING: disk at ${usage}%"
fi

# Did a command succeed? Test it directly
if systemctl is-active --quiet nginx; then
  echo "nginx is running"
fi

env="${ENV:-dev}"
case "$env" in
  dev|test) replicas=1 ;;
  staging)  replicas=2 ;;
  prod)     replicas=3 ;;
  *)        echo "Unknown env: $env" >&2; exit 1 ;;
esac
echo "Replicas for $env: $replicas"
```

| Test | True when |
|---|---|
| `-f file` / `-d dir` / `-e path` | Regular file exists / directory exists / anything exists |
| `-r` / `-w` / `-x file` | Readable / writable / executable |
| `-z "$s"` / `-n "$s"` | String is empty / not empty |
| `"$a" == "$b"` / `!=` | Strings equal / different (`==` with a pattern: `[[ $f == *.log ]]`) |
| `(( a > b ))` | Numeric comparison (or `-gt`, `-lt`, `-eq` inside `[[ ]]`) |
| `cmd1 && cmd2` / `cmd1 \|\| cmd2` | Run cmd2 only if cmd1 succeeded / failed |

## Loops and functions

> **In simple words:** Loops repeat work: for every server, every file, every line. Functions give a block of commands a name, so you can reuse it and keep the script readable.

```bash
#!/usr/bin/env bash
set -euo pipefail

# for: over a list, files, or a range
for env in dev staging prod; do
  echo "Checking $env"
done

for f in /var/log/*.log; do
  [[ -e "$f" ]] || continue            # no matches → skip
  echo "$f: $(du -h "$f" | cut -f1)"
done

for i in {1..5}; do echo "Attempt $i"; done

# while read: process a file line by line (safe with spaces)
while IFS= read -r host; do
  [[ -z "$host" || "$host" == \#* ]] && continue   # skip blanks and comments
  echo "Host: $host"
done < servers.txt

# retry until it works (max 5 tries)
attempt=1
until curl -fsS http://localhost:8080/health > /dev/null; do
  (( attempt++ >= 5 )) && { echo "Service never became healthy" >&2; exit 1; }
  sleep 2
done

# functions
log() { echo "[$(date +'%F %T')] $*"; }

check_port() {
  local host="$1" port="$2"            # local = only visible inside the function
  if timeout 3 bash -c "</dev/tcp/${host}/${port}" 2>/dev/null; then
    log "OK   ${host}:${port}"
  else
    log "FAIL ${host}:${port}"
    return 1                           # a non-zero return = failure
  fi
}

check_port localhost 22 || true
```

## Text processing toolkit

> **In simple words:** Most DevOps scripting is turning text (logs, command output, JSON) into answers. Six tools do almost all of it, and you chain them with `|`.

| Tool | Job | Example |
|---|---|---|
| `grep` | Find matching lines | `grep -i "error" app.log` |
| `cut` | Pick columns | `cut -d: -f1 /etc/passwd` |
| `awk` | Columns, filters, sums | `awk '$9 >= 500 {print $7}' access.log` |
| `sed` | Find and replace | `sed -i 's/v1.2/v1.3/g' deploy.yaml` |
| `sort` / `uniq -c` | Sort, count duplicates | `sort \| uniq -c \| sort -rn` |
| `jq` | Read JSON | `jq -r '.items[].metadata.name'` |
| `xargs` | Turn lines into arguments | `cat ids.txt \| xargs -n1 echo` |

Real one-liners:

```bash
# Top 10 client IPs in an nginx access log
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head

# Count HTTP status codes
awk '{print $9}' access.log | sort | uniq -c | sort -rn

# Errors per hour
grep "ERROR" app.log | cut -c1-13 | uniq -c

# Replace an image tag in a manifest (backup kept as .bak)
sed -i.bak 's#image: myapp:.*#image: myapp:1.4.2#' deployment.yaml

# Names of pods that aren't Running
kubectl get pods -A -o json | jq -r '.items[] | select(.status.phase != "Running") | "\(.metadata.namespace)/\(.metadata.name)"'

# Instance IDs and names from the AWS CLI
aws ec2 describe-instances --output json \
  | jq -r '.Reservations[].Instances[] | [.InstanceId, (.Tags // [] | map(select(.Key=="Name"))[0].Value // "-")] | @tsv'
```

## Writing robust scripts

> **In simple words:** A good script fails loudly and early, cleans up after itself, logs what it's doing, and is safe to run twice. These habits separate a quick hack from something the team can trust at 3 a.m.

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_NAME=$(basename "$0")
readonly TMP_DIR=$(mktemp -d)

log()  { echo "[$(date +'%F %T')] [INFO]  $*"; }
warn() { echo "[$(date +'%F %T')] [WARN]  $*" >&2; }
die()  { echo "[$(date +'%F %T')] [ERROR] $*" >&2; exit 1; }

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT                                   # always runs, even on errors
trap 'die "Failed at line $LINENO"' ERR             # report where it failed

usage() { echo "Usage: $SCRIPT_NAME <environment>"; exit 2; }
[[ $# -eq 1 ]] || usage
command -v kubectl > /dev/null || die "kubectl is not installed"

ENV="$1"
log "Working in $TMP_DIR for $ENV"
# … real work …
mkdir -p "/tmp/deploy-$ENV"        # -p makes it safe to run twice (idempotent)
log "Done"
```

| Habit | Why |
|---|---|
| `set -euo pipefail` | Don't continue after a failure |
| `trap cleanup EXIT` | Temp files and locks are removed even if the script crashes |
| `die` / `warn` to stderr (`>&2`) | Errors stay visible even when output is piped |
| Check arguments and required tools first | Fail in the first second, not halfway through a deployment |
| Idempotent commands (`mkdir -p`, `kubectl apply`, "create if missing") | Safe to re-run after a partial failure |
| `bash -x script.sh` or `set -x` | Prints each command as it runs, for debugging |
| **ShellCheck** (`shellcheck script.sh`) | Catches quoting bugs and common mistakes before they bite |

## Example programs

> **In simple words:** Small, real scripts you can copy and adapt. Each one solves a common DevOps chore, and together they use everything above.

### 1. Disk usage alert

```bash
#!/usr/bin/env bash
# disk-alert.sh: warn when any filesystem is above a threshold
set -euo pipefail
THRESHOLD="${1:-80}"

df -P -x tmpfs -x devtmpfs | awk 'NR>1 {gsub("%","",$5); print $5, $6}' | while read -r used mount; do
  if (( used >= THRESHOLD )); then
    echo "ALERT: ${mount} is ${used}% full"
  fi
done
```

### 2. Service health check with automatic restart

```bash
#!/usr/bin/env bash
# service-check.sh nginx sshd cron
set -euo pipefail

for svc in "$@"; do
  if systemctl is-active --quiet "$svc"; then
    echo "OK      $svc"
  else
    echo "DOWN    $svc → restarting"
    sudo systemctl restart "$svc" && echo "STARTED $svc" || echo "FAILED  $svc" >&2
  fi
done
```

### 3. Log analyzer

```bash
#!/usr/bin/env bash
# log-report.sh /var/log/nginx/access.log
set -euo pipefail
log="${1:?usage: $0 <access.log>}"

echo "Total requests : $(wc -l < "$log")"
echo "Unique visitors: $(awk '{print $1}' "$log" | sort -u | wc -l)"
echo; echo "Status codes:";      awk '{print $9}' "$log" | sort | uniq -c | sort -rn
echo; echo "Top 5 URLs:";        awk '{print $7}' "$log" | sort | uniq -c | sort -rn | head -5
echo; echo "Top 5 IPs with 5xx:"; awk '$9 ~ /^5/ {print $1}' "$log" | sort | uniq -c | sort -rn | head -5
```

### 4. Backup with rotation (keep the last 7)

```bash
#!/usr/bin/env bash
# backup.sh /etc/nginx /backups
set -euo pipefail
src="${1:?source dir}"; dest="${2:?backup dir}"; keep=7

mkdir -p "$dest"
archive="$dest/$(basename "$src")-$(date +%F-%H%M).tar.gz"
tar -czf "$archive" -C "$(dirname "$src")" "$(basename "$src")"
echo "Created $archive ($(du -h "$archive" | cut -f1))"

# delete all but the newest $keep backups of this source
ls -1t "$dest"/"$(basename "$src")"-*.tar.gz | tail -n +$((keep + 1)) | xargs -r rm -v
```

### 5. Check many servers and ports from a file

```bash
#!/usr/bin/env bash
# port-check.sh targets.txt      (lines like:  web1.example.com 443)
set -euo pipefail
failed=0
while read -r host port; do
  [[ -z "$host" || "$host" == \#* ]] && continue
  if timeout 3 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
    printf "%-30s %-6s OPEN\n" "$host" "$port"
  else
    printf "%-30s %-6s CLOSED\n" "$host" "$port"; failed=$((failed + 1))
  fi
done < "${1:?usage: $0 <targets.txt>}"
exit $(( failed > 0 ))          # non-zero exit if anything failed (useful in CI)
```

### 6. AWS: find and stop forgotten dev instances (dry run by default)

```bash
#!/usr/bin/env bash
# stop-dev-instances.sh [--apply]
set -euo pipefail
apply="${1:-}"

ids=$(aws ec2 describe-instances \
  --filters "Name=tag:env,Values=dev" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' --output text)

[[ -z "$ids" ]] && { echo "No running dev instances"; exit 0; }
echo "Running dev instances: $ids"

if [[ "$apply" == "--apply" ]]; then
  aws ec2 stop-instances --instance-ids $ids --output table
else
  echo "Dry run. Re-run with --apply to stop them."
fi
```

### 7. Kubernetes: report unhealthy pods across the cluster

```bash
#!/usr/bin/env bash
# k8s-unhealthy.sh
set -euo pipefail
kubectl get pods -A --no-headers | awk '$4 !~ /Running|Completed/ || $5+0 > 5 {
  printf "%-20s %-45s %-20s restarts=%s\n", $1, $2, $4, $5 }'
```

### 8. Docker clean-up

```bash
#!/usr/bin/env bash
# docker-cleanup.sh: free space on build agents
set -euo pipefail
echo "Before:"; docker system df
docker container prune -f --filter "until=24h"
docker image prune -af --filter "until=72h"
docker builder prune -f --filter "until=72h"
echo "After:"; docker system df
```

## Scheduling scripts: cron and systemd timers

> **In simple words:** Scripts become automation when they run by themselves. **cron** is the classic scheduler; **systemd timers** add logging and catch up on runs missed while the machine was off.

```bash
crontab -e
# min hour day month weekday  command
*/5  *    *   *     *        /home/ops/scripts/service-check.sh nginx >> /var/log/service-check.log 2>&1
0    2    *   *     *        /home/ops/scripts/backup.sh /etc/nginx /backups
0    20   *   *     1-5      /home/ops/scripts/stop-dev-instances.sh --apply
```

- Use **absolute paths**: cron runs with a minimal `PATH` and none of your login settings.
- Always redirect output (`>> file 2>&1`), or it's lost or mailed.
- Check expressions at [crontab.guru](https://crontab.guru).

A systemd timer for the same backup (logs end up in `journalctl -u backup`):

```ini
# /etc/systemd/system/backup.service
[Unit]
Description=Nightly nginx config backup

[Service]
Type=oneshot
ExecStart=/home/ops/scripts/backup.sh /etc/nginx /backups

# /etc/systemd/system/backup.timer
[Unit]
Description=Run backup nightly

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload && sudo systemctl enable --now backup.timer
systemctl list-timers | grep backup
```

## Where to learn more (free)

> **In simple words:** These free resources take you from zero to confident. Read one guide end to end, then practise every day with the puzzles and exercises.

| Resource | What it's good for |
|---|---|
| [The Linux Command Line (free book)](https://linuxcommand.org/tlcl.php) | Complete beginner-friendly book: shell, commands, then scripting |
| [BashGuide (Greg's Wiki)](https://mywiki.wooledge.org/BashGuide) | The most correct Bash tutorial: quoting, arrays, best practice |
| [Bash Pitfalls](https://mywiki.wooledge.org/BashPitfalls) | 60+ common mistakes and how to avoid them |
| [GNU Bash Reference Manual](https://www.gnu.org/software/bash/manual/bash.html) | The official reference |
| [ShellCheck](https://www.shellcheck.net/) | Paste a script and get bugs explained. Also a CLI and editor plugin |
| [explainshell.com](https://explainshell.com/) | Paste any command line and see every part explained |
| [tldr pages](https://tldr.sh/) | Short, practical examples for every command |
| [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) | How professional teams write and structure shell scripts |
| [OverTheWire: Bandit](https://overthewire.org/wargames/bandit/) | A fun game that teaches the Linux shell level by level |
| [Exercism Bash track](https://exercism.org/tracks/bash) | Free exercises with mentor feedback |

## Interview questions

> **In simple words:** Common shell scripting questions from DevOps interviews, with **short, simple answers** and a small example. Read the answer, run the example once, then try to explain it in your own words.

### Basic questions

#### 1. What is a shell script?
A text file with Linux commands that run one after another. Instead of typing the same commands every day, you put them in a script and run the script.

#### 2. What is the first line `#!/usr/bin/env bash`?
It's called the **shebang**. It tells Linux which program should run the file: here, Bash.

#### 3. How do you run a script?
Make it executable once, then run it:

```bash
chmod +x myscript.sh
./myscript.sh
```

#### 4. How do you create and use a variable?
Write the name, `=` and the value, with **no spaces** around `=`. Put `$` in front to use it.

```bash
env="dev"
echo "Deploying to $env"
```

#### 5. How do you read the values passed to a script?
`$1` is the first value, `$2` the second, `$#` is how many were passed.

```bash
# ./deploy.sh prod 3
echo "Environment: $1, replicas: $2"
```

#### 6. What is `$?`?
The result of the last command: **0 means it worked**, any other number means it failed.

```bash
ls /not-there
echo $?        # prints 2 (failed)
```

#### 7. How do you write an `if` condition?

```bash
if [[ -f /etc/hosts ]]; then
  echo "File exists"
else
  echo "File not found"
fi
```

#### 8. How do you write a `for` loop?

```bash
for server in web1 web2 web3; do
  echo "Checking $server"
done
```

#### 9. How do you read a file line by line?

```bash
while read -r line; do
  echo "Line: $line"
done < servers.txt
```

#### 10. What's the difference between `>` and `>>`?
`>` replaces the file's content. `>>` adds to the end of the file.

```bash
echo "first"  > out.txt     # file has: first
echo "second" >> out.txt    # file has: first, second
```

#### 11. What does `2>&1` mean?
Send error messages to the same place as normal output, for example both into one log file.

```bash
./backup.sh > backup.log 2>&1
```

#### 12. How do you search for a word in a file?
Use `grep`. `-i` ignores upper/lower case, and `-c` counts matching lines.

```bash
grep "ERROR" app.log
grep -c "ERROR" app.log     # how many lines have ERROR
```

#### 13. How do you replace text in a file?

```bash
sed -i 's/old/new/g' config.txt
```

#### 14. How do you print only one column?
`awk` splits each line into columns: `$1` is the first, `$2` the second.

```bash
awk '{print $1}' access.log     # first column (the IP address)
```

#### 15. How do you run a script automatically every day?
Use **cron**. Run `crontab -e` and add a line. This one runs at 2 a.m. every day:

```bash
0 2 * * * /home/ops/backup.sh
```

### More advanced questions

#### 16. What does `set -e` do?
It stops the script as soon as any command fails, so a broken step doesn't carry on. Most scripts start with `set -euo pipefail` for extra safety.

#### 17. How do you debug a script?
Run it with `bash -x`. It prints every command before running it, so you can see where it goes wrong.

```bash
bash -x myscript.sh
```

#### 18. How do you find and delete log files older than 7 days?

```bash
find /var/log/myapp -name "*.log" -mtime +7 -delete
```

#### 19. How do you count unique IP addresses in a log?

```bash
awk '{print $1}' access.log | sort -u | wc -l
```

#### 20. How do you check if a service is running?

```bash
systemctl is-active nginx       # prints "active" or "inactive"
```

#### 21. How do you check if a port is open?

```bash
ss -tulpn | grep 8080           # on this machine
nc -zv db-server 5432           # on another machine
```

#### 22. How do you stop a process by its name?

```bash
pkill -f myapp
```

#### 23. How do you keep a script running after you log out?

```bash
nohup ./long-job.sh > job.log 2>&1 &
```

#### 24. How do you write a function?

```bash
greet() {
  echo "Hello, $1"
}
greet "DevOps"
```

#### 25. What's the difference between `./script.sh` and `source script.sh`?
`./script.sh` runs in a **new** shell, so its variables disappear afterwards. `source` runs it in **your current** shell, so its variables stay (useful for loading settings).

#### 26. How do you keep passwords out of scripts?
Never write them inside the script. Read them from an environment variable, or from a secrets manager such as AWS Secrets Manager.

```bash
db_password="${DB_PASSWORD:?DB_PASSWORD is not set}"
```

### Practice tasks

1. Write `health.sh` that checks disk, memory and three services, and exits non-zero if anything is wrong.
2. Turn the log analyzer into a script that emails or prints a daily report from yesterday's log only.
3. Write `rollout.sh <deployment> <image>` that sets a new image with `kubectl set image`, waits with `kubectl rollout status`, and rolls back on failure.
4. Run `shellcheck` on every script you've written and fix each warning.
5. Schedule one script with cron and one with a systemd timer, and check both ran.
