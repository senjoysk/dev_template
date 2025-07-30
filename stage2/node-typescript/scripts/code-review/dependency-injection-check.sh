#!/bin/bash

# 依存性注入（DI）品質チェックスクリプト
# インターフェース使用、具象クラスへの直接依存を検出

echo "🔍 依存性注入品質チェック開始..."

# 設定可能な変数
INTERFACES_DIR="${DI_CHECK_INTERFACES_DIR:-interfaces}"
SKIP_CONCRETE_CHECK="${DI_CHECK_SKIP_CONCRETE:-false}"

# 結果を格納する変数
VIOLATIONS=0
CONCRETE_DEPENDENCY_FILES=()
NO_INTERFACE_FILES=()
DIRECT_INSTANTIATION_FILES=()
CONSTRUCTOR_INJECTION_MISSING=()

# チェック対象のファイル（変更されたTypeScriptファイルのみ）
CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.tsx?$' | grep -v '\.d\.ts$' | grep -v '__tests__' | grep -v '.test.ts' | grep -v '.spec.ts')

if [ -z "$CHANGED_FILES" ]; then
    echo "✅ チェック対象のTypeScriptファイルがありません"
    exit 0
fi

echo "📝 チェック対象ファイル数: $(echo "$CHANGED_FILES" | wc -l)"

# 1. コンストラクタで具象クラスへの直接依存をチェック
echo ""
echo "🔍 具象クラスへの直接依存チェック..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # constructorで具象クラスを受け取っているパターンを検出
        # private database: PostgresDatabase のようなパターン
        concrete_deps=$(grep -E "constructor.*\(.*:\s*[A-Z][a-zA-Z]*" "$file" | grep -v -E "string|number|boolean|Date|Array|Promise|Interface|I[A-Z]" || true)
        if [ -n "$concrete_deps" ]; then
            # インターフェースファイルは除外
            if ! [[ "$file" =~ interface|Interface ]]; then
                CONCRETE_DEPENDENCY_FILES+=("$file")
                VIOLATIONS=$((VIOLATIONS + 1))
                echo "  ❌ $file: コンストラクタで具象クラスに依存しています"
                echo "$concrete_deps" | head -3
            fi
        fi
    fi
done

# 2. インターフェースの使用状況をチェック
echo ""
echo "🔍 インターフェース使用チェック..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # クラス定義があるがimplementsがない場合
        if grep -E "^export\s+(abstract\s+)?class\s+\w+" "$file" > /dev/null; then
            if ! grep -E "implements\s+\w+" "$file" > /dev/null; then
                # ただし、エンティティやDTOクラスは除外
                if ! [[ "$file" =~ entity|Entity|dto|DTO|model|Model ]]; then
                    NO_INTERFACE_FILES+=("$file")
                    VIOLATIONS=$((VIOLATIONS + 1))
                    echo "  ⚠️  $file: インターフェースを実装していないクラスがあります"
                fi
            fi
        fi
    fi
done

# 3. new演算子による直接インスタンス化をチェック
echo ""
echo "🔍 直接インスタンス化チェック..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # new ConcreteClass() のパターンを検出
        # ただし、Error、Date、Array等の組み込みクラスは除外
        if grep -E "new\s+[A-Z][a-zA-Z]+\(" "$file" | grep -v -E "new\s+(Error|Date|Array|Map|Set|Promise|RegExp)" > /dev/null; then
            # ファクトリーパターンやテストファイルは除外
            if ! [[ "$file" =~ factory|Factory|builder|Builder|test|spec ]]; then
                DIRECT_INSTANTIATION_FILES+=("$file")
                VIOLATIONS=$((VIOLATIONS + 1))
                echo "  ⚠️  $file: 直接インスタンス化している箇所があります"
                grep -n -E "new\s+[A-Z][a-zA-Z]+\(" "$file" | grep -v -E "new\s+(Error|Date|Array|Map|Set|Promise|RegExp)" | head -3
            fi
        fi
    fi
done

# 4. コンストラクタインジェクションの実装チェック
echo ""
echo "🔍 コンストラクタインジェクションチェック..."
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        # privateメンバーがあるがコンストラクタがない、または空のコンストラクタ
        if grep -E "private\s+\w+:" "$file" > /dev/null; then
            if ! grep -E "constructor\s*\([^)]+\)" "$file" > /dev/null; then
                CONSTRUCTOR_INJECTION_MISSING+=("$file")
                VIOLATIONS=$((VIOLATIONS + 1))
                echo "  ❌ $file: privateメンバーがあるがコンストラクタインジェクションが実装されていません"
            fi
        fi
    fi
done

# 結果サマリー
echo ""
echo "📊 チェック結果サマリー"
echo "========================"

if [ $VIOLATIONS -eq 0 ]; then
    echo "✅ 依存性注入の問題は検出されませんでした！"
    exit 0
else
    echo "❌ ${VIOLATIONS}件の依存性注入の問題が検出されました"
    echo ""
    
    if [ ${#CONCRETE_DEPENDENCY_FILES[@]} -gt 0 ]; then
        echo "🚫 具象クラスへの直接依存: ${#CONCRETE_DEPENDENCY_FILES[@]}件"
        for file in "${CONCRETE_DEPENDENCY_FILES[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: インターフェースに依存するよう変更"
        echo "          constructor(private service: IService) {} // ✅"
        echo "          constructor(private service: ConcreteService) {} // ❌"
        echo ""
    fi
    
    if [ ${#NO_INTERFACE_FILES[@]} -gt 0 ]; then
        echo "⚠️  インターフェース未実装: ${#NO_INTERFACE_FILES[@]}件"
        for file in "${NO_INTERFACE_FILES[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: インターフェースを定義して実装"
        echo "          interface IUserService { ... }"
        echo "          class UserService implements IUserService { ... }"
        echo ""
    fi
    
    if [ ${#DIRECT_INSTANTIATION_FILES[@]} -gt 0 ]; then
        echo "⚠️  直接インスタンス化: ${#DIRECT_INSTANTIATION_FILES[@]}件"
        for file in "${DIRECT_INSTANTIATION_FILES[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: ファクトリーまたはDIコンテナを使用"
        echo "          const service = container.get<IService>('IService'); // ✅"
        echo "          const service = new ConcreteService(); // ❌"
        echo ""
    fi
    
    if [ ${#CONSTRUCTOR_INJECTION_MISSING[@]} -gt 0 ]; then
        echo "🚫 コンストラクタインジェクション未実装: ${#CONSTRUCTOR_INJECTION_MISSING[@]}件"
        for file in "${CONSTRUCTOR_INJECTION_MISSING[@]}"; do
            echo "   - $file"
        done
        echo ""
        echo "  💡 対策: 依存性はコンストラクタで注入"
        echo "          constructor("
        echo "              private readonly userService: IUserService,"
        echo "              private readonly logger: ILogger"
        echo "          ) {}"
        echo ""
    fi
    
    echo "📚 SOLID原則のDIP（依存性逆転の原則）に従い、抽象に依存してください"
    exit 1
fi