#!/bin/bash

# =============================================================================
# エラーハンドリング重複検知スクリプト - Python版
# =============================================================================
# 冗長なtry-except・エラーハンドリング重複を検知し、共通ハンドラの使用を推進する
# 
# 検知対象:
# - 同じexcept節やエラーハンドリング処理の重複
# - 統一エラーハンドラを使わずに直接try-exceptを使用
# - print/sys.stderr.write等の直接使用（loggingモジュール未使用）
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

# チェック対象のファイル（変更されたPythonファイルのみ）
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.py$' | grep -v '__pycache__' | grep -v 'test_' | grep -v '_test.py' | grep -v 'conftest.py')

if [ -z "$CHANGED_FILES" ]; then
    echo "✅ チェック対象のPythonファイルがありません"
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
    local print_error_count=0
    local sys_stderr_count=0
    local bare_except_count=0
    
    # 共通的なexcept節のパターンを検索
    for file in $CHANGED_FILES; do
        if [ -f "$file" ]; then
            # except節のパターンを抽出
            if grep -q "except.*:" "$file" 2>/dev/null; then
                grep -n "except.*:" "$file" | while IFS=: read -r line_num line_content; do
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
        # print使用チェック（エラーハンドリング内）
        print_error_count=$(grep -c "print.*[Ee]rror\|print.*[Ee]xception" "$temp_file" 2>/dev/null || echo "0")
        sys_stderr_count=$(grep -c "sys\.stderr" "$temp_file" 2>/dev/null || echo "0")
        bare_except_count=$(grep -c "except:" "$temp_file" 2>/dev/null || echo "0")
        
        if [[ $print_error_count -gt 0 ]]; then
            log_warning "printでのエラー出力が ${print_error_count} 箇所で検出されました"
            log_warning "→ logger.error()を使用してください（統一ログ管理）"
        fi
        
        if [[ $sys_stderr_count -gt 0 ]]; then
            log_warning "sys.stderr.writeの使用が ${sys_stderr_count} 箇所で検出されました"
            log_warning "→ logger.error()を使用してください"
        fi
        
        if [[ $bare_except_count -gt 0 ]]; then
            log_error "bare except節（except:）が ${bare_except_count} 箇所で検出されました"
            log_error "→ 具体的な例外タイプを指定してください（except Exception:）"
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
            # try-except使用をチェック
            if grep -q "try:" "$file"; then
                # loggingモジュールのインポートをチェック
                if ! grep -q "import logging\|from logging import" "$file"; then
                    # 直接try-exceptを使用していてloggingを使っていない
                    local try_except_lines=$(grep -n "try:" "$file" | head -3)
                    if [[ -n "$try_except_lines" ]]; then
                        log_warning "loggingモジュール未使用: $(basename "$file")"
                        echo "$try_except_lines" | while IFS= read -r line; do
                            echo "    $line"
                        done
                        log_warning "→ loggingモジュールを使用してエラーログを統一管理してください"
                    fi
                fi
            fi
        fi
    done
}

# =============================================================================
# 重複例外処理パターンの検知
# =============================================================================

check_redundant_exception_patterns() {
    log_info "重複例外処理パターンを検知中..."
    
    for file in $CHANGED_FILES; do
        if [ -f "$file" ]; then
            # 同じ例外タイプの重複チェック
            local exception_types=$(grep -E "except\s+\w+Error\s*:" "$file" 2>/dev/null | sed 's/.*except\s\+\(\w\+Error\).*/\1/' | sort | uniq -c | sort -nr)
            
            while read -r count exception; do
                if [[ -n "$count" && "$count" -gt 3 ]]; then
                    log_warning "同じ例外タイプの重複処理: $(basename "$file") - $exception (${count}箇所)"
                    log_warning "→ 共通のエラーハンドラー関数の作成を検討してください"
                fi
            done <<< "$exception_types"
        fi
    done
}

# =============================================================================
# デコレータベースのエラーハンドリング検知
# =============================================================================

check_decorator_error_handling() {
    log_info "デコレータベースのエラーハンドリング使用状況を確認中..."
    
    for file in $CHANGED_FILES; do
        if [ -f "$file" ]; then
            # 多数の関数がある場合、デコレータの使用を推奨
            local function_count=$(grep -c "^def " "$file" 2>/dev/null || echo "0")
            local try_count=$(grep -c "^\s*try:" "$file" 2>/dev/null || echo "0")
            
            if [[ $function_count -gt 5 && $try_count -gt 3 ]]; then
                if ! grep -q "@.*error\|@.*exception\|@.*catch" "$file"; then
                    log_warning "エラーハンドリングデコレータ未使用: $(basename "$file")"
                    log_warning "→ 関数数: $function_count, try-except数: $try_count"
                    log_warning "→ エラーハンドリングデコレータの使用を検討してください"
                fi
            fi
        fi
    done
}

# =============================================================================
# メイン実行
# =============================================================================

main() {
    echo "=============================================================================="
    echo "🔍 エラーハンドリング重複検知スクリプト - Python版"
    echo "=============================================================================="
    echo ""
    echo "📝 チェック対象ファイル数: $(echo "$CHANGED_FILES" | wc -l)"
    echo ""
    
    # 各チェック実行
    check_duplicate_error_patterns
    echo ""
    
    check_unified_error_handler_usage
    echo ""
    
    check_redundant_exception_patterns
    echo ""
    
    check_decorator_error_handling
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
            echo "   - loggingモジュールを使用してエラーログを統一"
            echo "   - 具体的な例外タイプを指定（bare exceptを避ける）"
            echo "   - 共通のエラーハンドラー関数やデコレータの作成"
            echo "   - printやsys.stderr.writeの代わりにlogger.error()を使用"
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