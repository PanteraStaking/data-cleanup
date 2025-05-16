#!/bin/bash

set -e  # Exit on error
set -x  # Debug: print commands as executed

# Set a proper PATH so cron can find all commands
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Log environment to a file for debugging
env > "$HOME/log/env_cron.log"
echo "Script started at $(date)" >> "$HOME/log/oraid_snapshot.log"

# ==== CONFIGURATION ====
SERVICE_NAME="orai-phil"  # Change to your service name: orai-dime / orai-phil / orai
ORAID_HOME="$HOME/.oraid"
SNAPSHOT_DIR="$HOME/oraichain_snapshot"
SNAPSHOT_TMP="$SNAPSHOT_DIR/tmp_snapshot.tar.lz4"
PRIV_STATE_BACKUP="$HOME/priv_validator_state.json"

# ==== TELEGRAM CONFIG ====
BOT_TOKEN=""  # Replace with your real token
CHAT_ID=""  # Replace with your group chat ID

send_telegram_message() {
  local MESSAGE="$1"
  echo "$MESSAGE"
  curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="$MESSAGE" \
    -d parse_mode="Markdown" > /dev/null
}

monitor_sync() {
  send_telegram_message "🔄 Monitoring sync progress every 10 minutes..."
  while true; do
    STATUS_OUTPUT=$(oraid status 2>/dev/null || echo "error")
    if [[ "$STATUS_OUTPUT" == "error" ]]; then
      send_telegram_message "❌ Failed to retrieve \`oraid status\`. Stopping monitoring."
      break
    fi

    CATCHING_UP=$(echo "$STATUS_OUTPUT" | jq -r '.sync_info.catching_up')
    BLOCK_HEIGHT=$(echo "$STATUS_OUTPUT" | jq -r '.sync_info.latest_block_height')

    if [[ "$CATCHING_UP" == "false" ]]; then
      send_telegram_message "✅ Node has fully synced at block *$BLOCK_HEIGHT*."
      break
    else
      send_telegram_message "📡 Still syncing... current block: *$BLOCK_HEIGHT*"
    fi

    sleep 600  # Wait 10 minutes
  done
}

# ==== START PROCESS ====
send_telegram_message "🚀 Starting Oraichain snapshot restore for *$SERVICE_NAME*..."

# Create snapshot dir
mkdir -p "$SNAPSHOT_DIR"

# STEP 1: Get latest snapshot URL
send_telegram_message "📦 Fetching latest snapshot URL..."
URL=$(curl -s https://snapshot.orai.io/snapshot.json | jq -r '.[0].Key')
SNAP_URL="https://orai.s3.us-east-2.amazonaws.com/$URL"
send_telegram_message "🔗 Latest Snapshot URL: $SNAP_URL"

if [[ -z "$SNAP_URL" ]]; then
  send_telegram_message "❌ Failed to retrieve snapshot URL. Aborting."
  exit 1
fi

# STEP 2: Download snapshot
send_telegram_message "⬇️ Downloading snapshot to *$SNAPSHOT_TMP*..."
curl -L "$SNAP_URL" -o "$SNAPSHOT_TMP"

if [[ ! -s "$SNAPSHOT_TMP" ]]; then
  send_telegram_message "❌ Snapshot download failed or file is empty. Aborting."
  exit 1
fi

send_telegram_message "✅ Snapshot downloaded successfully."

# STEP 3: Stop the node service
send_telegram_message "🛑 Stopping Oraichain daemon (*$SERVICE_NAME*)..."
sudo systemctl stop "$SERVICE_NAME"

# STEP 4: Backup priv_validator_state.json
send_telegram_message "🗂 Backing up *priv_validator_state.json*..."
cp "$ORAID_HOME/data/priv_validator_state.json" "$PRIV_STATE_BACKUP"

# STEP 5: Remove data and wasm
send_telegram_message "🧹 Removing old data and wasm..."
rm -rf "$ORAID_HOME/data" "$ORAID_HOME/wasm"

# STEP 6: Extract snapshot
send_telegram_message "📂 Extracting snapshot to *$ORAID_HOME*..."
lz4 -c -d "$SNAPSHOT_TMP" | tar -x -C "$ORAID_HOME"

# Remove snapshot file after extraction
rm -f "$SNAPSHOT_TMP"
send_telegram_message "🗑 Removed snapshot file after extraction."

# STEP 7: Restore validator state
send_telegram_message "♻️ Restoring *priv_validator_state.json*..."
cp "$PRIV_STATE_BACKUP" "$ORAID_HOME/data/"

# STEP 8: Start service
send_telegram_message "🚀 Starting Oraichain daemon (*$SERVICE_NAME*)..."
sudo systemctl daemon-reexec
sudo systemctl restart systemd-journald
sudo systemctl start "$SERVICE_NAME"
sudo systemctl enable "$SERVICE_NAME"

send_telegram_message "✅ Oraichain node *$SERVICE_NAME* restored from snapshot and started successfully."

# STEP 9: Monitor sync status
monitor_sync
