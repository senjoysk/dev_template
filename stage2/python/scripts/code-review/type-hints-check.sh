#!/bin/bash

# 型ヒントチェックスクリプト - Python版
# 型ヒントの不足、Any型使用を検出

echo "🔍 型ヒントチェック開始..."

# 結果を格納する変数
VIOLATIONS=0
NO_TYPE_HINT_FILES=()
ANY_TYPE_FILES=()
NO_RETURN_TYPE_FILES=()
ALLOW_ANY_WITHOUT_REASON=()

# チェック対象のファイル（変更されたPythonファイルのみ）
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.py$' | grep -v '__pycache__' | grep -v 'test_' | grep -v '_test.py' | grep -v 'conftest.py')

if [ -z "$CHANGED_FILES" ]; then
    echo "✅ チェック対象のPythonファイルがありません"
    exit 0
fi

echo "📝 チェック対象ファイル数: $(echo "$CHANGED_FILES" | wc -l)"

# 1. Any型の使用をチェック
echo ""
echo "🔍 Any型使用チェック..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # typingからAnyをインポートしているかチェック
        if grep -q "from typing import.*Any" "$file" || grep -q "import typing" "$file"; then
            # ALLOW_ANYコメントがないAny型使用を検出
            if grep -n ": Any" "$file" | grep -v "# ALLOW_ANY" > /dev/null; then
                ANY_TYPE_FILES+=("$file")
                VIOLATIONS=$((VIOLATIONS + 1))
                echo "  ❌ $file: Any型が使用されています（ALLOW_ANYコメントなし）"
                grep -n ": Any" "$file" | grep -v "# ALLOW_ANY" | head -3
            fi
            
            # ALLOW_ANYコメントはあるが理由が不明確な場合
            if grep -n "# ALLOW_ANY[[:space:]]*$" "$file" > /dev/null; then
                ALLOW_ANY_WITHOUT_REASON+=("$file")
                VIOLATIONS=$((VIOLATIONS + 1))
                echo "  ⚠️  $file: ALLOW_ANYコメントに理由が記載されていません"
                grep -n "# ALLOW_ANY[[:space:]]*$" "$file" | head -3
            fi
        fi
    fi
done

# 2. 関数の型ヒントチェック
echo ""
echo "🔍 関数型ヒントチェック..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # def function_name(param): のパターンを検出（型ヒントなし）
        # ただし、selfやclsは除外
        if grep -E "def\s+\w+\s*\([^)]*\b(?!self\b|cls\b)\w+\s*[,)]" "$file" | grep -v -E "\w+\s*:\s*\w+" > /dev/null; then
            NO_TYPE_HINT_FILES+=("$file")
            VIOLATIONS=$((VIOLATIONS + 1))
            echo "  ❌ $file: 型ヒントのないパラメータがあります"
            grep -n -E "def\s+\w+\s*\([^)]*\b(?!self\b|cls\b)\w+\s*[,)]" "$file" | grep -v -E "\w+\s*:\s*\w+" | head -3
        fi
    fi
done

# 3. 戻り値型ヒントチェック
echo ""
echo "🔍 戻り値型ヒントチェック..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # def function_name(...): で -> がないパターンを検出
        # __init__メソッドは除外（常にNoneを返すため）
        if grep -E "def\s+(?!__init__)\w+\s*\([^)]*\)\s*:" "$file" | grep -v "\->" > /dev/null; then
            NO_RETURN_TYPE_FILES+=("$file")
            VIOLATIONS=$((VIOLATIONS + 1))
            echo "  ❌ $file: 戻り値型ヒントがない関数があります"
            grep -n -E "def\s+(?!__init__)\w+\s*\([^)]*\)\s*:" "$file" | grep -v "\->" | head -3
        fi
    fi
done

# 4. mypyでの型チェック（可能な場合）
if command -v mypy >/dev/null 2>&1; then
    echo ""
    echo "🔍 mypyによる詳細な型チェック..."
    
    for file in $CHANGED_FILES; do
        if [ -f "$file" ]; then
            # mypyで型チェック
            MYPY_OUTPUT=$(mypy --strict --no-error-summary "$file" 2>&1 || true)
            
            if [ -n "$MYPY_OUTPUT" ]; then
                echo "  ⚠️  $file: mypyが型の問題を検出しました"
                echo "$MYPY_OUTPUT" | head -5
                VIOLATIONS=$((VIOLATIONS + 1))
            fi
        fi
    done
fi

# 結果サマリー
echo ""
echo "📊 チェック結果サマリー"
echo "========================"

if [ $VIOLATIONS -eq 0 ]; then
    echo "✅ 型ヒントの問題は検出されませんでした！"
    exit 0
else
    echo "❌ ${VIOLATIONS}件の型ヒントの問題が検出されました"
    echo ""
    
    if [ ${#ANY_TYPE_FILES[@]} -gt 0 ]; then
        echo "🚫 Any型使用（ALLOW_ANYなし）: ${#ANY_TYPE_FILES[@]}件"
        for file in "${ANY_TYPE_FILES[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: 具体的な型を定義するか、やむを得ない場合は理由を付けてコメント"
        echo "          from typing import Any"
        echo "          # ALLOW_ANY: 外部APIのレスポンス型が不定のため"
        echo "          response: Any = external_api.call()"
        echo ""
    fi
    
    if [ ${#ALLOW_ANY_WITHOUT_REASON[@]} -gt 0 ]; then
        echo "⚠️  ALLOW_ANYコメントに理由なし: ${#ALLOW_ANY_WITHOUT_REASON[@]}件"
        for file in "${ALLOW_ANY_WITHOUT_REASON[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: ALLOW_ANYコメントには必ず理由を記載"
        echo "          # ALLOW_ANY: JSONレスポンスの構造が動的なため"
        echo ""
    fi
    
    if [ ${#NO_TYPE_HINT_FILES[@]} -gt 0 ]; then
        echo "🚫 型ヒントなしパラメータ: ${#NO_TYPE_HINT_FILES[@]}件"
        for file in "${NO_TYPE_HINT_FILES[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: すべてのパラメータに型ヒントを追加"
        echo "          def process(data: dict[str, Any], count: int) -> None:"
        echo "          def calculate(values: list[float]) -> float:"
        echo ""
    fi
    
    if [ ${#NO_RETURN_TYPE_FILES[@]} -gt 0 ]; then
        echo "🚫 戻り値型ヒントなし: ${#NO_RETURN_TYPE_FILES[@]}件"
        for file in "${NO_RETURN_TYPE_FILES[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: すべての関数に戻り値型を明示"
        echo "          def get_user(id: int) -> User:"
        echo "          async def fetch_data() -> dict[str, Any]:"
        echo "          def process() -> None:"
        echo ""
    fi
    
    echo "📚 型ヒントにより、コードの可読性と保守性が向上します"
    echo "   mypyのインストール: pip install mypy"
    exit 1
fi