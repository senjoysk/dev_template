#!/bin/bash

# ファイルサイズ監視スクリプト（汎用版）
# 肥大化したファイルを検出し、開発効率と保守性の低下を防ぐ

set -e

echo "🔍 ファイルサイズチェックを開始します..."

# 設定: 行数閾値定義（プロジェクトに応じて調整可能）
LARGE_FILE_LINES=${LARGE_FILE_LINES:-800}        # 大型ファイル警告閾値
HUGE_FILE_LINES=${HUGE_FILE_LINES:-1500}         # 巨大ファイル阻止閾値
WARNING_FILE_LINES=${WARNING_FILE_LINES:-600}    # 警告ファイル閾値

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
    local lines=$(wc -l < "$file")
    
    if [ "$lines" -ge "$HUGE_FILE_LINES" ]; then
        echo -e "${RED}❌ 巨大ファイル:${NC} $file ($lines 行)"
        echo -e "   ${RED}緊急対応が必要です！${NC} 即座にファイル分割を実施してください"
        return 1
    elif [ "$lines" -ge "$LARGE_FILE_LINES" ]; then
        echo -e "${YELLOW}⚠️  大型ファイル:${NC} $file ($lines 行)"
        echo -e "   ${YELLOW}分割を検討してください${NC}"
        warning_count=$((warning_count + 1))
    elif [ "$lines" -ge "$WARNING_FILE_LINES" ]; then
        echo -e "${BLUE}📋 監視対象:${NC} $file ($lines 行)"
        echo -e "   ${BLUE}注意深く見守り中${NC} - 更なる肥大化を防止"
        warning_count=$((warning_count + 1))
    else
        echo -e "${GREEN}✅ 適切なサイズ:${NC} $file ($lines 行)"
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
echo -e "${BLUE}📏 行数閾値:${NC} 巨大: ${HUGE_FILE_LINES}行, 大型: ${LARGE_FILE_LINES}行, 警告: ${WARNING_FILE_LINES}行"
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
        echo -e "${GREEN}✅ 良好な保守性が保たれています${NC}"
    fi
    exit 0
else
    echo -e "${RED}❌ $violation_count 件の巨大ファイルが検出されました${NC}"
    echo ""
    echo -e "${YELLOW}🛠️  対策手順:${NC}"
    echo "1. 機能ごとにファイルを分割"
    echo "2. 共通部分を別ファイルに抽出"
    echo "3. 責務を明確にして再構成"
    echo ""
    echo -e "${BLUE}💡 分割の指針:${NC}"
    echo "- 1ファイル1機能の原則"
    echo "- 関連する機能はディレクトリでグループ化"
    echo "- 共通ユーティリティは utils/ や common/ に配置"
    echo ""
    echo -e "${BLUE}💡 設定カスタマイズ:${NC}"
    echo "export LARGE_FILE_LINES=1000    # 大型ファイル警告を1000行に変更"
    echo "export HUGE_FILE_LINES=2000     # 巨大ファイル阻止を2000行に変更"
    echo "export WARNING_FILE_LINES=800   # 警告閾値を800行に変更"
    echo ""
    exit 1
fi