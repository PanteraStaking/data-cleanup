# Oraichain Data Cleanup

This utility helps maintain disk space on Oraichain validator nodes by automating periodic cleanup operations. It includes Telegram notifications to keep you informed about the process.

## Setup Instructions

### 1. Prepare your script (clean_disk.sh)

Replace the Telegram variables inside the script with your own credentials:

```bash
BOT_TOKEN=""
CHAT_ID=""
```

### 2. Set up passwordless sudo for systemctl commands

Run the command to edit the sudoers file:

```bash
sudo visudo
```

Add the following line at the end (replace phil-mainnet with your username):

```
phil-mainnet ALL=(ALL) NOPASSWD: /bin/systemctl
```

This allows your user to run systemctl commands without a password prompt, which is required for cron jobs.

### 3. Verify permissions and ownership

Make sure your script is executable and owned by your user:

```bash
chmod +x /home/phil-mainnet/clean_disk.sh
chown phil-mainnet:phil-mainnet /home/phil-mainnet/clean_disk.sh
```

### 4. Create log folder

Create the log folder and set proper permissions:

```bash
mkdir -p /home/phil-mainnet/log
chown phil-mainnet:phil-mainnet /home/phil-mainnet/log
chmod 755 /home/phil-mainnet/log
```

### 5. Schedule the cron job

Edit your user's crontab:

```bash
crontab -e
```

Add this line to run the script every Friday at 16:10 (4:10 PM):

```
10 16 * * 5 /home/phil-mainnet/clean_disk.sh >> /home/phil-mainnet/log/oraid_snapshot.log 2>&1
```

### 6. Confirm cron job logs and troubleshooting

After the scheduled run time, check the log files for output and errors:

```bash
tail -40 /home/phil-mainnet/log/oraid_snapshot.log
```

If needed, also check the environment log:

```bash
tail -40 /home/phil-mainnet/log/env_cron.log
```

## About This Project

This script automates the process of cleaning up disk space on Oraichain validator nodes, ensuring your validator operates efficiently. The Telegram integration provides real-time notifications about the cleanup process status.
