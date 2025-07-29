#!/bin/bash

# Claude Code開発テンプレート Stage 1 初期化スクリプト
# 技術スタック非依存の最小限セットアップ

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
TEMPLATE_DIR="$(dirname "$SCRIPT_DIR")"

# 色付きログ用の定数
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# プロジェクト名を取得
PROJECT_NAME=$(basename "$PWD")

echo -e "${BLUE}🚀 Claude Code開発テンプレート Stage 1 初期化${NC}"
echo -e "${BLUE}📁 プロジェクト: ${PROJECT_NAME}${NC}"
echo ""

# ファイルをコピーする関数
copy_file() {
    local src="$1"
    local dest="$2"
    
    # 既存ファイルチェック
    if [ -f "$dest" ]; then
        echo -e "${YELLOW}⚠️  スキップ: $dest (既存ファイル)${NC}"
        return
    fi
    
    # ディレクトリ作成
    mkdir -p "$(dirname "$dest")"
    
    # ファイルコピー
    echo -e "${GREEN}✅ 作成: $dest${NC}"
    cp "$src" "$dest"
}

# テンプレート処理関数
process_template() {
    local src="$1"
    local dest="$2"
    
    # 既存ファイルチェック
    if [ -f "$dest" ]; then
        echo -e "${YELLOW}⚠️  スキップ: $dest (既存ファイル)${NC}"
        return
    fi
    
    # ディレクトリ作成
    mkdir -p "$(dirname "$dest")"
    
    # テンプレート処理
    echo -e "${GREEN}✅ 作成: $dest${NC}"
    sed -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
        -e "s|{{PROJECT_DESCRIPTION}}|$PROJECT_NAME - Claude Codeで開発|g" \
        "$src" > "$dest"
}

echo -e "${BLUE}📋 Stage 1: 最小限のClaude Code環境をセットアップ中...${NC}"
echo ""

# CLAUDE.mdのコピー
copy_file "$TEMPLATE_DIR/stage1/CLAUDE.md" "CLAUDE.md"

# DEVELOPMENT_GUIDE.mdのコピー
copy_file "$TEMPLATE_DIR/stage1/DEVELOPMENT_GUIDE.md" "DEVELOPMENT_GUIDE.md"

# DEVELOPMENT_CHECKLIST.mdのコピー
copy_file "$TEMPLATE_DIR/stage1/DEVELOPMENT_CHECKLIST.md" "DEVELOPMENT_CHECKLIST.md"

# README.mdの処理
process_template "$TEMPLATE_DIR/stage1/README.md.template" "README.md"

# .gitignoreのコピー
copy_file "$TEMPLATE_DIR/stage1/.gitignore" ".gitignore"

# scripts/worktree.shのコピー
mkdir -p scripts
copy_file "$TEMPLATE_DIR/stage1/scripts/worktree.sh" "scripts/worktree.sh"
chmod +x scripts/worktree.sh

# Git初期化（まだ初期化されていない場合）
if [ ! -d ".git" ]; then
    echo ""
    echo -e "${BLUE}📋 Gitリポジトリを初期化中...${NC}"
    git init
    echo -e "${GREEN}✅ Gitリポジトリを初期化しました${NC}"
fi

echo ""
echo -e "${GREEN}✅ Stage 1 の適用が完了しました！${NC}"
echo ""
echo -e "${BLUE}📚 セットアップ完了:${NC}"
echo "- CLAUDE.md: Claude Code用の開発ガイド"
echo "- DEVELOPMENT_GUIDE.md: 開発者向けガイド"
echo "- DEVELOPMENT_CHECKLIST.md: TDDチェックリスト"
echo "- README.md: プロジェクトの説明"
echo "- .gitignore: Git除外設定"
echo "- scripts/worktree.sh: Git Worktree管理"
echo ""
echo -e "${GREEN}🚀 Claude Codeで開発を始められます！${NC}"
echo ""
echo -e "${BLUE}📋 次のステップ:${NC}"
echo "1. CLAUDE.md と README.md をプロジェクトに合わせてカスタマイズ"
echo "2. 技術スタックが決まったら Stage 2 を実行:"
echo "   ${TEMPLATE_DIR}/scripts/init-stage2.sh"
echo ""

# 通知音を鳴らす（macOSの場合）
if command -v play >/dev/null 2>&1; then
    play /System/Library/Sounds/Glass.aiff vol 2 >/dev/null 2>&1 || true
elif [ -f /System/Library/Sounds/Glass.aiff ]; then
    afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 || true
fi