#!/bin/bash

# Claude Code開発テンプレート Stage 2 初期化スクリプト
# 技術スタック自動検出と固有設定の適用

# テストモードでsourceされた場合は関数定義のみを読み込む
if [ -n "$SOURCING_FOR_TEST" ]; then
    # 関数定義のみを読み込み、メイン処理をスキップ
    SKIP_MAIN=1
fi

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

# 実行結果を追跡する配列
ADDED_FILES=()
SKIPPED_FILES=()
SKIPPED_DIFFS=()  # スキップされたファイルの差分情報

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
    
    # Ruby検出
    elif [ -f "Gemfile" ]; then
        stack="ruby"
    
    # その他
    else
        stack="generic"
    fi
    
    echo "$stack"
}

# メイン処理を実行する関数
main() {
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

# 差分情報を取得する関数
get_diff_summary() {
    local file1="$1"
    local file2="$2"
    
    if [ ! -f "$file1" ] || [ ! -f "$file2" ]; then
        echo "差分計算不可"
        return
    fi
    
    # 差分の行数をカウント
    local diff_output=$(diff -u "$file1" "$file2" 2>/dev/null || true)
    local added_lines=$(echo "$diff_output" | grep -c '^+[^+]' || true)
    local removed_lines=$(echo "$diff_output" | grep -c '^-[^-]' || true)
    
    if [ $added_lines -eq 0 ] && [ $removed_lines -eq 0 ]; then
        echo "差分なし"
    else
        echo "+${added_lines}行/-${removed_lines}行"
    fi
}

# 主要な差分を表示する関数
show_diff_preview() {
    local existing="$1"
    local template="$2"
    
    # 差分の最初の数行を表示
    local diff_preview=$(diff -u "$existing" "$template" 2>/dev/null | grep -E '^[+-][^+-]' | head -5 || true)
    
    if [ -n "$diff_preview" ]; then
        echo -e "    ${BLUE}📊 差分プレビュー:${NC}"
        echo "$diff_preview" | while IFS= read -r line; do
            if [[ $line == +* ]]; then
                echo -e "    ${GREEN}$line${NC}"
            elif [[ $line == -* ]]; then
                echo -e "    ${RED}$line${NC}"
            fi
        done
        echo "    ..."
    fi
}

# ファイルをコピーする関数
copy_file() {
    local src="$1"
    local dest="$2"
    
    # 既存ファイルチェック
    if [ -f "$dest" ]; then
        echo -e "${YELLOW}⚠️  スキップ: $dest (既存ファイル)${NC}"
        SKIPPED_FILES+=("$dest")
        
        # 差分情報を取得
        local diff_summary=$(get_diff_summary "$dest" "$src")
        SKIPPED_DIFFS+=("$dest|$diff_summary")
        
        # 差分プレビューを表示
        show_diff_preview "$dest" "$src"
        
        return
    fi
    
    # ディレクトリ作成
    mkdir -p "$(dirname "$dest")"
    
    # ファイルコピー
    echo -e "${GREEN}✅ 作成: $dest${NC}"
    cp "$src" "$dest"
    ADDED_FILES+=("$dest")
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
                ADDED_FILES+=(".husky/pre-commit")
            else
                echo -e "${YELLOW}⚠️  スキップ: .husky/pre-commit (既存ファイル)${NC}"
                SKIPPED_FILES+=(".husky/pre-commit")
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
esac

# CLAUDE.mdとDEVELOPMENT_GUIDE.mdの更新案内
echo ""
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}📊 実行結果サマリー${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ${#ADDED_FILES[@]} -gt 0 ]; then
    echo -e "${GREEN}✅ 追加されたファイル (${#ADDED_FILES[@]}件):${NC}"
    for file in "${ADDED_FILES[@]}"; do
        echo "   - $file"
    done
fi

if [ ${#SKIPPED_FILES[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}⚠️  スキップされたファイル (${#SKIPPED_FILES[@]}件):${NC}"
    for i in "${!SKIPPED_FILES[@]}"; do
        local file="${SKIPPED_FILES[$i]}"
        # 対応する差分情報を探す
        local diff_info="差分情報なし"
        for diff_entry in "${SKIPPED_DIFFS[@]}"; do
            if [[ "$diff_entry" == "$file|"* ]]; then
                diff_info="${diff_entry#*|}"
                break
            fi
        done
        echo "   - $file (既存ファイル) [$diff_info]"
    done
fi

if [ ${#ADDED_FILES[@]} -eq 0 ] && [ ${#SKIPPED_FILES[@]} -gt 0 ]; then
    echo ""
    echo -e "${BLUE}ℹ️  すべてのファイルが既に存在するためスキップされました。${NC}"
    echo "   プロジェクトは既に Stage 2 セットアップ済みのようです。"
fi

echo ""
if [ ${#ADDED_FILES[@]} -gt 0 ]; then
    echo -e "${GREEN}✅ Stage 2 の適用が完了しました！${NC}"
    echo ""
    echo -e "${BLUE}📚 セットアップ内容:${NC}"
    echo "- scripts/code-review/: コード品質チェック"
    echo "- scripts/test-analysis/: テスト分析スクリプト"
    
    if [ "$TECH_STACK" = "node-typescript" ] || [ "$TECH_STACK" = "node-javascript" ] || [ "$TECH_STACK" = "react" ]; then
        echo "- .husky/pre-commit: Git pre-commitフック"
        echo "- .nvmrc: Node.jsバージョン管理"
    fi
    
    echo ""
    echo -e "${GREEN}🚀 技術スタックに最適化された環境で開発を続けられます！${NC}"
fi

echo ""
echo -e "${BLUE}📋 次のステップ:${NC}"
echo "1. CLAUDE.md に技術スタック固有の情報を追加"
echo "2. npm/pip/go mod 等で必要な依存関係をインストール"
echo "3. TDDサイクルで開発を開始"
echo ""

# 差分を保存する関数
save_diffs_for_review() {
    if [ ${#SKIPPED_FILES[@]} -eq 0 ]; then
        return
    fi
    
    local diff_dir=".template_updates_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$diff_dir"
    
    echo ""
    echo -e "${BLUE}📁 差分を保存中...${NC}"
    
    for file in "${SKIPPED_FILES[@]}"; do
        # stage2のファイルを探す
        local src_file=""
        local stage=""
        
        # 次のパスを順番に確認
        if [ -f "$TEMPLATE_DIR/stage2/node-typescript/$file" ]; then
            src_file="$TEMPLATE_DIR/stage2/node-typescript/$file"
            stage="stage2/node-typescript"
        elif [ -f "$TEMPLATE_DIR/stage2/python/$file" ]; then
            src_file="$TEMPLATE_DIR/stage2/python/$file"
            stage="stage2/python"
        elif [ -f "$TEMPLATE_DIR/scripts/code-review/$(basename "$file")" ] && [[ "$file" == scripts/code-review/* ]]; then
            src_file="$TEMPLATE_DIR/scripts/code-review/$(basename "$file")"
            stage="scripts/code-review"
        elif [ -f "$TEMPLATE_DIR/scripts/test-analysis/$(basename "$file")" ] && [[ "$file" == scripts/test-analysis/* ]]; then
            # 技術スタックに応じたファイルを確認
            case "$TECH_STACK" in
                node-typescript|node-javascript|react)
                    src_file="$TEMPLATE_DIR/scripts/test-analysis/node.sh"
                    ;;
                python)
                    src_file="$TEMPLATE_DIR/scripts/test-analysis/python.sh"
                    ;;
                *)
                    src_file="$TEMPLATE_DIR/scripts/test-analysis/test-analysis-template.sh"
                    ;;
            esac
            stage="scripts/test-analysis"
        fi
        
        if [ -f "$src_file" ]; then
            # ディレクトリ構造を維持
            mkdir -p "$diff_dir/$(dirname "$file")"
            
            # 新バージョンを保存
            cp "$src_file" "$diff_dir/${file}.new"
            
            # 差分を保存
            diff -u "$file" "$diff_dir/${file}.new" > "$diff_dir/${file}.diff" 2>/dev/null || true
        fi
    done
    
    # レポートを生成
    cat > "$diff_dir/UPDATE_REPORT.md" << EOF
# テンプレート更新レポート (Stage 2)

生成日時: $(date)
プロジェクト: $PROJECT_NAME
技術スタック: $TECH_STACK

## サマリー
- 追加されたファイル: ${#ADDED_FILES[@]}件
- スキップされたファイル: ${#SKIPPED_FILES[@]}件

## スキップされたファイルの詳細

EOF
    
    for i in "${!SKIPPED_FILES[@]}"; do
        local file="${SKIPPED_FILES[$i]}"
        local diff_info="差分情報なし"
        for diff_entry in "${SKIPPED_DIFFS[@]}"; do
            if [[ "$diff_entry" == "$file|"* ]]; then
                diff_info="${diff_entry#*|}"
                break
            fi
        done
        
        echo "### $file" >> "$diff_dir/UPDATE_REPORT.md"
        echo "**差分サイズ**: $diff_info" >> "$diff_dir/UPDATE_REPORT.md"
        echo "" >> "$diff_dir/UPDATE_REPORT.md"
        
        if [ -f "$diff_dir/${file}.diff" ] && [ -s "$diff_dir/${file}.diff" ]; then
            echo '```diff' >> "$diff_dir/UPDATE_REPORT.md"
            head -20 "$diff_dir/${file}.diff" >> "$diff_dir/UPDATE_REPORT.md"
            local diff_lines=$(wc -l < "$diff_dir/${file}.diff")
            if [ $diff_lines -gt 20 ]; then
                echo "... (残り $((diff_lines - 20))行)" >> "$diff_dir/UPDATE_REPORT.md"
            fi
            echo '```' >> "$diff_dir/UPDATE_REPORT.md"
        else
            echo "差分なし" >> "$diff_dir/UPDATE_REPORT.md"
        fi
        echo "" >> "$diff_dir/UPDATE_REPORT.md"
    done
    
    echo "" >> "$diff_dir/UPDATE_REPORT.md"
    echo "## 手動マージの方法" >> "$diff_dir/UPDATE_REPORT.md"
    echo "" >> "$diff_dir/UPDATE_REPORT.md"
    echo '```bash' >> "$diff_dir/UPDATE_REPORT.md"
    echo "# 差分を確認" >> "$diff_dir/UPDATE_REPORT.md"
    echo "cat $diff_dir/ファイル名.diff" >> "$diff_dir/UPDATE_REPORT.md"
    echo "" >> "$diff_dir/UPDATE_REPORT.md"
    echo "# マージツールで比較" >> "$diff_dir/UPDATE_REPORT.md"
    echo "vimdiff ファイル名 $diff_dir/ファイル名.new" >> "$diff_dir/UPDATE_REPORT.md"
    echo '```' >> "$diff_dir/UPDATE_REPORT.md"
    
    echo -e "${GREEN}✅ 差分情報を保存しました: $diff_dir/${NC}"
    echo -e "   ${BLUE}📄 レポート: $diff_dir/UPDATE_REPORT.md${NC}"
    echo -e "   ${BLUE}📁 新バージョン: $diff_dir/*.new${NC}"
    echo -e "   ${BLUE}📊 差分ファイル: $diff_dir/*.diff${NC}"
}

    # 実行結果サマリーの前に差分保存を実行
    save_diffs_for_review

    echo -e "${BLUE}📋 CLAUDE.md と DEVELOPMENT_GUIDE.md の更新について${NC}"
    echo "技術スタック固有の情報を追加することをお勧めします:"
    echo "- ビルドコマンド"
    echo "- テストコマンド"
    echo "- 依存関係のインストール方法"
    echo "- デプロイ手順（該当する場合）"
    if [ ${#SKIPPED_FILES[@]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}💡 スキップされたファイルの差分を確認:${NC}"
        echo "   最新の .template_updates_* ディレクトリを参照"
    fi
    echo ""
}

# テストモードでない場合のみメイン処理を実行
if [ -z "$SKIP_MAIN" ]; then
    main
fi