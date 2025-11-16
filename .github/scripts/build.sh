#!/usr/bin/env bash
set -euo pipefail

echo "::group::[DEBUG] Starting build process"

# 安裝依賴（Bun 會自動使用 lockfile 確保一致性）
echo "Installing dependencies..."
bun install --frozen-lockfile

# 複製 .env.example 為 .env（用於建置時需要的環境變數）
echo "Setting up environment files..."
find . -type f -name ".env.example" -exec sh -c 'cp "$1" "${1%.*}"' _ {} \;

# 執行 ESLint 檢查
echo "Running linter..."
bun lint

# 建置 Next.js 應用程式
echo "Building application..."
bun run build

echo "::notice::Build completed successfully"
echo "::endgroup::"

