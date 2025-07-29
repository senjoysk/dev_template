#!/bin/bash

# Claude Code開発テンプレート初期化スクリプト
# プロジェクトの技術スタックを検出し、適切なテンプレートを適用

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# 色付きログ用の定数
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# デフォルト設定
PROJECT_NAME=$(basename "$PWD")
UPDATE_MODE=false
FORCE_STACK=""

# 使い方を表示
show_usage() {
    echo "使い方: $0 [オプション]"
    echo ""
    echo "オプション:"
    echo "  --update          既存プロジェクトを更新（既存ファイルは上書きしない）"
    echo "  --stack=STACK     技術スタックを指定（auto-detect をスキップ）"
    echo "                    STACK: node-typescript, python, go, react"
    echo "  --help            このヘルプを表示"
    echo ""
    echo "例:"
    echo "  $0                           # 新規プロジェクトで自動検出"
    echo "  $0 --stack=node-typescript   # Node.js + TypeScript を強制"
    echo "  $0 --update                  # 既存プロジェクトを更新"
}

# オプション解析
while [[ $# -gt 0 ]]; do
    case $1 in
        --update)
            UPDATE_MODE=true
            shift
            ;;
        --stack=*)
            FORCE_STACK="${1#*=}"
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}❌ 不明なオプション: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🚀 Claude Code開発テンプレート初期化${NC}"
echo -e "${BLUE}📁 プロジェクト: ${PROJECT_NAME}${NC}"
echo ""

# 技術スタック検出関数
detect_tech_stack() {
    local stack=""
    
    # Node.js/TypeScript検出
    if [ -f "package.json" ]; then
        if [ -f "tsconfig.json" ]; then
            stack="node-typescript"
        else
            stack="node-javascript"
        fi
        
        # React検出
        if grep -q '"react"' package.json 2>/dev/null; then
            stack="react"
        fi
    
    # Python検出
    elif [ -f "requirements.txt" ] || [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
        stack="python"
    
    # Go検出
    elif [ -f "go.mod" ]; then
        stack="go"
    
    # Ruby検出
    elif [ -f "Gemfile" ]; then
        stack="ruby"
    
    # その他
    else
        stack="generic"
    fi
    
    echo "$stack"
}

# 技術スタック決定
if [ -n "$FORCE_STACK" ]; then
    TECH_STACK="$FORCE_STACK"
    echo -e "${BLUE}📦 技術スタック（指定）: ${TECH_STACK}${NC}"
else
    TECH_STACK=$(detect_tech_stack)
    echo -e "${BLUE}📦 技術スタック（検出）: ${TECH_STACK}${NC}"
fi

# テンプレート変数の設定
case "$TECH_STACK" in
    node-typescript)
        PRIMARY_LANGUAGE="typescript"
        BUILD_COMMAND="npm run build"
        TEST_COMMAND="npm test"
        TEST_COMMAND_WATCH="npm run test:watch"
        INSTALL_COMMAND="npm install"
        TEST_ANALYSIS_SCRIPT="./scripts/test-analysis/node.sh"
        USE_NVM=true
        ;;
    node-javascript)
        PRIMARY_LANGUAGE="javascript"
        BUILD_COMMAND="npm run build"
        TEST_COMMAND="npm test"
        TEST_COMMAND_WATCH="npm run test:watch"
        INSTALL_COMMAND="npm install"
        TEST_ANALYSIS_SCRIPT="./scripts/test-analysis/node.sh"
        USE_NVM=true
        ;;
    python)
        PRIMARY_LANGUAGE="python"
        BUILD_COMMAND="python -m py_compile ."
        TEST_COMMAND="pytest"
        TEST_COMMAND_WATCH="pytest-watch"
        INSTALL_COMMAND="pip install -r requirements.txt"
        TEST_ANALYSIS_SCRIPT="./scripts/test-analysis/python.sh"
        USE_NVM=false
        ;;
    go)
        PRIMARY_LANGUAGE="go"
        BUILD_COMMAND="go build ./..."
        TEST_COMMAND="go test ./..."
        TEST_COMMAND_WATCH="watch -n 2 go test ./..."
        INSTALL_COMMAND="go mod download"
        TEST_ANALYSIS_SCRIPT="./scripts/test-analysis/go.sh"
        USE_NVM=false
        ;;
    react)
        PRIMARY_LANGUAGE="typescript"
        BUILD_COMMAND="npm run build"
        TEST_COMMAND="npm test"
        TEST_COMMAND_WATCH="npm run test:watch"
        INSTALL_COMMAND="npm install"
        TEST_ANALYSIS_SCRIPT="./scripts/test-analysis/node.sh"
        USE_NVM=true
        ;;
    *)
        PRIMARY_LANGUAGE="generic"
        BUILD_COMMAND="make build"
        TEST_COMMAND="make test"
        TEST_COMMAND_WATCH="make test-watch"
        INSTALL_COMMAND="make install"
        TEST_ANALYSIS_SCRIPT="./scripts/test-analysis/generic.sh"
        USE_NVM=false
        ;;
esac

