#!/bin/bash

# =============================================================================
# エラーハンドリング重複検知スクリプト
# =============================================================================
# 冗長なtry-catch・エラーハンドリング重複を検知し、共通ハンドラの使用を推進する
# 
# 検知対象:
# - 同じcatch節やエラーハンドリング処理の重複
# - 統一エラーハンドラを使わずに直接try-catchを使用
# - console.error等の直接使用（Loggerサービス未使用）
# =============================================================================

# カラー設定
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 検査結果カウンタ
VIOLATIONS_COUNT=0
ERRORS_COUNT=0

# チェック対象のファイル（変更されたTypeScript/JavaScriptファイルのみ）
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(tsx?|jsx?)$' | grep -v '\.d\.ts$' | grep -v '__tests__' | grep -v '.test.' | grep -v '.spec.')

if [ -z "$CHANGED_FILES" ]; then
    echo "✅ チェック対象のファイルがありません"
    exit 0
fi

# =============================================================================
# ヘルパー関数
# =============================================================================

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((VIOLATIONS_COUNT++))
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
    ((ERRORS_COUNT++))
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# =============================================================================
# 重複エラーハンドリングパターンの検知
# =============================================================================

check_duplicate_error_patterns() {
    log_info "重複エラーハンドリングパターンを検知中..."
    
    local temp_file=$(mktemp)
    local console_error_count=0
    local throw_new_error_count=0
    
    # 共通的なcatch節のパターンを検索
    for file in $CHANGED_FILES; do
        if [ -f "$file" ]; then
            # catch節のパターンを抽出
            if grep -q "catch.*error.*{" "$file" 2>/dev/null; then
                grep -n "catch.*error.*{" "$file" | while IFS=: read -r line_num line_content; do
                    local next_lines=$(sed -n "${line_num},$((line_num+5))p" "$file" 2>/dev/null)
                    echo "FILE:$file:$line_num" >> "$temp_file"
                    echo "$next_lines" >> "$temp_file"
                    echo "---" >> "$temp_file"
                done
            fi
        fi
    done
    
    # 重複パターンを分析
    if [[ -s "$temp_file" ]]; then
        # console.error使用チェック
        console_error_count=$(grep -c "console\.error" "$temp_file" 2>/dev/null || echo "0")
        throw_new_error_count=$(grep -c "throw new.*Error" "$temp_file" 2>/dev/null || echo "0")
        
        if [[ $console_error_count -gt 0 ]]; then
            log_warning "console.errorの直接使用が ${console_error_count} 箇所で検出されました"
            log_warning "→ logger.errorを使用してください（統一ログ管理）"
        fi
        
        if [[ $throw_new_error_count -gt 3 ]]; then
            log_warning "直接的なError作成が ${throw_new_error_count} 箇所で検出されました"
            log_warning "→ AppErrorまたは専用エラークラスの使用を検討してください"
        fi
    fi
    
    rm -f "$temp_file"
}

# =============================================================================
# 統一エラーハンドラの未使用検知
# =============================================================================

check_unified_error_handler_usage() {
    log_info "統一エラーハンドラーの使用状況を確認中..."
    
    for file in $CHANGED_FILES; do
        if [ -f "$file" ]; then
            # try-catch使用をチェック
            if grep -q "try\s*{" "$file"; then
                # 統一エラーハンドラの使用をチェック
                if ! grep -q "withErrorHandling\|withApiErrorHandling\|withDatabaseErrorHandling\|withDiscordErrorHandling\|errorHandler\|asyncHandler" "$file"; then
                    # 直接try-catchを使用している箇所を報告
                    local try_catch_lines=$(grep -n "try\s*{" "$file" | head -3)
                    if [[ -n "$try_catch_lines" ]]; then
                        log_warning "統一エラーハンドラー未使用: $(basename "$file")"
                        echo "$try_catch_lines" | while IFS= read -r line; do
                            echo "    $line"
                        done
                        log_warning "→ withErrorHandling系の関数やasyncHandlerを使用してください"
                    fi
                fi
            fi
        fi
    done
}

# =============================================================================
# 冗長なPromise.rejectパターンの検知
# =============================================================================

check_redundant_promise_patterns() {
    log_info "冗長なPromise.rejectパターンを検知中..."
    
    for file in $CHANGED_FILES; do
        if [ -f "$file" ] && grep -q "new Promise.*reject" "$file"; then
            local reject_patterns=$(grep -c "reject.*new.*Error\|reject.*AppError" "$file" 2>/dev/null || echo "0")
            if [[ $reject_patterns -gt 2 ]]; then
                log_warning "Promise.reject重複パターン: $(basename "$file") (${reject_patterns}箇所)"
                log_warning "→ createPromiseErrorHandlerの使用を検討してください"
            fi
        fi
    done
}

# =============================================================================
# Express用エラーハンドリングの検知
# =============================================================================

check_express_error_handling() {
    log_info "Express用エラーハンドリングの使用状況を確認中..."
    
    for file in $CHANGED_FILES; do
        if [ -f "$file" ] && [[ "$file" == *"route"* || "$file" == *"controller"* || "$file" == *"middleware"* ]]; then
            if grep -q "try\s*{" "$file" && ! grep -q "asyncHandler\|expressErrorHandler\|next(" "$file"; then
                log_warning "Express用統一エラーハンドラー未使用: $(basename "$file")"
                log_warning "→ asyncHandler または expressErrorHandler を使用してください"
            fi
        fi
    done
}

# =============================================================================
# メイン実行
# =============================================================================

main() {
    echo "=============================================================================="
    echo "🔍 エラーハンドリング重複検知スクリプト"
    echo "=============================================================================="
    echo ""
    echo "📝 チェック対象ファイル数: $(echo "$CHANGED_FILES" | wc -l)"
    echo ""
    
    # 各チェック実行
    check_duplicate_error_patterns
    echo ""
    
    check_unified_error_handler_usage
    echo ""
    
    check_redundant_promise_patterns
    echo ""
    
    check_express_error_handling
    echo ""
    
    # 結果サマリー
    echo "=============================================================================="
    echo "📊 検査結果サマリー"
    echo "=============================================================================="
    
    if [[ $ERRORS_COUNT -eq 0 && $VIOLATIONS_COUNT -eq 0 ]]; then
        log_success "エラーハンドリング重複は検出されませんでした！"
        echo ""
        log_success "✅ 統一エラーハンドラーが適切に使用されています"
        echo ""
    else
        if [[ $ERRORS_COUNT -gt 0 ]]; then
            log_error "重大な問題: ${ERRORS_COUNT} 件"
        fi
        
        if [[ $VIOLATIONS_COUNT -gt 0 ]]; then
            log_warning "改善提案: ${VIOLATIONS_COUNT} 件"
            echo ""
            echo "💡 改善方法:"
            echo "   - withErrorHandling系の関数を使用してtry-catch処理を統一"
            echo "   - AppError/専用エラークラスを使用してエラー情報を構造化"
            echo "   - Express用にはasyncHandlerとexpressErrorHandlerを使用"
            echo "   - console.error直接使用をlogger.errorに変更"
        fi
        
        echo ""
        echo "📚 統一エラーハンドリングパターンの使用を推奨します"
    fi
    
    echo "=============================================================================="
    
    # 終了コード
    if [[ $ERRORS_COUNT -gt 0 ]]; then
        exit 1
    elif [[ $VIOLATIONS_COUNT -gt 0 ]]; then
        exit 0  # 警告レベルは成功扱い（pre-commitを止めない）
    else
        exit 0
    fi
}

# スクリプト実行
main "$@"