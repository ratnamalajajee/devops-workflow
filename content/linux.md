# Linux Fundamentals

Almost every server, container, and Kubernetes node you touch runs Linux. You don't need to be a kernel expert. You do need to move around the filesystem, read logs, manage processes and services, understand permissions, and write small scripts without thinking twice. This guide covers exactly that.

> **Note:** Practice in your WSL Ubuntu, or start a throwaway container: `docker run -it --rm ubuntu:24.04 bash`.

## Why Linux matters in DevOps

- **Servers:** EC2 instances, on-prem VMs, and Kubernetes nodes are almost all Linux.
- **Containers:** every Docker image is a small Linux userspace. Debugging containers means debugging Linux.
- **Automation:** CI pipelines run shell commands on Linux runners.
- **Troubleshooting:** when production breaks, you SSH in and use `top`, `journalctl`, `df`, `ss`, and `curl`.

Key idea: **everything is a file**. Configuration, devices, process information (`/proc`), and logs all appear in the filesystem.

## The filesystem hierarchy

| Path | What lives there |
|---|---|
| `/` | Root of everything |
| `/home/<user>` | Your files (`~` is shorthand) |
| `/root` | Home of the root user |
| `/etc` | System-wide configuration (`/etc/ssh/sshd_config`, `/etc/hosts`) |
| `/var` | Variable data. `/var/log` holds logs |
| `/usr/bin`, `/usr/local/bin` | Installed programs |
| `/tmp` | Temporary files, cleared on reboot |
| `/opt` | Optional, third-party software |
| `/proc`, `/sys` | Virtual files exposing kernel and process info |
| `/dev` | Devices (disks, `/dev/null`) |
| `/mnt`, `/media` | Mount points (WSL mounts Windows drives at `/mnt/c`) |

```bash
pwd                 # where am I?
ls /                # list the root
cat /etc/os-release # which distro?
uname -a            # kernel info
```

## Navigation and file operations

```bash
cd ~/code           # change directory (cd alone goes home, cd - goes back)
ls -lah             # long listing, hidden files, human sizes
tree -L 2           # directory tree, 2 levels
mkdir -p app/src/utils     # create nested dirs
touch app/README.md        # create empty file
cp file.txt backup.txt     # copy
cp -r app app-copy         # copy directory
mv old.txt new.txt         # move / rename
rm file.txt                # delete file
rm -r app-copy             # delete directory
ln -s /opt/tool/bin/tool /usr/local/bin/tool   # symbolic link
```

### Finding things

```bash
find . -name "*.log" -mtime -1        # .log files modified in last day
find / -type f -size +100M 2>/dev/null # files bigger than 100MB
grep -rn "ERROR" /var/log/            # search text recursively
grep -i "timeout" app.log | wc -l     # count case-insensitive matches
which python3                         # path of a command
```

> **Warning:** `rm -rf` has no undo and no recycle bin. Double-check the path, especially when it contains a variable.

## Viewing and editing files

```bash
cat file.txt            # print whole file
less /var/log/syslog    # scroll (q to quit, / to search)
head -n 20 file.txt     # first 20 lines
tail -n 50 app.log      # last 50 lines
tail -f app.log         # follow live (Ctrl+C to stop)
wc -l file.txt          # count lines
diff a.conf b.conf      # compare files
```

### Pipes and redirection

The `|` pipe sends one command's output into the next. This is the core of Linux power-use.

```bash
echo "hello" > out.txt        # overwrite file
echo "world" >> out.txt       # append
command 2> errors.txt         # redirect stderr
command > all.txt 2>&1        # stdout + stderr
cat access.log | awk '{print $1}' | sort | uniq -c | sort -rn | head
# -> top client IPs in a web access log
```

### Vim survival kit

You will meet `vim` on servers with no other editor.

| Key | Action |
|---|---|
| `i` | Insert mode (start typing) |
| `Esc` | Back to normal mode |
| `:w` | Save |
| `:q` / `:q!` | Quit / quit without saving |
| `:wq` | Save and quit |
| `/text` | Search, `n` for next |
| `dd` / `u` | Delete line / undo |

Prefer something simpler? `nano file.txt` works too. Save with Ctrl+O and exit with Ctrl+X.