# ファイルをコピーする関数（テンプレート変数を置換）
copy_and_process_template() {
    local src="$1"
    local dest="$2"
    
    # 既存ファイルチェック
    if [ -f "$dest" ] && [ "$UPDATE_MODE" = true ]; then
        echo -e "${YELLOW}⚠️  スキップ: $dest (既存ファイル)${NC}"
        return
    fi
    
    # ディレクトリ作成
    mkdir -p "$(dirname "$dest")"
    
    # テンプレート処理
    echo -e "${GREEN}✅ 作成: $dest${NC}"
    
    # 基本的な変数置換
    sed -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
        -e "s|{{PROJECT_DIR}}|$(basename "$PWD")|g" \
        -e "s|{{TECH_STACK}}|$TECH_STACK|g" \
        -e "s|{{PRIMARY_LANGUAGE}}|$PRIMARY_LANGUAGE|g" \
        -e "s|{{BUILD_COMMAND}}|$BUILD_COMMAND|g" \
        -e "s|{{TEST_COMMAND}}|$TEST_COMMAND|g" \
        -e "s|{{TEST_COMMAND_WATCH}}|$TEST_COMMAND_WATCH|g" \
        -e "s|{{INSTALL_COMMAND}}|$INSTALL_COMMAND|g" \
        -e "s|{{TEST_ANALYSIS_SCRIPT}}|$TEST_ANALYSIS_SCRIPT|g" \
        -e "s|{{USE_NVM}}|$USE_NVM|g" \
        "$src" > "$dest"
    
    # 条件付きセクションの処理（簡易版）
    if [ "$USE_NVM" = false ]; then
        # {{#if USE_NVM}} ... {{/if}} ブロックを削除
        sed -i.bak '/{{#if USE_NVM}}/,/{{\/if}}/d' "$dest" && rm -f "$dest.bak"
    fi
    
    # 残りのプレースホルダーをクリーンアップ
    sed -i.bak 's/{{#if.*}}//g; s/{{\/if}}//g' "$dest" && rm -f "$dest.bak"
}

echo ""
echo -e "${BLUE}📋 テンプレートを適用中...${NC}"

# CLAUDE.mdの作成
copy_and_process_template "$SCRIPT_DIR/CLAUDE.md.template" "CLAUDE.md"

# DEVELOPMENT_GUIDE.mdの作成
copy_and_process_template "$SCRIPT_DIR/docs/DEVELOPMENT_GUIDE.md.template" "docs/DEVELOPMENT_GUIDE.md"

# スクリプトのコピー
echo -e "${BLUE}📋 スクリプトをコピー中...${NC}"

# ディレクトリ作成
mkdir -p scripts/{test-analysis,code-review}
mkdir -p .husky

# テスト分析スクリプト
if [ -f "$SCRIPT_DIR/scripts/test-analysis/${TECH_STACK%%-*}.sh" ]; then
    cp "$SCRIPT_DIR/scripts/test-analysis/${TECH_STACK%%-*}.sh" "scripts/test-analysis/test-analysis.sh"
else
    cp "$SCRIPT_DIR/scripts/test-analysis/node.sh" "scripts/test-analysis/test-analysis.sh"
fi
chmod +x scripts/test-analysis/test-analysis.sh

# コード品質チェックスクリプト
cp "$SCRIPT_DIR/scripts/code-review/srp-check.sh" "scripts/code-review/"
cp "$SCRIPT_DIR/scripts/code-review/file-size-check.sh" "scripts/code-review/"
chmod +x scripts/code-review/*.sh

# worktree.shスクリプト
cp "$SCRIPT_DIR/scripts/worktree.sh" "scripts/"
chmod +x scripts/worktree.sh

# Huskyのセットアップ
if [ "$TECH_STACK" = "node-typescript" ] || [ "$TECH_STACK" = "node-javascript" ] || [ "$TECH_STACK" = "react" ]; then
    echo -e "${BLUE}📋 Huskyをセットアップ中...${NC}"
    
    # package.jsonが存在する場合のみ
    if [ -f "package.json" ]; then
        # Huskyをインストール
        if ! grep -q '"husky"' package.json; then
            npm install --save-dev husky
        fi
        
        # Huskyを初期化
        npx husky install
        
        # pre-commitフックを作成
        copy_and_process_template "$SCRIPT_DIR/.husky/pre-commit.template" ".husky/pre-commit"
        chmod +x .husky/pre-commit
    fi
else
    echo -e "${YELLOW}⚠️  Husky設定はNode.jsプロジェクトでのみ利用可能です${NC}"
    echo -e "${BLUE}💡 他の言語では、.git/hooks/pre-commit を手動で設定してください${NC}"
fi

# 技術スタック別の追加ファイル
if [ -d "$SCRIPT_DIR/templates/$TECH_STACK" ]; then
    echo -e "${BLUE}📋 技術スタック固有のテンプレートを適用中...${NC}"
    cp -r "$SCRIPT_DIR/templates/$TECH_STACK"/. .
fi

echo ""
echo -e "${GREEN}✅ テンプレートの適用が完了しました！${NC}"
echo ""
echo -e "${BLUE}📚 次のステップ:${NC}"
echo "1. CLAUDE.md を確認・カスタマイズ"
echo "2. docs/DEVELOPMENT_GUIDE.md を確認・カスタマイズ"
echo "3. 必要に応じて scripts/ 内のスクリプトを調整"

if [ "$TECH_STACK" = "node-typescript" ] || [ "$TECH_STACK" = "node-javascript" ] || [ "$TECH_STACK" = "react" ]; then
    echo "4. npm install を実行して依存関係をインストール"
fi

echo ""
echo -e "${GREEN}🚀 Claude Codeで効率的な開発を始めましょう！${NC}"

# 通知音を鳴らす
if command -v play >/dev/null 2>&1; then
    play /System/Library/Sounds/Glass.aiff vol 2 >/dev/null 2>&1 || true
fi