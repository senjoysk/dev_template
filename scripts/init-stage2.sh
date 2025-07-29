#!/bin/bash

# Claude Code開発テンプレート Stage 2 初期化スクリプト
# 技術スタック自動検出と固有設定の適用

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

# デフォルト設定
PROJECT_NAME=$(basename "$PWD")
FORCE_STACK=""

# 使い方を表示
show_usage() {
    echo "使い方: $0 [オプション]"
    echo ""
    echo "オプション:"
    echo "  --stack=STACK     技術スタックを指定（auto-detect をスキップ）"
    echo "                    STACK: node-typescript, python, go, react"
    echo "  --help            このヘルプを表示"
    echo ""
    echo "例:"
    echo "  $0                           # 技術スタックを自動検出"
    echo "  $0 --stack=node-typescript   # Node.js + TypeScript を強制"
}

# オプション解析
while [[ $# -gt 0 ]]; do
    case $1 in
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

# 技術スタック検出関数（init.shから流用）
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

echo -e "${BLUE}🚀 Claude Code開発テンプレート Stage 2 初期化${NC}"
echo -e "${BLUE}📁 プロジェクト: ${PROJECT_NAME}${NC}"
echo ""

# 技術スタック決定
if [ -n "$FORCE_STACK" ]; then
    TECH_STACK="$FORCE_STACK"
    echo -e "${BLUE}📦 技術スタック（指定）: ${TECH_STACK}${NC}"
else
    TECH_STACK=$(detect_tech_stack)
    echo -e "${BLUE}📦 技術スタック（検出）: ${TECH_STACK}${NC}"
fi

# 技術スタックが検出できない場合
if [ "$TECH_STACK" = "generic" ]; then
    echo -e "${YELLOW}⚠️  技術スタックを検出できませんでした${NC}"
    echo -e "${YELLOW}以下のいずれかのファイルを作成後、再度実行してください:${NC}"
    echo "- package.json (Node.js)"
    echo "- requirements.txt (Python)"
    echo "- go.mod (Go)"
    echo "- Gemfile (Ruby)"
    echo ""
    echo -e "${BLUE}または、--stack オプションで指定してください${NC}"
    exit 1
fi

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

echo ""
echo -e "${BLUE}📋 Stage 2: 技術スタック固有の設定を適用中...${NC}"
echo ""

# スクリプトのコピー
echo -e "${BLUE}📋 共通スクリプトをコピー中...${NC}"

# コード品質チェックスクリプト
mkdir -p scripts/code-review
copy_file "$TEMPLATE_DIR/scripts/code-review/srp-check.sh" "scripts/code-review/srp-check.sh"
copy_file "$TEMPLATE_DIR/scripts/code-review/file-size-check.sh" "scripts/code-review/file-size-check.sh"
chmod +x scripts/code-review/*.sh

# テスト分析スクリプト
mkdir -p scripts/test-analysis
case "$TECH_STACK" in
    node-typescript|node-javascript|react)
        copy_file "$TEMPLATE_DIR/scripts/test-analysis/node.sh" "scripts/test-analysis/test-analysis.sh"
        ;;
    python)
        copy_file "$TEMPLATE_DIR/scripts/test-analysis/python.sh" "scripts/test-analysis/test-analysis.sh"
        ;;
    go)
        copy_file "$TEMPLATE_DIR/scripts/test-analysis/go.sh" "scripts/test-analysis/test-analysis.sh"
        ;;
    *)
        # 汎用テンプレートを使用
        copy_file "$TEMPLATE_DIR/scripts/test-analysis/test-analysis-template.sh" "scripts/test-analysis/test-analysis.sh"
        ;;
esac
chmod +x scripts/test-analysis/test-analysis.sh

# 技術スタック固有の設定
case "$TECH_STACK" in
    node-typescript|node-javascript|react)
        echo ""
        echo -e "${BLUE}📋 Node.js環境の設定中...${NC}"
        
        # .nvmrcのコピー
        if [ -f "$TEMPLATE_DIR/stage2/node-typescript/.nvmrc" ]; then
            copy_file "$TEMPLATE_DIR/stage2/node-typescript/.nvmrc" ".nvmrc"
        fi
        
        # Huskyのセットアップ
        if [ -f "package.json" ]; then
            echo -e "${BLUE}📋 Huskyをセットアップ中...${NC}"
            
            # Huskyをインストール
            if ! grep -q '"husky"' package.json; then
                echo -e "${GREEN}📦 Huskyをインストール中...${NC}"
                npm install --save-dev husky
            fi
            
            # Huskyを初期化
            if [ ! -d ".husky" ]; then
                npx husky install
            fi
            
            # pre-commitフックを作成
            if [ ! -f ".husky/pre-commit" ]; then
                npx husky add .husky/pre-commit "npm run build || echo 'No build script'"
                
                # pre-commitの内容を追加
                cat > .husky/pre-commit << 'EOF'
#!/bin/sh
. "$(dirname -- "$0")/_/husky.sh"

# ビルド確認（存在する場合）
if grep -q '"build"' package.json 2>/dev/null; then
    echo "🔨 Pre-commit check: ビルド確認..."
    npm run build
fi

# テスト実行と失敗分析
echo "🧪 Pre-commit check: テスト実行と失敗分析..."
if [ -f scripts/test-analysis/test-analysis.sh ]; then
    ./scripts/test-analysis/test-analysis.sh
else
    npm test || echo "⚠️  テストスクリプトが設定されていません"
fi

# SRP（単一責任原則）違反チェック
echo "🔍 Pre-commit check: SRP違反チェック..."
./scripts/code-review/srp-check.sh

if [ $? -ne 0 ]; then
    echo ""
    echo "🚨 コミットが阻止されました！"
    echo "🛠️ SRP（単一責任原則）違反が検出されました。"
    echo ""
    exit 1
fi

echo "✅ SRP違反チェック通過"

# ファイルサイズ監視チェック
echo "🔍 Pre-commit check: ファイルサイズ監視..."
./scripts/code-review/file-size-check.sh

if [ $? -ne 0 ]; then
    echo ""
    echo "🚨 コミットが阻止されました！"
    echo "🛠️ 巨大ファイルが検出されました。"
    echo ""
    exit 1
fi

echo "✅ ファイルサイズチェック通過"
echo "✅ すべての品質チェックが完了しました"
EOF
                chmod +x .husky/pre-commit
                echo -e "${GREEN}✅ Huskyのpre-commitフックを設定しました${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  package.jsonが見つかりません。Huskyの設定をスキップします${NC}"
        fi
        ;;
        
    python)
        echo ""
        echo -e "${BLUE}📋 Python環境の設定中...${NC}"
        
        # pre-commit設定ファイル
        if [ -f "$TEMPLATE_DIR/stage2/python/.pre-commit-config.yaml" ]; then
            copy_file "$TEMPLATE_DIR/stage2/python/.pre-commit-config.yaml" ".pre-commit-config.yaml"
            echo -e "${BLUE}💡 pre-commitを使用するには: pip install pre-commit && pre-commit install${NC}"
        fi
        ;;
        
    go)
        echo ""
        echo -e "${BLUE}📋 Go環境の設定中...${NC}"
        # Go固有の設定があればここに追加
        ;;
esac

# CLAUDE.mdとDEVELOPMENT_GUIDE.mdの更新案内
echo ""
echo -e "${BLUE}📋 CLAUDE.md と DEVELOPMENT_GUIDE.md の更新について${NC}"
echo "技術スタック固有の情報を追加することをお勧めします:"
echo "- ビルドコマンド"
echo "- テストコマンド"
echo "- 依存関係のインストール方法"
echo "- デプロイ手順（該当する場合）"

echo ""
echo -e "${GREEN}✅ Stage 2 の適用が完了しました！${NC}"
echo ""
echo -e "${BLUE}📚 追加されたもの:${NC}"
echo "- scripts/code-review/: コード品質チェック"
echo "- scripts/test-analysis/: テスト分析スクリプト"

if [ "$TECH_STACK" = "node-typescript" ] || [ "$TECH_STACK" = "node-javascript" ] || [ "$TECH_STACK" = "react" ]; then
    echo "- .husky/pre-commit: Git pre-commitフック"
    echo "- .nvmrc: Node.jsバージョン管理"
fi

echo ""
echo -e "${GREEN}🚀 技術スタックに最適化された環境で開発を続けられます！${NC}"
echo ""
echo -e "${BLUE}📋 次のステップ:${NC}"
echo "1. CLAUDE.md に技術スタック固有の情報を追加"
echo "2. npm/pip/go mod 等で必要な依存関係をインストール"
echo "3. TDDサイクルで開発を開始"
echo ""

# 通知音を鳴らす（macOSの場合）
if command -v play >/dev/null 2>&1; then
    play /System/Library/Sounds/Glass.aiff vol 2 >/dev/null 2>&1 || true
elif [ -f /System/Library/Sounds/Glass.aiff ]; then
    afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 || true
fi