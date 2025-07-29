#!/bin/bash

# SRP（単一責任原則）違反検出スクリプト（汎用版）
# ファイルの責務肥大化を自動検出し、コミット時に警告・阻止する

set -e

echo "🔍 SRP違反チェックを開始します..."

# 設定: 閾値定義（プロジェクトに応じて調整可能）
MAX_LINES=${MAX_LINES:-500}              # ファイル最大行数
MAX_METHODS=${MAX_METHODS:-20}           # クラス最大メソッド数
MAX_FUNCTIONS=${MAX_FUNCTIONS:-15}       # ファイル最大関数数
MAX_IMPORTS=${MAX_IMPORTS:-30}           # 最大import数（複雑度の指標）

# 色付きログ用の定数
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 違反カウンター
violation_count=0

# ヘルパー関数: 例外チェック
check_srp_exception() {
    local file="$1"
    if grep -q "@SRP-EXCEPTION\|// SRP-IGNORE\|# SRP-IGNORE" "$file" 2>/dev/null; then
        return 0  # 例外として許可
    fi
    return 1  # 例外なし
}

# ヘルパー関数: 行数チェック
check_file_lines() {
    local file="$1"
    local lines=$(wc -l < "$file")
    
    if [ "$lines" -gt "$MAX_LINES" ]; then
        if ! check_srp_exception "$file"; then
            echo -e "${RED}❌ ファイル行数超過:${NC} $file ($lines 行 > $MAX_LINES 行)"
            echo -e "   ${YELLOW}対策:${NC} ファイルを責務ごとに分割してください"
            return 1
        else
            echo -e "${YELLOW}⚠️  例外許可:${NC} $file ($lines 行) - @SRP-EXCEPTION により許可"
        fi
    fi
    return 0
}

# ヘルパー関数: メソッド/関数数チェック（言語別）
check_method_count() {
    local file="$1"
    local count=0
    
    # ファイル拡張子による言語判定
    case "$file" in
        *.ts|*.js|*.tsx|*.jsx)
            # TypeScript/JavaScript: クラスメソッドと関数
            count=$(grep -cE "^\s*(public|private|protected|static|async)?\s*\w+\s*\(" "$file" 2>/dev/null || echo "0")
            ;;
        *.py)
            # Python: def文のカウント
            count=$(grep -c "^\s*def\s" "$file" 2>/dev/null || echo "0")
            ;;
        *.go)
            # Go: func宣言のカウント
            count=$(grep -c "^func\s" "$file" 2>/dev/null || echo "0")
            ;;
        *.java|*.kt)
            # Java/Kotlin: メソッド宣言
            count=$(grep -cE "^\s*(public|private|protected|static)?\s+\w+\s+\w+\s*\(" "$file" 2>/dev/null || echo "0")
            ;;
        *)
            return 0  # 未対応の言語はスキップ
            ;;
    esac
    
    local threshold=$MAX_METHODS
    [ "${file##*.}" = "go" ] && threshold=$MAX_FUNCTIONS  # Goは関数数で判定
    
    if [ "$count" -gt "$threshold" ]; then
        if ! check_srp_exception "$file"; then
            echo -e "${RED}❌ メソッド/関数数超過:${NC} $file ($count 個 > $threshold 個)"
            echo -e "   ${YELLOW}対策:${NC} クラス/ファイルを責務ごとに分割してください"
            return 1
        else
            echo -e "${YELLOW}⚠️  例外許可:${NC} $file ($count 個) - @SRP-EXCEPTION により許可"
        fi
    fi
    return 0
}

