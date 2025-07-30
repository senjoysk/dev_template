#!/bin/bash

# エラー処理規約違反検出スクリプト - Python版
# print()でのエラー出力、except節での握りつぶしを検出

echo "🔍 エラー処理規約チェック開始..."

# 設定可能な変数（プロジェクトでカスタマイズ可能）
LOGGER_MODULE="${ERROR_CHECK_LOGGER_MODULE:-logging}"
CUSTOM_ERROR_MODULE="${ERROR_CHECK_CUSTOM_ERROR_MODULE:-exceptions}"
SKIP_CUSTOM_ERROR_CHECK="${ERROR_CHECK_SKIP_CUSTOM_ERROR:-false}"

# 結果を格納する変数
VIOLATIONS=0
PRINT_ERROR_FILES=()
BARE_EXCEPT_FILES=()
STANDARD_EXCEPTION_FILES=()
EXCEPT_PASS_FILES=()

# チェック対象のファイル（変更されたPythonファイルのみ）
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.py$' | grep -v '__pycache__' | grep -v 'test_' | grep -v '_test.py')

if [ -z "$CHANGED_FILES" ]; then
    echo "✅ チェック対象のPythonファイルがありません"
    exit 0
fi

echo "📝 チェック対象ファイル数: $(echo "$CHANGED_FILES" | wc -l)"

# 1. print()でのエラー出力をチェック
echo ""
echo "🔍 print()でのエラー出力チェック..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # logger系のファイルは除外
        if [[ "$file" == *"logger"* ]] || [[ "$file" == *"logging"* ]]; then
            continue
        fi
        
        # print文でerror/exception/traceback等が含まれるものを検出
        if grep -E "print\(.*(\berror\b|\bexception\b|\btraceback\b|エラー|例外)" "$file" > /dev/null; then
            PRINT_ERROR_FILES+=("$file")
            VIOLATIONS=$((VIOLATIONS + 1))
            echo "  ❌ $file: print()でエラー情報を出力しています"
            grep -n -E "print\(.*(\berror\b|\bexception\b|\btraceback\b)" "$file" | head -3
        fi
    fi
done

# 2. 標準Exception使用をチェック（オプショナル）
if [ "$SKIP_CUSTOM_ERROR_CHECK" != "true" ]; then
    echo ""
    echo "🔍 標準Exception使用チェック..."
    for file in $CHANGED_FILES; do
        if [ -f "$file" ]; then
            # exceptions/errorsファイルは除外
            if [[ "$file" == *"exception"* ]] || [[ "$file" == *"error"* ]]; then
                continue
            fi
            
            # raise Exception()の使用を検出
            if grep -E "raise Exception\(" "$file" | grep -v "#.*raise Exception" > /dev/null; then
                STANDARD_EXCEPTION_FILES+=("$file")
                VIOLATIONS=$((VIOLATIONS + 1))
                echo "  ❌ $file: 標準Exceptionが使用されています（具体的な例外クラスの使用を推奨）"
                grep -n -E "raise Exception\(" "$file" | grep -v "#.*raise Exception" | head -3
            fi
        fi
    done
fi

# 3. bare exceptをチェック
echo ""
echo "🔍 bare except節チェック..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # except: のみの行を検出
        if grep -E "^[[:space:]]*except[[:space:]]*:" "$file" > /dev/null; then
            BARE_EXCEPT_FILES+=("$file")
            VIOLATIONS=$((VIOLATIONS + 1))
            echo "  ❌ $file: bare except節が使用されています"
            grep -n -E "^[[:space:]]*except[[:space:]]*:" "$file" | head -3
        fi
    fi
done

# 4. except節でのpassを検出
echo ""
echo "🔍 except節でのpass使用チェック..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # except節の後にpassがあるパターンを検出
        # awkで複数行パターンマッチング
        if awk '/except.*:/ { except_line=NR; next } 
                except_line && NR <= except_line+5 && /^[[:space:]]*pass[[:space:]]*$/ { 
                    print FILENAME":"except_line":except節でpassが使用されています"; 
                    except_line=0 
                }' "$file" | grep -q "except節でpass"; then
            EXCEPT_PASS_FILES+=("$file")
            VIOLATIONS=$((VIOLATIONS + 1))
            echo "  ⚠️  $file: except節でエラーを握りつぶしている可能性があります"
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
    
    if [ ${#PRINT_ERROR_FILES[@]} -gt 0 ]; then
        echo "🚫 print()でのエラー出力: ${#PRINT_ERROR_FILES[@]}件"
        for file in "${PRINT_ERROR_FILES[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: loggingモジュールを使用してください"
        echo "          import logging"
        echo "          logger = logging.getLogger(__name__)"
        echo "          logger.error('エラーメッセージ', exc_info=True)"
        echo ""
    fi
    
    if [ ${#STANDARD_EXCEPTION_FILES[@]} -gt 0 ]; then
        echo "🚫 標準Exception使用: ${#STANDARD_EXCEPTION_FILES[@]}件"
        for file in "${STANDARD_EXCEPTION_FILES[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: 具体的な例外クラスを使用してください"
        echo "          raise ValueError('無効な値です')"
        echo "          raise TypeError('型が不正です')"
        echo "          raise CustomError('カスタムエラー')"
        echo ""
    fi
    
    if [ ${#BARE_EXCEPT_FILES[@]} -gt 0 ]; then
        echo "🚫 bare except使用: ${#BARE_EXCEPT_FILES[@]}件"
        for file in "${BARE_EXCEPT_FILES[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: 具体的な例外を捕捉してください"
        echo "          except ValueError:"
        echo "          except (TypeError, AttributeError):"
        echo "          except Exception:  # 最低限Exceptionを指定"
        echo ""
    fi
    
    if [ ${#EXCEPT_PASS_FILES[@]} -gt 0 ]; then
        echo "⚠️  エラー握りつぶしの可能性: ${#EXCEPT_PASS_FILES[@]}件"
        for file in "${EXCEPT_PASS_FILES[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: except節では必ず以下のいずれかを実行してください:"
        echo "          1. logger.exception()でログ記録"
        echo "          2. エラーを再raiseまたは別の例外としてraise"
        echo "          3. 適切なエラーハンドリング処理を実装"
        echo ""
    fi
    
    echo "📚 プロジェクトのエラー処理規約を確認してください"
    exit 1
fi