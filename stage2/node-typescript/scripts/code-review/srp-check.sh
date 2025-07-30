#!/bin/bash

# 単一責任原則（SRP: Single Responsibility Principle）チェックスクリプト
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

# チェック対象のファイル（変更されたTypeScriptファイルのみ）
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.tsx?$' | grep -v '\.d\.ts$' | grep -v '__tests__' | grep -v '.test.ts' | grep -v '.spec.ts')

if [ -z "$CHANGED_FILES" ]; then
    echo "✅ チェック対象のTypeScriptファイルがありません"
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
        # 関数の開始と終了を検出
        # function name() { または const name = () => { のパターン
        while IFS=: read -r line_num line_content; do
            if [[ "$line_content" =~ (function|const|let|var).*\{$ ]] || [[ "$line_content" =~ =.*\=\>.*\{ ]]; then
                # 関数名を抽出
                func_name=$(echo "$line_content" | sed -E 's/.*(function|const|let|var)\s+([a-zA-Z_][a-zA-Z0-9_]*).*/\2/')
                
                # 関数の終了位置を探す（簡易的な実装）
                end_line=$(awk -v start="$line_num" '
                    NR > start {
                        if (/^}/) {
                            print NR
                            exit
                        }
                    }
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
        done < <(grep -n -E "(function|const|let|var).*\{$|=.*=>.*\{" "$file" 2>/dev/null || true)
    fi
done

# 3. クラスのメソッド数チェック
echo ""
echo "🔍 クラスのメソッド数チェック（${MAX_CLASS_METHODS}個以上）..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # クラス定義を検出
        while IFS=: read -r line_num class_line; do
            if [[ "$class_line" =~ class[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*) ]]; then
                class_name="${BASH_REMATCH[1]}"
                
                # クラス内のメソッド数をカウント（簡易実装）
                method_count=$(awk -v start="$line_num" '
                    NR > start && /^}/ { exit }
                    NR > start && /^\s*(public|private|protected|static|async)?\s*[a-zA-Z_][a-zA-Z0-9_]*\s*\(/ { count++ }
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
        import_count=$(grep -c "^import" "$file" 2>/dev/null || echo "0")
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