# Next.js Self Hosting with GitHub Actions CI/CD

> **特別感謝**: 感謝 [Lee Robinson](https://github.com/leerob) 創建的 [next-self-host](https://github.com/leerob/next-self-host) 專案，本專案高度參考了該專案的設計與架構，並在此基礎上添加了 GitHub Actions CI/CD 自動部署功能。

這是一個展示如何透過 **GitHub Actions** 自動部署 Next.js 應用程式到 VPS 的範例專案。本專案使用 Docker、PostgreSQL 和 Nginx，並展示了 Next.js 的多項功能，如快取、ISR、環境變數等。

## 目錄

- [專案特色](#專案特色)
- [支援的 Next.js 功能](#支援的-nextjs-功能)
- [快速開始](#快速開始)
- [前置需求](#前置需求)
- [GitHub Actions 設置](#github-actions-設置)
- [手動部署](#手動部署首次設置)
- [部署腳本說明](#部署腳本說明)
- [資料庫設置](#資料庫設置)
- [本地開發](#本地開發)
- [常用指令](#常用指令)
- [專案結構](#專案結構)
- [相關資源](#相關資源)

## 專案特色

- **自動化部署**: 透過 GitHub Actions 實現 CI/CD，push 到 `main` 分支即自動部署
- **智能部署**: 自動判斷首次部署或更新部署，執行對應的部署腳本
- **完整建置檢查**: 所有分支的 push 都會執行建置檢查，確保程式碼品質
- **SSH 安全連線**: 使用 SSH 金鑰進行安全的遠端部署
- **Docker 容器化**: Next.js 應用和 PostgreSQL 資料庫都在 Docker 容器中運行
- **Nginx 反向代理**: 配置 HTTPS、SSL 憑證和速率限制

## 支援的 Next.js 功能

本專案展示了多種 Next.js 功能：

- Image Optimization（圖片優化）
- Streaming（串流）
- 與 Postgres 資料庫互動
- Caching（快取）
- Incremental Static Regeneration（ISR）
- 讀取環境變數
- 使用 Middleware
- 伺服器啟動時執行程式碼
- Cron job 觸發 Route Handler

## 快速開始

### 自動部署（推薦）

1. **設置前置需求**（見下方詳細說明）
2. **配置 GitHub Secrets 和 Variables**（見 [GitHub Actions 設置](#github-actions-設置)）
3. **修改部署腳本配置**：編輯 `deploy.sh` 中的網域名稱和 Email
4. **Push 到 main 分支**：GitHub Actions 會自動執行部署

### 手動部署

如果你偏好手動部署，請參考 [手動部署](#手動部署首次設置) 章節。

## 前置需求

在開始之前，請確保你已準備好以下項目：

1. **GitHub Repository**
   - ⚠️ **重要限制**: 目前部署流程僅支援 **public repository**
   - 部署腳本會在伺服器上執行 `git clone`/`git pull`，private repository 需要額外的認證設定
   - 如需使用 private repository，需要修改部署腳本以支援 GitHub Personal Access Token 或 SSH key 認證

2. **網域名稱**（可選）
   - 如果只是想測試自動化部署流程，可以跳過這一步
   - 如需使用 HTTPS，則需要網域名稱

3. **Linux Ubuntu 伺服器**
   - 推薦使用 [DigitalOcean Droplet](https://www.digitalocean.com/products/droplets)
   - 建議至少 1GB RAM、1 vCPU

4. **DNS 設定**（如果使用網域名稱）
   - 建立一個 `A` DNS 記錄，指向你的伺服器 IPv4 位址
   - 等待 DNS 傳播完成（通常需要幾分鐘到幾小時）

5. **SSH 金鑰對**
   - 用於 GitHub Actions 連線到 VPS
   - 如果你使用 DigitalOcean，建立 VPS 時會提供設定指南
   - 確保私鑰已妥善保存，並記下 passphrase（如果有設定）

## GitHub Actions 設置

### 1. 設置 GitHub Secrets 和 Variables

前往你的 GitHub Repository → **Settings** → **Secrets and variables** → **Actions**，設置以下內容：

#### Secrets（機密資訊）

| Secret 名稱 | 說明 | 範例 |
|------------|------|------|
| `SSH_HOST` | VPS 的 IP 位址或網域名稱 | `123.45.67.89` 或 `example.com` |
| `SSH_PRIVATE_KEY` | SSH 私鑰完整內容（包含 `-----BEGIN` 和 `-----END`） | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `SSH_KEY_PASSPHRASE` | （可選）SSH 私鑰的 passphrase，如果沒有設定則留空 | `your-passphrase` |

> **提示**: 複製 SSH 私鑰時，請確保包含完整的內容，包括開頭和結尾的標記。

#### Variables（變數）

| Variable 名稱 | 說明 | 預設值 |
|-------------|------|--------|
| `VAR_SSH_USER` | SSH 使用者名稱 | `root` |
| `VAR_SSH_PORT` | SSH 連接埠 | `22` |

### 2. 工作流程

- **Build Job**: 所有分支的 push 都會執行建置檢查
- **Deploy Job**: 僅 `main` 分支的 push 且 Build 成功後，會自動判斷首次部署或更新部署，執行對應的部署腳本
  - 首次部署：執行 `deploy.sh`（完整環境設置）
  - 更新部署：執行 `update.sh`（更新程式碼並重啟容器）

> **注意**: 
> - `deploy.sh` 中的網域名稱和 Email 需要根據你的實際情況調整
> - ⚠️ **Repository 限制**: 目前僅支援 **public repository**。部署腳本會在伺服器上執行 `git clone`/`git pull`，private repository 需要額外的認證設定

## 手動部署（首次設置）

如果你想手動進行首次部署，可以按照以下步驟操作：

### 步驟 1: SSH 連線到伺服器

```bash
# 使用密碼登入
ssh root@your_server_ip

# 或使用 SSH 私鑰
ssh -o IdentitiesOnly=yes -o ForwardAgent=yes -i /your/ssh/private/key/path root@your_server_ip
```

### 步驟 2: 下載部署腳本

```bash
# 下載部署腳本（請替換為你的 Repository URL）
curl -o ~/deploy.sh https://raw.githubusercontent.com/YOUR_USERNAME/next-self-host/main/deploy.sh
```

### 步驟 3: 修改部署腳本配置

編輯 `deploy.sh`，修改以下變數：

```bash
nano ~/deploy.sh
```

需要修改的變數（通常在檔案開頭）：

- `DOMAIN_NAME`: 你的網域名稱（例如：`example.com`）
- `EMAIL`: 你的 Email（用於 Let's Encrypt SSL 憑證）
- `REPO_URL`: 你的 GitHub Repository URL
  - ⚠️ **限制**: 目前僅支援 **public repository**
  - 如需使用 private repository，需要修改腳本以支援 GitHub Personal Access Token 或 SSH key 認證

### 步驟 4: 執行部署腳本

```bash
# 賦予執行權限
chmod +x ~/deploy.sh

# 執行部署腳本
./deploy.sh
```

部署過程可能需要 5-10 分鐘，請耐心等待。部署完成後，你的應用程式將可在設定的網域存取。

## 部署腳本說明

### deploy.sh（首次部署）

執行完整環境設置：系統更新、安裝 Docker/Nginx、申請 SSL 憑證、建置應用程式等。

### update.sh（更新部署）

拉取最新程式碼、重新建置映像檔並重啟容器。

## 資料庫設置

使用 Drizzle 進行資料庫遷移：

```bash
docker exec -it myapp-web-1 sh
bun run db:push
```

本地開發可使用 Drizzle Studio 視覺化管理：

```bash
bun run db:studio
```

## 本地開發

使用 Docker Compose：

```bash
docker-compose up -d
```

Next.js 應用程式將在 `http://localhost:3000` 運行。

或使用 Bun 直接運行：

```bash
bun install
bun run dev
```

## 常用指令

```bash
# Docker 容器管理
docker-compose ps              # 檢查容器狀態
docker-compose logs web         # 查看日誌
docker-compose restart web      # 重啟容器

# 伺服器管理
sudo systemctl restart nginx    # 重啟 Nginx
docker exec -it myapp-web-1 sh  # 進入容器

# 資料庫管理
bun run db:push                 # 推送 schema 變更
bun run db:studio               # 啟動 Drizzle Studio
```

## 專案結構

```
.
├── .github/workflows/ci-cd.yaml  # GitHub Actions CI/CD
├── app/                          # Next.js App Router
├── deploy.sh                     # 首次部署腳本
├── update.sh                     # 更新部署腳本
├── docker-compose.yml            # Docker Compose 配置
└── Dockerfile                    # Docker 映像檔配置
```

## 相關資源

- [原始參考專案](https://github.com/leerob/next-self-host) - leerob/next-self-host

## 授權

本專案採用 [MIT License](LICENSE) 授權。