## Users, groups and permissions

```bash
whoami && id                 # current user, UID, groups
sudo adduser deploy          # create user
sudo usermod -aG sudo deploy # give sudo rights
sudo su - deploy             # switch to user
```

### Reading permissions

```text
-rwxr-xr--  1 alice devs  1024 Jan 1 10:00 deploy.sh
 │└┬┘└┬┘└┬┘     │     │
 │ │  │  └ others: r--  (read)
 │ │  └─── group:  r-x  (read, execute)
 │ └────── owner:  rwx  (read, write, execute)
 └──────── type: - file, d directory, l link
```

Numeric form: r=4, w=2, x=1. So `rwxr-xr--` = 7,5,4 = **754**.

```bash
chmod 755 deploy.sh          # rwx r-x r-x
chmod +x script.sh           # add execute
chmod 600 ~/.ssh/id_ed25519  # private key: owner read/write only
sudo chown alice:devs file   # change owner and group
sudo chown -R www-data /var/www
```

> **Tip:** SSH refuses keys that other users can read. If you see `UNPROTECTED PRIVATE KEY FILE`, run `chmod 600` on the key.

## Package management

| Distro family | Tool | Install example |
|---|---|---|
| Ubuntu / Debian | `apt` | `sudo apt install nginx` |
| RHEL / Amazon Linux / Fedora | `dnf` (older: `yum`) | `sudo dnf install nginx` |
| Alpine (common in containers) | `apk` | `apk add curl` |

```bash
sudo apt update              # refresh package index
sudo apt upgrade -y          # upgrade everything
apt search nginx             # search
sudo apt install -y nginx    # install
sudo apt remove nginx        # remove
dpkg -l | grep nginx         # is it installed?
```

## Processes and systemd services

```bash
ps aux | grep nginx       # find a process
top                       # live view (q to quit); try htop
pgrep -a python           # PIDs by name
kill 1234                 # graceful stop (SIGTERM)
kill -9 1234              # force kill (SIGKILL), last resort
nohup ./long-job.sh &     # run in background, survive logout
jobs; fg; bg              # job control
free -h                   # memory
uptime                    # load average
```

### systemd

Most distros use **systemd** to manage long-running services.

```bash
sudo systemctl status nginx     # is it running? recent logs
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx
sudo systemctl enable nginx     # start on boot
systemctl list-units --type=service --state=running
```

Write your own service in `/etc/systemd/system/myapp.service`:

```ini
[Unit]
Description=My demo app
After=network.target

[Service]
User=deploy
WorkingDirectory=/opt/myapp
ExecStart=/usr/bin/python3 -m http.server 9000
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now myapp
curl localhost:9000
```

> **Note:** WSL2 on recent Windows versions supports systemd. If `systemctl` fails, add `[boot]` and `systemd=true` to `/etc/wsl.conf`, then run `wsl --shutdown` from PowerShell.

## Networking basics

```bash
ip a                          # interfaces and IPs
ip route                      # routing table / default gateway
ss -tulpn                     # listening ports and owning process
ping -c 3 google.com          # reachability
curl -I https://example.com   # HTTP headers only
curl -v http://localhost:8080/health
dig example.com +short        # DNS lookup (apt install dnsutils)
nslookup example.com
traceroute example.com        # path to host
cat /etc/hosts /etc/resolv.conf
```

Concepts to know cold:

- **IP and CIDR:** `10.0.1.0/24` = 256 addresses (`10.0.1.0`–`10.0.1.255`). The smaller the suffix, the bigger the network.
- **Ports:** 22 SSH, 80 HTTP, 443 HTTPS, 5432 Postgres, 3306 MySQL, 6443 Kubernetes API.
- **DNS:** turns names into IPs. Many outages are DNS.
- **Firewall:** `sudo ufw status` (Ubuntu), security groups in AWS.

## Disks and storage

```bash
df -h                     # free space per filesystem
du -sh /var/log/*         # size of each item
du -h --max-depth=1 / 2>/dev/null | sort -h | tail
lsblk                     # block devices
sudo mount /dev/xvdf /data
tar -czvf backup.tar.gz /etc/nginx   # compress
tar -xzvf backup.tar.gz -C /tmp      # extract
```

