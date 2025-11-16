#!/usr/bin/env bash
# 設置 GitHub Actions 環境中的 SSH 連線，用於後續的遠端部署
set -euo pipefail

echo "::group::[DEBUG] Setting up SSH connection"

# 檢查必要的環境變數和 secrets
SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY:-}"
MISSING_VARS=""

[ -z "${SSH_USER:-}" ] && MISSING_VARS="${MISSING_VARS} VAR_SSH_USER"
[ -z "${SSH_PORT:-}" ] && MISSING_VARS="${MISSING_VARS} VAR_SSH_PORT"
[ -z "${SSH_HOST:-}" ] && MISSING_VARS="${MISSING_VARS} SSH_HOST"
[ -z "${SSH_PRIVATE_KEY}" ] && MISSING_VARS="${MISSING_VARS} SSH_PRIVATE_KEY"

if [ -n "${MISSING_VARS}" ]; then
  echo "::error::Missing required variables/secrets:${MISSING_VARS}"
  exit 1
fi

# 設置 SSH 目錄和權限
SSH_DIR="${HOME}/.ssh"
SSH_KEY_FILE="${SSH_DIR}/id_deploy"
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"  # SSH 目錄必須是 700 權限

# 寫入 SSH private key（使用 printf 確保正確處理多行內容）
printf '%s\n' "${SSH_PRIVATE_KEY}" > "${SSH_KEY_FILE}"
chmod 600 "${SSH_KEY_FILE}"  # SSH private key 必須是 600 權限

# 驗證文件是否成功創建
if [ ! -f "${SSH_KEY_FILE}" ]; then
  echo "::error::Failed to create SSH key file at ${SSH_KEY_FILE}"
  exit 1
fi

# 添加 known_hosts（避免首次連線時的確認提示）
ssh-keyscan -p "${SSH_PORT}" -H "${SSH_HOST}" >> "${SSH_DIR}/known_hosts" 2>/dev/null || true
chmod 644 "${SSH_DIR}/known_hosts"

# 啟動 SSH agent 並添加 key
eval "$(ssh-agent -s)"
# 將 SSH agent 環境變數寫入 GitHub Actions 環境，供後續步驟使用
echo "SSH_AUTH_SOCK=${SSH_AUTH_SOCK}" >> $GITHUB_ENV
echo "SSH_AGENT_PID=${SSH_AGENT_PID}" >> $GITHUB_ENV

# 添加 SSH key（如果有 passphrase 則使用 expect）
if [ -n "${SSH_KEY_PASSPHRASE:-}" ]; then
  sudo apt-get update -qq && sudo apt-get install -y expect
  cat > /tmp/ssh-add.exp <<'EXPECT_EOF'
set timeout 10
spawn ssh-add $env(SSH_KEY_FILE)
expect {
  "Enter passphrase" {
    send "$env(SSH_KEY_PASSPHRASE)\r"
    exp_continue
  }
  "Identity added" {
    exit 0
  }
  eof {
    catch wait result
    set exit_code [lindex $result 3]
    exit $exit_code
  }
  timeout {
    exit 1
  }
}
EXPECT_EOF
  SSH_KEY_FILE="${SSH_KEY_FILE}" SSH_KEY_PASSPHRASE="${SSH_KEY_PASSPHRASE}" expect /tmp/ssh-add.exp
else
  ssh-add "${SSH_KEY_FILE}"
fi

echo "::notice::SSH setup completed successfully"
echo "::endgroup::"

