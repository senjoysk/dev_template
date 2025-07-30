#!/bin/bash

# ファイルサイズ監視スクリプト
# 大きすぎるファイルを検出し、リファクタリングの必要性を示唆

echo "🔍 ファイルサイズチェック開始..."

# 設定可能な閾値（環境変数で上書き可能）
WARNING_LINES="${FILE_SIZE_WARNING:-150}"  # 警告レベル
ERROR_LINES="${FILE_SIZE_ERROR:-300}"      # エラーレベル
WARNING_SIZE_KB="${FILE_SIZE_WARNING_KB:-50}"  # ファイルサイズ警告（KB）
ERROR_SIZE_KB="${FILE_SIZE_ERROR_KB:-100}"     # ファイルサイズエラー（KB）

# 結果を格納する変数
VIOLATIONS=0
WARNING_FILES=()
ERROR_FILES=()
LARGE_SIZE_FILES=()

# チェック対象のファイル（変更されたTypeScript/JavaScriptファイルのみ）
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(tsx?|jsx?)$' | grep -v '\.d\.ts$' | grep -v '__tests__' | grep -v '.test.' | grep -v '.spec.')

if [ -z "$CHANGED_FILES" ]; then
    echo "✅ チェック対象のファイルがありません"
    exit 0
fi

echo "📝 チェック対象ファイル数: $(echo "$CHANGED_FILES" | wc -l)"
echo ""
echo "📏 閾値設定:"
echo "  - 警告: ${WARNING_LINES}行 または ${WARNING_SIZE_KB}KB"
echo "  - エラー: ${ERROR_LINES}行 または ${ERROR_SIZE_KB}KB"

# ファイルチェック
echo ""
echo "🔍 ファイル分析中..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # 行数チェック
        line_count=$(wc -l < "$file" | tr -d ' ')
        
        # ファイルサイズチェック（KB）
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            file_size_kb=$(stat -f%z "$file" | awk '{print int($1/1024)}')
        else
            # Linux
            file_size_kb=$(stat -c%s "$file" | awk '{print int($1/1024)}')
        fi
        
        # コメントと空行を除いた実効行数
        effective_lines=$(grep -v '^\s*$' "$file" | grep -v '^\s*//' | grep -v '^\s*/\*' | wc -l | tr -d ' ')
        
        # 評価
        severity=""
        
        # 行数による評価
        if [ "$line_count" -ge "$ERROR_LINES" ]; then
            ERROR_FILES+=("$file:$line_count:$effective_lines")
            severity="ERROR"
            VIOLATIONS=$((VIOLATIONS + 1))
        elif [ "$line_count" -ge "$WARNING_LINES" ]; then
            WARNING_FILES+=("$file:$line_count:$effective_lines")
            severity="WARNING"
            VIOLATIONS=$((VIOLATIONS + 1))
        fi
        
        # ファイルサイズによる評価
        if [ "$file_size_kb" -ge "$ERROR_SIZE_KB" ]; then
            LARGE_SIZE_FILES+=("$file:${file_size_kb}KB")
            if [ "$severity" != "ERROR" ]; then
                severity="ERROR"
                VIOLATIONS=$((VIOLATIONS + 1))
            fi
        elif [ "$file_size_kb" -ge "$WARNING_SIZE_KB" ]; then
            LARGE_SIZE_FILES+=("$file:${file_size_kb}KB")
            if [ -z "$severity" ]; then
                severity="WARNING"
                VIOLATIONS=$((VIOLATIONS + 1))
            fi
        fi
        
        # 結果表示
        if [ -n "$severity" ]; then
            if [ "$severity" = "ERROR" ]; then
                echo "  ❌ $file: ${line_count}行 (実効${effective_lines}行), ${file_size_kb}KB"
            else
                echo "  ⚠️  $file: ${line_count}行 (実効${effective_lines}行), ${file_size_kb}KB"
            fi
        fi
    fi
done

# 詳細分析（エラーファイルのみ）
if [ ${#ERROR_FILES[@]} -gt 0 ]; then
    echo ""
    echo "📊 詳細分析（エラーレベルのファイル）"
    echo "================================"
    
    for file_info in "${ERROR_FILES[@]}"; do
        file=$(echo "$file_info" | cut -d: -f1)
        echo ""
        echo "📄 $file"
        
        # インポート数
        import_count=$(grep -c "^import" "$file" 2>/dev/null || echo "0")
        echo "  📦 インポート数: $import_count"
        
        # 関数/メソッド数
        function_count=$(grep -E "^\s*(export\s+)?(async\s+)?(function|const|let|var).*=.*=>|^\s*(export\s+)?(async\s+)?function" "$file" | wc -l | tr -d ' ')
        echo "  🔧 関数数: $function_count"
        
        # クラス数
        class_count=$(grep -c "^\s*\(export\s\+\)\?class\s" "$file" 2>/dev/null || echo "0")
        echo "  🏗️  クラス数: $class_count"
        
        # 複雑度の指標（条件文の数）
        complexity=$(grep -E "^\s*(if|else|switch|for|while|do|try|catch)" "$file" | wc -l | tr -d ' ')
        echo "  🔀 条件文数: $complexity"
    done
fi

# 結果サマリー
echo ""
echo "📊 チェック結果サマリー"
echo "========================"

if [ $VIOLATIONS -eq 0 ]; then
    echo "✅ すべてのファイルが適切なサイズです！"
    exit 0
else
    total_errors=${#ERROR_FILES[@]}
    total_warnings=${#WARNING_FILES[@]}
    
    echo "📋 検出された問題:"
    
    if [ $total_errors -gt 0 ]; then
        echo "  ❌ エラー: ${total_errors}件（${ERROR_LINES}行以上）"
    fi
    
    if [ $total_warnings -gt 0 ]; then
        echo "  ⚠️  警告: ${total_warnings}件（${WARNING_LINES}行以上）"
    fi
    
    echo ""
    echo "💡 推奨アクション:"
    echo "  1. 大きなファイルを機能ごとに分割"
    echo "  2. 共通処理を別モジュールに抽出"
    echo "  3. 複雑なロジックをヘルパー関数に分離"
    echo "  4. テストコードは別ファイルに配置"
    
    if [ $total_errors -gt 0 ]; then
        echo ""
        echo "❌ エラーレベルのファイルが存在します。リファクタリングを強く推奨します。"
        exit 1
    else
        echo ""
        echo "⚠️  警告レベルのファイルが存在します。将来的なリファクタリングを検討してください。"
        exit 0
    fi
fi