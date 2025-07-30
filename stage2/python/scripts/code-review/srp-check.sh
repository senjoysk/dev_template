#!/bin/bash

# 単一責任原則（SRP: Single Responsibility Principle）チェックスクリプト - Python版
# ファイルサイズと複雑度から、単一責任の原則に違反している可能性があるファイルを検出

echo "🔍 単一責任原則チェック開始..."

# 設定可能な閾値（環境変数で上書き可能）
MAX_FILE_LINES="${SRP_MAX_LINES:-200}"
MAX_FUNCTION_LINES="${SRP_MAX_FUNCTION_LINES:-50}"
MAX_CLASS_METHODS="${SRP_MAX_CLASS_METHODS:-10}"
MAX_IMPORTS="${SRP_MAX_IMPORTS:-15}"

# 結果を格納する変数
VIOLATIONS=0
LARGE_FILES=()
LARGE_FUNCTIONS=()
LARGE_CLASSES=()
TOO_MANY_IMPORTS=()

# チェック対象のファイル（変更されたPythonファイルのみ）
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.py$' | grep -v '__pycache__' | grep -v 'test_' | grep -v '_test.py' | grep -v 'conftest.py')

if [ -z "$CHANGED_FILES" ]; then
    echo "✅ チェック対象のPythonファイルがありません"
    exit 0
fi

echo "📝 チェック対象ファイル数: $(echo "$CHANGED_FILES" | wc -l)"

# 1. ファイルサイズチェック
echo ""
echo "🔍 ファイルサイズチェック（${MAX_FILE_LINES}行以上）..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        line_count=$(wc -l < "$file" | tr -d ' ')
        if [ "$line_count" -gt "$MAX_FILE_LINES" ]; then
            LARGE_FILES+=("$file:$line_count")
            VIOLATIONS=$((VIOLATIONS + 1))
            echo "  ⚠️  $file: ${line_count}行"
        fi
    fi
done

# 2. 関数の長さチェック
echo ""
echo "🔍 関数の長さチェック（${MAX_FUNCTION_LINES}行以上）..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # Pythonの関数定義を検出 (def または async def)
        while IFS=: read -r line_num line_content; do
            if [[ "$line_content" =~ ^[[:space:]]*(async[[:space:]]+)?def[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
                func_name="${BASH_REMATCH[2]}"
                indent_level=$(echo "$line_content" | sed 's/[^ ].*//' | wc -c)
                
                # 関数の終了位置を探す（同じインデントレベルの次の要素まで）
                end_line=$(awk -v start="$line_num" -v indent="$indent_level" '
                    NR > start {
                        # 現在の行のインデントを計算
                        current_indent = match($0, /[^ ]/) - 1
                        if (current_indent >= 0 && current_indent < indent && $0 !~ /^[[:space:]]*$/ && $0 !~ /^[[:space:]]*#/) {
                            print NR - 1
                            exit
                        }
                    }
                    END { print NR }
                ' "$file")
                
                if [ -n "$end_line" ]; then
                    func_lines=$((end_line - line_num + 1))
                    if [ "$func_lines" -gt "$MAX_FUNCTION_LINES" ]; then
                        LARGE_FUNCTIONS+=("$file:$line_num:$func_name:$func_lines")
                        VIOLATIONS=$((VIOLATIONS + 1))
                        echo "  ⚠️  $file:$line_num - $func_name: ${func_lines}行"
                    fi
                fi
            fi
        done < <(grep -n -E "^[[:space:]]*(async[[:space:]]+)?def[[:space:]]+" "$file" 2>/dev/null || true)
    fi
done

# 3. クラスのメソッド数チェック
echo ""
echo "🔍 クラスのメソッド数チェック（${MAX_CLASS_METHODS}個以上）..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # クラス定義を検出
        while IFS=: read -r line_num class_line; do
            if [[ "$class_line" =~ ^[[:space:]]*class[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
                class_name="${BASH_REMATCH[1]}"
                indent_level=$(echo "$class_line" | sed 's/[^ ].*//' | wc -c)
                
                # クラス内のメソッド数をカウント
                method_count=$(awk -v start="$line_num" -v indent="$indent_level" '
                    NR > start {
                        # クラスの終了を検出
                        current_indent = match($0, /[^ ]/) - 1
                        if (current_indent >= 0 && current_indent <= indent && $0 !~ /^[[:space:]]*$/ && $0 !~ /^[[:space:]]*#/) {
                            exit
                        }
                        # メソッド定義を検出（defで始まり、インデントがクラスより深い）
                        if ($0 ~ /^[[:space:]]+def[[:space:]]/ && current_indent > indent) {
                            count++
                        }
                    }
                    END { print count+0 }
                ' "$file")
                
                if [ "$method_count" -gt "$MAX_CLASS_METHODS" ]; then
                    LARGE_CLASSES+=("$file:$line_num:$class_name:$method_count")
                    VIOLATIONS=$((VIOLATIONS + 1))
                    echo "  ⚠️  $file:$line_num - class $class_name: ${method_count}メソッド"
                fi
            fi
        done < <(grep -n "^[[:space:]]*class[[:space:]]" "$file" 2>/dev/null || true)
    fi
done

# 4. インポート数チェック
echo ""
echo "🔍 インポート数チェック（${MAX_IMPORTS}個以上）..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # import文とfrom...import文をカウント
        import_count=$(grep -E "^(import|from)" "$file" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$import_count" -gt "$MAX_IMPORTS" ]; then
            TOO_MANY_IMPORTS+=("$file:$import_count")
            VIOLATIONS=$((VIOLATIONS + 1))
            echo "  ⚠️  $file: ${import_count}個のインポート"
        fi
    fi
done

# 結果サマリー
echo ""
echo "📊 チェック結果サマリー"
echo "========================"

if [ $VIOLATIONS -eq 0 ]; then
    echo "✅ 単一責任原則の違反は検出されませんでした！"
    exit 0
else
    echo "⚠️  ${VIOLATIONS}件の潜在的な違反が検出されました"
    echo ""
    
    if [ ${#LARGE_FILES[@]} -gt 0 ]; then
        echo "📄 大きすぎるファイル: ${#LARGE_FILES[@]}件"
        echo "  💡 ファイルを機能ごとに分割することを検討してください"
    fi
    
    if [ ${#LARGE_FUNCTIONS[@]} -gt 0 ]; then
        echo "📏 長すぎる関数: ${#LARGE_FUNCTIONS[@]}件"
        echo "  💡 関数を小さな単位に分割してください"
    fi
    
    if [ ${#LARGE_CLASSES[@]} -gt 0 ]; then
        echo "🏗️  メソッドが多すぎるクラス: ${#LARGE_CLASSES[@]}件"
        echo "  💡 クラスの責任を分割することを検討してください"
    fi
    
    if [ ${#TOO_MANY_IMPORTS[@]} -gt 0 ]; then
        echo "📦 インポートが多すぎるファイル: ${#TOO_MANY_IMPORTS[@]}件"
        echo "  💡 依存関係を見直し、モジュールの結合度を下げてください"
    fi
    
    echo ""
    echo "📚 単一責任原則（SRP）: 各モジュールは1つの責任のみを持つべきです"
    exit 1
fi