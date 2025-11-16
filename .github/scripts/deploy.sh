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

# 驗證部署腳本存在
if [ ! -f "${DEPLOY_SCRIPT_PATH}" ]; then
  echo "::error::Deploy script not found at ${DEPLOY_SCRIPT_PATH}"
  exit 1
fi

if [ ! -f "${UPDATE_SCRIPT_PATH}" ]; then
  echo "::error::Update script not found at ${UPDATE_SCRIPT_PATH}"
  exit 1
fi

# 設置 SSH 選項
SSH_OPTS="-p ${SSH_PORT} -o StrictHostKeyChecking=no -o UserKnownHostsFile=~/.ssh/known_hosts -o ServerAliveInterval=10 -o ServerAliveCountMax=12 -o TCPKeepAlive=yes -o ConnectTimeout=30"

# 檢查是否為首次部署
echo "Checking if this is the first deployment..."
IS_FIRST_DEPLOY=$(ssh $SSH_OPTS "${SSH_USER}@${SSH_HOST}" "[ -f ~/deploy.sh ] && echo 'no' || echo 'yes'")

if [ "${IS_FIRST_DEPLOY}" = "yes" ]; then
  echo "::notice::This is the first deployment"
else
  echo "::notice::This is an update deployment"
fi

# 上傳腳本到遠端
echo "Uploading scripts to remote server..."
scp $SSH_OPTS "${UPDATE_SCRIPT_PATH}" "${SSH_USER}@${SSH_HOST}:~/update.sh"
scp $SSH_OPTS "${DEPLOY_SCRIPT_PATH}" "${SSH_USER}@${SSH_HOST}:~/deploy.sh"

# 執行遠端部署邏輯
echo "Executing deployment on remote server..."
if [ "${IS_FIRST_DEPLOY}" = "yes" ]; then
  ssh $SSH_OPTS "${SSH_USER}@${SSH_HOST}" "chmod +x ~/deploy.sh ~/update.sh && ~/deploy.sh"
else
  ssh $SSH_OPTS "${SSH_USER}@${SSH_HOST}" "chmod +x ~/deploy.sh ~/update.sh && ~/update.sh"
fi

echo "::notice::Deployment completed successfully"
echo "::endgroup::"

