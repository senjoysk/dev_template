#!/bin/bash

# ファイルサイズ監視スクリプト（汎用版）
# 巨大ファイルを検出し、分割を促す

set -e

echo "🔍 ファイルサイズチェックを開始します..."

# 設定: 閾値定義（プロジェクトに応じて調整可能）
MAX_FILE_SIZE=${MAX_FILE_SIZE:-100}      # KB単位（デフォルト100KB）
WARNING_SIZE=${WARNING_SIZE:-50}         # 警告サイズ（KB単位）

# 色付きログ用の定数
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 違反カウンター
violation_count=0
warning_count=0

# ヘルパー関数: ファイルサイズチェック
check_file_size() {
    local file="$1"
    local size_kb=$(du -k "$file" | cut -f1)
    
    if [ "$size_kb" -gt "$MAX_FILE_SIZE" ]; then
        echo -e "${RED}❌ ファイルサイズ超過:${NC} $file (${size_kb}KB > ${MAX_FILE_SIZE}KB)"
        echo -e "   ${YELLOW}対策:${NC} ファイルを機能ごとに分割してください"
        return 1
    elif [ "$size_kb" -gt "$WARNING_SIZE" ]; then
        echo -e "${YELLOW}⚠️  ファイルサイズ警告:${NC} $file (${size_kb}KB > ${WARNING_SIZE}KB)"
        echo -e "   ${BLUE}推奨:${NC} 今後の拡張を考慮して分割を検討してください"
        warning_count=$((warning_count + 1))
    else
        echo -e "${GREEN}✅ OK:${NC} $file (${size_kb}KB)"
    fi
    return 0
}

# 現在のコミット対象ファイルを取得
if [ -n "$(git diff --cached --name-only 2>/dev/null)" ]; then
    # コミット対象ファイルがある場合
    files_to_check=$(git diff --cached --name-only | grep -E '\.(ts|js|tsx|jsx|py|go|java|kt|rb|php|cs|cpp|c|h|hpp)$' | grep -v node_modules | grep -v dist || echo "")
else
    # 初回コミットなど、コミット対象ファイルがない場合は全ファイルをチェック
    files_to_check=$(find . -type f \( -name "*.ts" -o -name "*.js" -o -name "*.tsx" -o -name "*.jsx" -o -name "*.py" -o -name "*.go" -o -name "*.java" -o -name "*.kt" -o -name "*.rb" -o -name "*.php" -o -name "*.cs" -o -name "*.cpp" -o -name "*.c" -o -name "*.h" -o -name "*.hpp" \) | grep -v node_modules | grep -v dist | grep -v ".git")
fi

if [ -z "$files_to_check" ]; then
    echo -e "${GREEN}✅ チェック対象のソースファイルがありません${NC}"
    exit 0
fi

echo -e "${BLUE}📋 チェック対象ファイル数:${NC} $(echo "$files_to_check" | wc -l)"
echo -e "${BLUE}📏 サイズ上限:${NC} ${MAX_FILE_SIZE}KB (警告: ${WARNING_SIZE}KB)"
echo ""

# 各ファイルをチェック
for file in $files_to_check; do
    if [ -f "$file" ]; then
        if ! check_file_size "$file"; then
            violation_count=$((violation_count + 1))
        fi
    fi
done

# 結果レポート
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}📊 ファイルサイズチェック結果${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$violation_count" -eq 0 ]; then
    if [ "$warning_count" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  $warning_count 件の警告があります${NC}"
        echo -e "${BLUE}💡 ヒント:${NC} 大きくなりつつあるファイルは早めの分割を検討してください"
    else
        echo -e "${GREEN}✅ 全ファイルが適切なサイズです${NC}"
    fi
    exit 0
else
    echo -e "${RED}❌ $violation_count 件のファイルサイズ違反が検出されました${NC}"
    echo ""
    echo -e "${YELLOW}🛠️  対策手順:${NC}"
    echo "1. 機能ごとにファイルを分割"
    echo "2. 共通部分を別ファイルに抽出"
    echo "3. 大きなデータは外部ファイルに移動"
    echo ""
    echo -e "${BLUE}💡 分割の指針:${NC}"
    echo "- 1ファイル1機能の原則"
    echo "- 関連する機能はディレクトリでグループ化"
    echo "- 共通ユーティリティは utils/ や common/ に配置"
    echo ""
    echo -e "${BLUE}💡 設定カスタマイズ:${NC}"
    echo "export MAX_FILE_SIZE=150  # サイズ上限を150KBに変更"
    echo "export WARNING_SIZE=75    # 警告サイズを75KBに変更"
    echo ""
    exit 1
fi