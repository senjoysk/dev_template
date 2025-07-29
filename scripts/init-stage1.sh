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

# 実行結果を追跡する配列
ADDED_FILES=()
SKIPPED_FILES=()
SKIPPED_DIFFS=()  # スキップされたファイルの差分情報

echo -e "${BLUE}🚀 Claude Code開発テンプレート Stage 1 初期化${NC}"
echo -e "${BLUE}📁 プロジェクト: ${PROJECT_NAME}${NC}"
echo ""

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

# テンプレート処理関数
process_template() {
    local src="$1"
    local dest="$2"
    
    # 既存ファイルチェック
    if [ -f "$dest" ]; then
        echo -e "${YELLOW}⚠️  スキップ: $dest (既存ファイル)${NC}"
        SKIPPED_FILES+=("$dest")
        
        # テンプレートを一時的に処理して差分を確認
        local temp_file=$(mktemp)
        sed -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
            -e "s|{{PROJECT_DESCRIPTION}}|$PROJECT_NAME - Claude Codeで開発|g" \
            "$src" > "$temp_file"
        
        # 差分情報を取得
        local diff_summary=$(get_diff_summary "$dest" "$temp_file")
        SKIPPED_DIFFS+=("$dest|$diff_summary")
        
        # 差分プレビューを表示
        show_diff_preview "$dest" "$temp_file"
        
        rm -f "$temp_file"
        return
    fi
    
    # ディレクトリ作成
    mkdir -p "$(dirname "$dest")"
    
    # テンプレート処理
    echo -e "${GREEN}✅ 作成: $dest${NC}"
    sed -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
        -e "s|{{PROJECT_DESCRIPTION}}|$PROJECT_NAME - Claude Codeで開発|g" \
        "$src" > "$dest"
    ADDED_FILES+=("$dest")
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
    echo "   プロジェクトは既にセットアップ済みのようです。"
fi

echo ""
if [ ${#ADDED_FILES[@]} -gt 0 ]; then
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
fi

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
        local src_file="$TEMPLATE_DIR/stage1/$file"
        
        # テンプレートファイルの場合は特別処理
        if [[ "$file" == *.template ]] || [[ "$src_file" == *.template ]]; then
            src_file="${src_file%.template}.template"
        fi
        
        if [ -f "$src_file" ]; then
            # ディレクトリ構造を維持
            mkdir -p "$diff_dir/$(dirname "$file")"
            
            # 新バージョンを保存
            if [[ "$src_file" == *.template ]]; then
                # テンプレートを処理してから保存
                sed -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
                    -e "s|{{PROJECT_DESCRIPTION}}|$PROJECT_NAME - Claude Codeで開発|g" \
                    "$src_file" > "$diff_dir/${file}.new"
            else
                cp "$src_file" "$diff_dir/${file}.new"
            fi
            
            # 差分を保存
            diff -u "$file" "$diff_dir/${file}.new" > "$diff_dir/${file}.diff" 2>/dev/null || true
        fi
    done
    
    # レポートを生成
    cat > "$diff_dir/UPDATE_REPORT.md" << EOF
# テンプレート更新レポート

生成日時: $(date)
プロジェクト: $PROJECT_NAME

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

echo ""
echo -e "${BLUE}📋 次のステップ:${NC}"
echo "1. CLAUDE.md と README.md をプロジェクトに合わせてカスタマイズ"
echo "2. 技術スタックが決まったら Stage 2 を実行:"
echo "   ${TEMPLATE_DIR}/scripts/init-stage2.sh"
if [ ${#SKIPPED_FILES[@]} -gt 0 ]; then
    echo "3. スキップされたファイルの差分を確認:"
    echo "   最新の .template_updates_* ディレクトリを参照"
fi
echo ""

# 通知音を鳴らす（macOSの場合）
if command -v play >/dev/null 2>&1; then
    play /System/Library/Sounds/Glass.aiff vol 2 >/dev/null 2>&1 || true
elif [ -f /System/Library/Sounds/Glass.aiff ]; then
    afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 || true
fi