#!/usr/bin/env bash
set -euo pipefail

echo "::group::[DEBUG] Starting deployment process"

# 檢查必要的環境變數
MISSING_VARS=""
[ -z "${SSH_USER:-}" ] && MISSING_VARS="${MISSING_VARS} SSH_USER"
[ -z "${SSH_PORT:-}" ] && MISSING_VARS="${MISSING_VARS} SSH_PORT"
[ -z "${SSH_HOST:-}" ] && MISSING_VARS="${MISSING_VARS} SSH_HOST"
[ -z "${DEPLOY_SCRIPT_PATH:-}" ] && MISSING_VARS="${MISSING_VARS} DEPLOY_SCRIPT_PATH"
[ -z "${UPDATE_SCRIPT_PATH:-}" ] && MISSING_VARS="${MISSING_VARS} UPDATE_SCRIPT_PATH"

if [ -n "${MISSING_VARS}" ]; then
  echo "::error::Missing required variables:${MISSING_VARS}"
  exit 1
fi

echo "[DEBUG] Environment variables check passed"
echo "[DEBUG] SSH_USER: ${SSH_USER}"
echo "[DEBUG] SSH_PORT: ${SSH_PORT}"
echo "[DEBUG] SSH_HOST: ${SSH_HOST}"
echo "[DEBUG] DEPLOY_SCRIPT_PATH: ${DEPLOY_SCRIPT_PATH}"
echo "[DEBUG] UPDATE_SCRIPT_PATH: ${UPDATE_SCRIPT_PATH}"

# 驗證部署腳本存在
if [ ! -f "${DEPLOY_SCRIPT_PATH}" ]; then
  echo "::error::Deploy script not found at ${DEPLOY_SCRIPT_PATH}"
  exit 1
fi

if [ ! -f "${UPDATE_SCRIPT_PATH}" ]; then
  echo "::error::Update script not found at ${UPDATE_SCRIPT_PATH}"
  exit 1
fi

echo "[DEBUG] Script files verified"

# 檢查 SSH agent 是否運行
if [ -z "${SSH_AUTH_SOCK:-}" ]; then
  echo "::error::SSH_AUTH_SOCK is not set. SSH agent may not be running."
  exit 1
fi

echo "[DEBUG] SSH_AUTH_SOCK: ${SSH_AUTH_SOCK}"

# 測試 SSH 連接
echo "[DEBUG] Testing SSH connection..."
if ! ssh -p "${SSH_PORT}" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${SSH_USER}@${SSH_HOST}" "echo 'SSH connection successful'" 2>&1; then
  echo "::error::Failed to establish SSH connection to ${SSH_USER}@${SSH_HOST}:${SSH_PORT}"
  exit 1
fi

echo "[DEBUG] SSH connection test passed"

# 設置 SSH 選項（使用數組以確保正確展開）
SSH_OPTS=(
  -p "${SSH_PORT}"
  -o "StrictHostKeyChecking=no"
  -o "UserKnownHostsFile=${HOME}/.ssh/known_hosts"
  -o "ServerAliveInterval=10"
  -o "ServerAliveCountMax=12"
  -o "TCPKeepAlive=yes"
  -o "ConnectTimeout=30"
)

# 檢查是否為首次部署
echo "[DEBUG] Checking if this is the first deployment..."
IS_FIRST_DEPLOY=$(ssh "${SSH_OPTS[@]}" "${SSH_USER}@${SSH_HOST}" "[ -f ~/deploy.sh ] && echo 'no' || echo 'yes'" 2>&1) || {
  echo "::error::Failed to check deployment status"
  exit 1
}

if [ "${IS_FIRST_DEPLOY}" = "yes" ]; then
  echo "::notice::This is the first deployment"
else
  echo "::notice::This is an update deployment"
fi

# 上傳腳本到遠端
echo "[DEBUG] Uploading scripts to remote server..."
if ! scp "${SSH_OPTS[@]}" "${UPDATE_SCRIPT_PATH}" "${SSH_USER}@${SSH_HOST}:~/update.sh" 2>&1; then
  echo "::error::Failed to upload update script"
  exit 1
fi

if ! scp "${SSH_OPTS[@]}" "${DEPLOY_SCRIPT_PATH}" "${SSH_USER}@${SSH_HOST}:~/deploy.sh" 2>&1; then
  echo "::error::Failed to upload deploy script"
  exit 1
fi

echo "[DEBUG] Scripts uploaded successfully"

# 執行遠端部署邏輯
echo "[DEBUG] Executing deployment on remote server..."
if [ "${IS_FIRST_DEPLOY}" = "yes" ]; then
  echo "[DEBUG] Running initial deployment script..."
  if ! ssh "${SSH_OPTS[@]}" "${SSH_USER}@${SSH_HOST}" "chmod +x ~/deploy.sh ~/update.sh && ~/deploy.sh" 2>&1; then
    echo "::error::Failed to execute deployment script on remote server"
    exit 1
  fi
else
  echo "[DEBUG] Running update script..."
  if ! ssh "${SSH_OPTS[@]}" "${SSH_USER}@${SSH_HOST}" "chmod +x ~/deploy.sh ~/update.sh && ~/update.sh" 2>&1; then
    echo "::error::Failed to execute update script on remote server"
    exit 1
  fi
fi

echo "::notice::Deployment completed successfully"
echo "::endgroup::"