# ヘルパー関数: import/require数チェック（複雑度の指標）
check_import_count() {
    local file="$1"
    local import_count=0
    
    # ファイル拡張子による言語判定
    case "$file" in
        *.ts|*.js|*.tsx|*.jsx)
            # TypeScript/JavaScript: import文
            import_count=$(grep -c "^import\|^const.*=.*require" "$file" 2>/dev/null || echo "0")
            ;;
        *.py)
            # Python: import文
            import_count=$(grep -c "^import\|^from.*import" "$file" 2>/dev/null || echo "0")
            ;;
        *.go)
            # Go: import文（複数行対応）
            import_count=$(awk '/^import \(/{flag=1} flag && /^\)/{print NR-start; flag=0} flag && /^[[:space:]]*"/{count++} !flag && /^import/{count++} END{print count+0}' "$file" 2>/dev/null | tail -1)
            ;;
        *.java|*.kt)
            # Java/Kotlin: import文
            import_count=$(grep -c "^import\s" "$file" 2>/dev/null || echo "0")
            ;;
        *)
            return 0  # 未対応の言語はスキップ
            ;;
    esac
    
    if [ "$import_count" -gt "$MAX_IMPORTS" ]; then
        if ! check_srp_exception "$file"; then
            echo -e "${YELLOW}⚠️  import数多数:${NC} $file ($import_count imports > $MAX_IMPORTS imports)"
            echo -e "   ${BLUE}情報:${NC} 複雑度が高い可能性があります。分割を検討してください"
            # import数はwarningのみで、違反カウンターは増やさない
        fi
    fi
    return 0
}

# メインチェック関数
check_file() {
    local file="$1"
    local file_violations=0
    
    echo -e "${BLUE}📄 チェック中:${NC} $file"
    
    if ! check_file_lines "$file"; then
        file_violations=$((file_violations + 1))
    fi
    
    if ! check_method_count "$file"; then
        file_violations=$((file_violations + 1))
    fi
    
    check_import_count "$file"  # warningのみなので違反カウントには含めない
    
    if [ "$file_violations" -eq 0 ]; then
        echo -e "${GREEN}✅ OK${NC}"
    fi
    
    return $file_violations
}

# 現在のコミット対象ファイルを取得
if [ -n "$(git diff --cached --name-only 2>/dev/null)" ]; then
    # コミット対象ファイルがある場合
    files_to_check=$(git diff --cached --name-only | grep -E '\.(ts|js|tsx|jsx|py|go|java|kt)$' | grep -v node_modules | grep -v dist || echo "")
else
    # 初回コミットなど、コミット対象ファイルがない場合は全ファイルをチェック
    files_to_check=$(find . -type f \( -name "*.ts" -o -name "*.js" -o -name "*.tsx" -o -name "*.jsx" -o -name "*.py" -o -name "*.go" -o -name "*.java" -o -name "*.kt" \) | grep -v node_modules | grep -v dist | grep -v ".git")
fi

if [ -z "$files_to_check" ]; then
    echo -e "${GREEN}✅ チェック対象のソースファイルがありません${NC}"
    exit 0
fi

echo -e "${BLUE}📋 チェック対象ファイル数:${NC} $(echo "$files_to_check" | wc -l)"
echo ""

# 各ファイルをチェック
for file in $files_to_check; do
    if [ -f "$file" ]; then
        if ! check_file "$file"; then
            violation_count=$((violation_count + 1))
        fi
        echo ""
    fi
done

# 結果レポート
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}📊 SRP違反チェック結果${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$violation_count" -eq 0 ]; then
    echo -e "${GREEN}✅ SRP違反は検出されませんでした${NC}"
    echo -e "${GREEN}✅ 全ファイルが単一責任原則を遵守しています${NC}"
    exit 0
else
    echo -e "${RED}❌ $violation_count 件のSRP違反が検出されました${NC}"
    echo ""
    echo -e "${YELLOW}🛠️  対策手順:${NC}"
    echo "1. 違反ファイルを責務ごとに分割"
    echo "2. 一時的に継続する場合は @SRP-EXCEPTION コメントを追加"
    echo "3. 例外理由を @SRP-REASON で説明"
    echo ""
    echo -e "${BLUE}💡 例外指定例:${NC}"
    echo "// @SRP-EXCEPTION: 統合リポジトリとして複数インターフェース実装が必要"
    echo "// @SRP-REASON: 既存システムとの互換性維持のため段階的分割中"
    echo ""
    echo -e "${BLUE}💡 設定カスタマイズ:${NC}"
    echo "export MAX_LINES=800      # 行数上限を変更"
    echo "export MAX_METHODS=30     # メソッド数上限を変更"
    echo ""
    exit 1
fi