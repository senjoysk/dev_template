#!/bin/bash

# 型安全性チェックスクリプト - TypeScript版
# any型使用、型注釈不足を検出

echo "🔍 型安全性チェック開始..."

# 結果を格納する変数
VIOLATIONS=0
ANY_TYPE_FILES=()
IMPLICIT_ANY_FILES=()
MISSING_RETURN_TYPE_FILES=()
ALLOW_ANY_WITHOUT_REASON=()

# チェック対象のファイル（変更されたTypeScriptファイルのみ）
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.tsx?$' | grep -v '\.d\.ts$' | grep -v '__tests__' | grep -v '.test.ts' | grep -v '.spec.ts')

if [ -z "$CHANGED_FILES" ]; then
    echo "✅ チェック対象のTypeScriptファイルがありません"
    exit 0
fi

echo "📝 チェック対象ファイル数: $(echo "$CHANGED_FILES" | wc -l)"

# 1. any型の直接使用をチェック
echo ""
echo "🔍 any型使用チェック..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # any型使用をチェック
        any_lines=$(grep -n ": any" "$file" || true)
        if [ -n "$any_lines" ]; then
            # ファイル全体でALLOW_ANYコメントをチェック
            if ! grep -q "// ALLOW_ANY" "$file"; then
                ANY_TYPE_FILES+=("$file")
                VIOLATIONS=$((VIOLATIONS + 1))
                echo "  ❌ $file: any型が使用されています（ALLOW_ANYコメントなし）"
                echo "$any_lines" | head -3
            fi
        fi
        
        # ALLOW_ANYコメントはあるが理由が不明確な場合
        if grep -n "// ALLOW_ANY[[:space:]]*$" "$file" > /dev/null; then
            ALLOW_ANY_WITHOUT_REASON+=("$file")
            VIOLATIONS=$((VIOLATIONS + 1))
            echo "  ⚠️  $file: ALLOW_ANYコメントに理由が記載されていません"
            grep -n "// ALLOW_ANY[[:space:]]*$" "$file" | head -3
        fi
    fi
done

# 2. 暗黙的なany型をチェック（パラメータに型注釈がない）
echo ""
echo "🔍 暗黙的any型チェック..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # 関数パラメータの型注釈チェック（簡易版）
        # function name(param) や (param) => のパターンを検出
        if grep -E "function\s+\w+\s*\([^:)]*\w+[^:)]*\)" "$file" > /dev/null || \
           grep -E "\(\s*\w+\s*\)\s*=>" "$file" > /dev/null; then
            # より詳細な検証（型注釈がないパラメータを探す）
            if grep -E "function.*\(\s*\w+\s*[,)]" "$file" > /dev/null || \
               grep -E "\(\s*\w+\s*[,)]\s*=>" "$file" > /dev/null; then
                IMPLICIT_ANY_FILES+=("$file")
                VIOLATIONS=$((VIOLATIONS + 1))
                echo "  ❌ $file: 型注釈のないパラメータがあります（暗黙的any）"
            fi
        fi
    fi
done

# 3. 関数の戻り値型注釈チェック
echo ""
echo "🔍 戻り値型注釈チェック..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # TypeScriptコンパイラを使用して型チェック（可能な場合）
        if command -v npx >/dev/null 2>&1 && [ -f "tsconfig.json" ]; then
            # noImplicitAnyとnoImplicitReturnsを有効にして型チェック
            TYPE_CHECK_OUTPUT=$(npx tsc --noEmit --noImplicitAny --noImplicitReturns --skipLibCheck "$file" 2>&1 || true)
            
            if echo "$TYPE_CHECK_OUTPUT" | grep -E "(Missing return type|inferred type|implicit any)" > /dev/null; then
                MISSING_RETURN_TYPE_FILES+=("$file")
                VIOLATIONS=$((VIOLATIONS + 1))
                echo "  ❌ $file: 戻り値型注釈が不足している可能性があります"
                echo "$TYPE_CHECK_OUTPUT" | grep -E "(Missing return type|inferred type|implicit any)" | head -3
            fi
        else
            # TypeScriptコンパイラが使えない場合の簡易チェック
            # function name() { や () => { のパターンで : Type がないものを検出
            if grep -E "(function\s+\w+\s*\([^)]*\)\s*\{|=>\s*\{)" "$file" | grep -v -E ":\s*(Promise<|void|string|number|boolean|any|\w+(\[\])?|{)" > /dev/null; then
                MISSING_RETURN_TYPE_FILES+=("$file")
                VIOLATIONS=$((VIOLATIONS + 1))
                echo "  ⚠️  $file: 戻り値型注釈が不足している可能性があります"
            fi
        fi
    fi
done

# 結果サマリー
echo ""
echo "📊 チェック結果サマリー"
echo "========================"

if [ $VIOLATIONS -eq 0 ]; then
    echo "✅ 型安全性の問題は検出されませんでした！"
    exit 0
else
    echo "❌ ${VIOLATIONS}件の型安全性の問題が検出されました"
    echo ""
    
    if [ ${#ANY_TYPE_FILES[@]} -gt 0 ]; then
        echo "🚫 any型使用（ALLOW_ANYなし）: ${#ANY_TYPE_FILES[@]}件"
        for file in "${ANY_TYPE_FILES[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: 具体的な型を定義するか、やむを得ない場合は理由を付けてコメント"
        echo "          // ALLOW_ANY: ライブラリの型定義が不完全なため"
        echo "          const data: any = externalLibrary.getData();"
        echo ""
    fi
    
    if [ ${#ALLOW_ANY_WITHOUT_REASON[@]} -gt 0 ]; then
        echo "⚠️  ALLOW_ANYコメントに理由なし: ${#ALLOW_ANY_WITHOUT_REASON[@]}件"
        for file in "${ALLOW_ANY_WITHOUT_REASON[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: ALLOW_ANYコメントには必ず理由を記載"
        echo "          // ALLOW_ANY: sqlite3のRunResultのchangesプロパティアクセスのため"
        echo ""
    fi
    
    if [ ${#IMPLICIT_ANY_FILES[@]} -gt 0 ]; then
        echo "🚫 暗黙的any型（型注釈なし）: ${#IMPLICIT_ANY_FILES[@]}件"
        for file in "${IMPLICIT_ANY_FILES[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: すべてのパラメータに型注釈を追加"
        echo "          function process(data: UserData): void { ... }"
        echo "          const handler = (event: Event): void => { ... }"
        echo ""
    fi
    
    if [ ${#MISSING_RETURN_TYPE_FILES[@]} -gt 0 ]; then
        echo "🚫 戻り値型注釈なし: ${#MISSING_RETURN_TYPE_FILES[@]}件"
        for file in "${MISSING_RETURN_TYPE_FILES[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: すべての関数に戻り値型を明示"
        echo "          function calculate(a: number, b: number): number { ... }"
        echo "          async function fetchData(): Promise<Data> { ... }"
        echo ""
    fi
    
    echo "📚 TypeScriptの型安全性を保つため、strictモードを維持してください"
    exit 1
fi