> **Tip:** "Disk full" is a top-5 production incident. `df -h` then `du -sh` is the first move. The usual culprit is logs in `/var/log` or Docker data in `/var/lib/docker`.

## SSH: remote access

```bash
ssh -i ~/.ssh/mykey.pem ubuntu@203.0.113.10       # connect
scp -i ~/.ssh/mykey.pem app.tar.gz ubuntu@203.0.113.10:/tmp/   # copy file
ssh-copy-id user@host                              # install your key on a server
```

Save hosts in `~/.ssh/config` so you can type `ssh web1`:

```text
Host web1
    HostName 203.0.113.10
    User ubuntu
    IdentityFile ~/.ssh/mykey.pem

Host bastion-*
    User ec2-user
    ForwardAgent no
```

Harden the server in `/etc/ssh/sshd_config`: `PasswordAuthentication no`, `PermitRootLogin no`, then `sudo systemctl restart ssh`.

## Bash scripting

A script is a file of commands with a shebang line. This one has the patterns you will reuse everywhere:

```bash
#!/usr/bin/env bash
set -euo pipefail   # exit on error, undefined vars, failed pipes

APP_NAME="${1:-myapp}"          # first argument, default "myapp"
LOG_DIR="/var/log/${APP_NAME}"
THRESHOLD=80

log() { echo "[$(date +'%F %T')] $*"; }

if [[ ! -d "$LOG_DIR" ]]; then
  log "Log dir $LOG_DIR missing, creating"
  mkdir -p "$LOG_DIR"
fi

usage=$(df / --output=pcent | tail -1 | tr -dc '0-9')
if (( usage > THRESHOLD )); then
  log "WARNING: root disk at ${usage}%"
fi

for svc in nginx ssh cron; do
  if systemctl is-active --quiet "$svc"; then
    log "$svc: running"
  else
    log "$svc: NOT running"
  fi
done
```

```bash
chmod +x healthcheck.sh
./healthcheck.sh myapp
```

### Scheduling with cron

```bash
crontab -e
# m  h  dom mon dow  command
*/5 *  *   *   *     /home/deploy/healthcheck.sh >> /tmp/health.log 2>&1
0   2  *   *   *     /home/deploy/backup.sh
```

Use [crontab.guru](https://crontab.guru) to check expressions.

## Logs and troubleshooting

```bash
journalctl -u nginx -f            # follow a service's logs
journalctl -p err --since "1 hour ago"
journalctl --disk-usage
sudo tail -f /var/log/syslog      # Ubuntu system log
dmesg -T | tail                   # kernel messages (OOM kills show here)
```

A troubleshooting checklist when "the app is down":

1. **Is the process running?** `systemctl status app` or `ps aux | grep app`
2. **Is it listening?** `ss -tulpn | grep 8080`
3. **Can I reach it locally?** `curl -v localhost:8080`
4. **What do the logs say?** `journalctl -u app -n 100`
5. **Are resources exhausted?** `df -h`, `free -h`, `top`
6. **Is the network or firewall blocking it?** security groups, `ufw`, DNS

## Lab: build a monitored web server

Do this without looking back at the earlier steps.

1. Install `nginx`, enable it, and confirm `curl localhost` returns the welcome page.
2. Replace `/var/www/html/index.html` with a page showing your name.
3. Create a user `deploy` and make it the owner of `/var/www/html`.
4. Write `healthcheck.sh` that checks nginx is active, port 80 is listening, and disk usage is below 80%. Log the result with a timestamp.
5. Schedule it every 5 minutes with cron, then check the log file fills up.
6. Stop nginx and confirm your script reports the failure.
7. Find the top 5 largest directories under `/var`.

### Cheat sheet

| Task | Command |
|---|---|
| What's using port 80? | `sudo ss -tulpn \| grep :80` |
| Follow service logs | `journalctl -u svc -f` |
| Disk usage | `df -h` / `du -sh *` |
| Memory | `free -h` |
| Find text in files | `grep -rn "text" dir/` |
| Make executable | `chmod +x file` |
| Service on boot | `systemctl enable --now svc` |
