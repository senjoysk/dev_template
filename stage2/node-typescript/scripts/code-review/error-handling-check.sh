#!/bin/bash

# エラー処理規約違反検出スクリプト（汎用版）
# console.errorの使用、catch節での握りつぶしを検出

echo "🔍 エラー処理規約チェック開始..."

# 設定可能な変数（プロジェクトでカスタマイズ可能）
LOGGER_PATH="${ERROR_CHECK_LOGGER_PATH:-./utils/logger}"
ERROR_HANDLER_PATH="${ERROR_CHECK_ERROR_HANDLER_PATH:-./utils/errorHandler}"
CUSTOM_ERROR_PATH="${ERROR_CHECK_CUSTOM_ERROR_PATH:-./errors}"
SKIP_CUSTOM_ERROR_CHECK="${ERROR_CHECK_SKIP_CUSTOM_ERROR:-false}"

# 結果を格納する変数
VIOLATIONS=0
CONSOLE_ERROR_FILES=()
CATCH_WITHOUT_THROW_FILES=()
NEW_ERROR_FILES=()

# チェック対象のファイル（変更されたTypeScriptファイルのみ）
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ts|tsx|js|jsx)$' | grep -v '__tests__' | grep -v '.test.[tj]s' | grep -v '.spec.[tj]s')

if [ -z "$CHANGED_FILES" ]; then
    echo "✅ チェック対象のファイルがありません"
    exit 0
fi

echo "📝 チェック対象ファイル数: $(echo "$CHANGED_FILES" | wc -l)"

# 1. console.errorの使用をチェック
echo ""
echo "🔍 console.error使用チェック..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # errorHandler/loggerファイルは例外
        if [[ "$file" == *"errorHandler"* ]] || [[ "$file" == *"logger"* ]]; then
            continue
        fi
        
        if grep -q "console\.error" "$file"; then
            CONSOLE_ERROR_FILES+=("$file")
            VIOLATIONS=$((VIOLATIONS + 1))
            echo "  ❌ $file: console.errorが使用されています"
            grep -n "console\.error" "$file" | head -3
        fi
    fi
done

# 2. 標準Errorの使用をチェック（new Error()） - オプショナル
if [ "$SKIP_CUSTOM_ERROR_CHECK" != "true" ]; then
    echo ""
    echo "🔍 標準Error使用チェック..."
    for file in $CHANGED_FILES; do
        if [ -f "$file" ]; then
            # errorHandler/errorsファイルは例外
            if [[ "$file" == *"errorHandler"* ]] || [[ "$file" == *"errors"* ]] || [[ "$file" == *"Error"* ]]; then
                continue
            fi
            
            if grep -E "new Error\(" "$file" | grep -v "//.*new Error" | grep -v "\* .*new Error" > /dev/null; then
                NEW_ERROR_FILES+=("$file")
                VIOLATIONS=$((VIOLATIONS + 1))
                echo "  ❌ $file: 標準Errorが使用されています（カスタムエラークラスの使用を推奨）"
                grep -n -E "new Error\(" "$file" | grep -v "//.*new Error" | head -3
            fi
        fi
    done
fi

# 3. catch節での握りつぶしをチェック
echo ""
echo "🔍 catch節チェック..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # テストファイルはスキップ
        if [[ "$file" == *"test"* ]] || [[ "$file" == *"spec"* ]]; then
            continue
        fi
        
        # catch節のパターンを検索（より簡単なアプローチ）
        if grep -E "catch.*\{[[:space:]]*//.*無視|catch.*\{[[:space:]]*\}|catch.*\{[[:space:]]*$" "$file" > /dev/null; then
            CATCH_WITHOUT_THROW_FILES+=("$file")
            VIOLATIONS=$((VIOLATIONS + 1))
            echo "  ⚠️  $file: エラーの握りつぶしが検出されました"
            grep -n -A2 -B1 "catch.*{" "$file" | head -5
        fi
    fi
done

# 結果サマリー
echo ""
echo "📊 チェック結果サマリー"
echo "========================"

if [ $VIOLATIONS -eq 0 ]; then
    echo "✅ エラー処理規約違反は検出されませんでした！"
    exit 0
else
    echo "❌ ${VIOLATIONS}件の違反が検出されました"
    echo ""
    
    if [ ${#CONSOLE_ERROR_FILES[@]} -gt 0 ]; then
        echo "🚫 console.error使用: ${#CONSOLE_ERROR_FILES[@]}件"
        for file in "${CONSOLE_ERROR_FILES[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: ロガーライブラリを使用してください"
        echo "          例: logger.error('コンテキスト', 'メッセージ', error)"
        echo ""
    fi
    
    if [ ${#NEW_ERROR_FILES[@]} -gt 0 ]; then
        echo "🚫 標準Error使用: ${#NEW_ERROR_FILES[@]}件"
        for file in "${NEW_ERROR_FILES[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: プロジェクトで定義されたカスタムエラークラスの使用を推奨します"
        echo "          例: throw new ValidationError('メッセージ')"
        echo ""
    fi
    
    if [ ${#CATCH_WITHOUT_THROW_FILES[@]} -gt 0 ]; then
        echo "⚠️  エラーの握りつぶし: ${#CATCH_WITHOUT_THROW_FILES[@]}件"
        for file in "${CATCH_WITHOUT_THROW_FILES[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: catch節では必ず以下のいずれかを実行してください:"
        echo "          1. ログ記録 + throw でエラー再スロー"
        echo "          2. エラーから復旧して return"
        echo "          3. より適切なエラーにラップして throw"
        echo ""
    fi
    
    echo "📚 プロジェクトのエラー処理規約を確認してください"
    exit 1
fi