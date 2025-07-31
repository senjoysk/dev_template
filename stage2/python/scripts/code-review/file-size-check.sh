#!/bin/bash

# ファイルサイズ監視スクリプト - Python版
# 肥大化したファイルを検出し、開発効率と保守性の低下を防ぐ

echo "🔍 ファイルサイズチェック開始..."

# 設定: 行数閾値定義（プロジェクトに応じて調整可能）
LARGE_FILE_LINES=${LARGE_FILE_LINES:-800}        # 大型ファイル警告閾値
HUGE_FILE_LINES=${HUGE_FILE_LINES:-1500}         # 巨大ファイル阻止閾値
WARNING_FILE_LINES=${WARNING_FILE_LINES:-600}    # 警告ファイル閾値

# 結果を格納する変数
VIOLATIONS=0
WARNING_FILES=()
ERROR_FILES=()
LARGE_SIZE_FILES=()

# チェック対象のファイル（変更されたPythonファイルのみ）
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.py$' | grep -v '__pycache__' | grep -v 'test_' | grep -v '_test.py' | grep -v 'conftest.py')

if [ -z "$CHANGED_FILES" ]; then
    echo "✅ チェック対象のPythonファイルがありません"
    exit 0
fi

echo "📝 チェック対象ファイル数: $(echo "$CHANGED_FILES" | wc -l)"
echo ""
echo "📏 行数閾値:"
echo "  - 監視対象: ${WARNING_FILE_LINES}行"
echo "  - 大型ファイル: ${LARGE_FILE_LINES}行"
echo "  - 巨大ファイル: ${HUGE_FILE_LINES}行"

# ファイルチェック
echo ""
echo "🔍 ファイル分析中..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # 行数チェック
        line_count=$(wc -l < "$file" | tr -d ' ')
        
        # ファイルサイズ（参考情報として）
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            file_size_kb=$(stat -f%z "$file" | awk '{print int($1/1024)}')
        else
            # Linux
            file_size_kb=$(stat -c%s "$file" | awk '{print int($1/1024)}')
        fi
        
        # コメントと空行を除いた実効行数
        # Pythonのコメント（#）とdocstring（""" または '''）を考慮
        effective_lines=$(python3 -c "
import re
with open('$file', 'r') as f:
    content = f.read()
    # docstringを除去
    content = re.sub(r'\"\"\".*?\"\"\"', '', content, flags=re.DOTALL)
    content = re.sub(r\"'''.*?'''\", '', content, flags=re.DOTALL)
    # コメントと空行をカウントから除外
    lines = [line for line in content.split('\n') 
             if line.strip() and not line.strip().startswith('#')]
    print(len(lines))
" 2>/dev/null || grep -v '^\s*$' "$file" | grep -v '^\s*#' | wc -l | tr -d ' ')
        
        # 評価
        severity=""
        
        # 行数による評価
        if [ "$line_count" -ge "$HUGE_FILE_LINES" ]; then
            ERROR_FILES+=("$file:$line_count:$effective_lines")
            severity="ERROR"
            VIOLATIONS=$((VIOLATIONS + 1))
        elif [ "$line_count" -ge "$LARGE_FILE_LINES" ]; then
            WARNING_FILES+=("$file:$line_count:$effective_lines")
            severity="WARNING"
            VIOLATIONS=$((VIOLATIONS + 1))
        elif [ "$line_count" -ge "$WARNING_FILE_LINES" ]; then
            WARNING_FILES+=("$file:$line_count:$effective_lines")
            severity="WATCH"
            VIOLATIONS=$((VIOLATIONS + 1))
        fi
        
        # 結果表示
        if [ -n "$severity" ]; then
            if [ "$severity" = "ERROR" ]; then
                echo "  🚨 巨大ファイル: $file (${line_count}行, 実効${effective_lines}行)"
            elif [ "$severity" = "WARNING" ]; then
                echo "  ⚠️  大型ファイル: $file (${line_count}行, 実効${effective_lines}行)"
            else
                echo "  📋 監視対象: $file (${line_count}行, 実効${effective_lines}行)"
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
        import_count=$(grep -E "^(import|from)" "$file" | wc -l | tr -d ' ')
        echo "  📦 インポート数: $import_count"
        
        # 関数数
        function_count=$(grep -E "^(async )?def " "$file" | wc -l | tr -d ' ')
        echo "  🔧 関数数: $function_count"
        
        # クラス数
        class_count=$(grep -c "^class " "$file" 2>/dev/null || echo "0")
        echo "  🏗️  クラス数: $class_count"
        
        # 複雑度の指標（条件文の数）
        complexity=$(grep -E "^\s*(if|elif|else|for|while|try|except|finally|with)" "$file" | wc -l | tr -d ' ')
        echo "  🔀 制御構文数: $complexity"
        
        # デコレータの使用数（複雑度の指標）
        decorator_count=$(grep -c "^\s*@" "$file" 2>/dev/null || echo "0")
        echo "  🎨 デコレータ数: $decorator_count"
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
        echo "  🚨 巨大ファイル: ${total_errors}件（${HUGE_FILE_LINES}行以上）"
    fi
    
    if [ $total_warnings -gt 0 ]; then
        echo "  ⚠️  大型ファイル: ${total_warnings}件（${LARGE_FILE_LINES}行以上）"
    fi
    
    echo ""
    echo "💡 推奨アクション:"
    echo "  1. 大きなファイルをモジュールに分割"
    echo "  2. 共通処理をユーティリティモジュールに抽出"
    echo "  3. 複雑なロジックを別関数やクラスに分離"
    echo "  4. __init__.py を活用してパッケージ構造を整理"
    
    if [ $total_errors -gt 0 ]; then
        echo ""
        echo "🚨 ${total_errors}件の巨大ファイルが検出されました"
        echo "🔴 即座に分割対応が必要です！"
        exit 1
    else
        echo ""
        echo "⚠️  ${total_warnings}件の大型ファイルが検出されました"
        echo "📝 近い将来に分割を検討してください"
        exit 0
    fi
fi