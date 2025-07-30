#!/usr/bin/env bats

# コードレビュースクリプトのテスト

# テスト環境のセットアップ
setup() {
    # テスト用の一時ディレクトリを作成
    export TEST_DIR="$(mktemp -d)"
    export ORIGINAL_DIR="$(pwd)"
    export TEMPLATE_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
    
    # テストディレクトリに移動
    cd "$TEST_DIR"
    
    # Gitリポジトリを初期化（スクリプトがgitを使用するため）
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
}

# テスト環境のクリーンアップ
teardown() {
    cd "$ORIGINAL_DIR"
    rm -rf "$TEST_DIR"
}

# ============================================================================
# srp-check.sh のテスト
# ============================================================================

# テスト1: srp-check.sh - 大きすぎるTypeScriptファイルを検出
@test "srp-check.sh detects large TypeScript files" {
    # 大きなファイルを作成（デフォルト500行以上）
    cat > large.ts << 'EOF'
// This is a large file
class LargeClass {
EOF
    # 600行のダミーメソッドを追加
    for i in {1..600}; do
        echo "    method$i() { return $i; }" >> large.ts
    done
    echo "}" >> large.ts
    
    # ファイルをステージング
    git add large.ts
    
    # スクリプトを実行
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/srp-check.sh"
    
    # 終了コードが1（違反検出）であることを確認
    [ "$status" -eq 1 ]
    
    # 出力に警告が含まれることを確認
    [[ "$output" =~ "large.ts" ]]
    [[ "$output" =~ "ファイル行数超過" ]]
}

# テスト2: srp-check.sh - 環境変数でカスタマイズ可能
@test "srp-check.sh respects environment variables" {
    # 小さなファイルを作成（100行）
    cat > small.ts << 'EOF'
class SmallClass {
EOF
    for i in {1..100}; do
        echo "    method$i() { return $i; }" >> small.ts
    done
    echo "}" >> small.ts
    
    git add small.ts
    
    # 閾値を50行に設定して実行
    SRP_MAX_LINES=50 run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/srp-check.sh"
    
    # 違反が検出されることを確認
    [ "$status" -eq 1 ]
    [[ "$output" =~ "small.ts" ]]
}

# テスト3: srp-check.sh - Python版の動作確認
@test "srp-check.sh Python version works correctly" {
    # Pythonファイルを作成
    cat > large.py << 'EOF'
class LargeClass:
    """A large class with many methods"""
EOF
    for i in {1..250}; do
        echo "    def method$i(self): return $i" >> large.py
    done
    
    git add large.py
    
    # Python版スクリプトを実行
    run "$TEMPLATE_DIR/stage2/python/scripts/code-review/srp-check.sh"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "large.py" ]]
}

# ============================================================================
# file-size-check.sh のテスト
# ============================================================================

# テスト4: file-size-check.sh - 警告レベルのファイルを検出
@test "file-size-check.sh detects warning level files" {
    # 160行のファイルを作成（デフォルト警告は150行）
    echo "// Test file" > medium.ts
    for i in {1..160}; do
        echo "const line$i = $i;" >> medium.ts
    done
    
    git add medium.ts
    
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/file-size-check.sh"
    
    # 警告は出るが終了コードは0
    [ "$status" -eq 0 ]
    [[ "$output" =~ "⚠️" ]]
    [[ "$output" =~ "medium.ts" ]]
}

# テスト5: file-size-check.sh - エラーレベルのファイルを検出
@test "file-size-check.sh detects error level files" {
    # 350行のファイルを作成（デフォルトエラーは300行）
    echo "// Large file" > huge.ts
    for i in {1..350}; do
        echo "const line$i = $i;" >> huge.ts
    done
    
    git add huge.ts
    
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/file-size-check.sh"
    
    # エラーで終了コード1
    [ "$status" -eq 1 ]
    [[ "$output" =~ "❌" ]]
    [[ "$output" =~ "huge.ts" ]]
    [[ "$output" =~ "詳細分析" ]]
}

# ============================================================================
# error-handling-check.sh のテスト
# ============================================================================

# テスト6: error-handling-check.sh - console.error使用を検出
@test "error-handling-check.sh detects console.error usage" {
    cat > bad-error.ts << 'EOF'
try {
    doSomething();
} catch (error) {
    console.error('Error:', error);
}
EOF
    
    git add bad-error.ts
    
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/error-handling-check.sh"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "console.error" ]]
    [[ "$output" =~ "bad-error.ts" ]]
}

# テスト7: error-handling-check.sh - エラーの握りつぶしを検出
@test "error-handling-check.sh detects error swallowing" {
    cat > swallow-error.ts << 'EOF'
try {
    riskyOperation();
} catch (error) {
    // エラーを無視
}
EOF
    
    git add swallow-error.ts
    
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/error-handling-check.sh"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "エラーの握りつぶし" ]]
}

# ============================================================================
# console-usage-check.sh のテスト
# ============================================================================

# テスト8: console-usage-check.sh - console.log使用を検出
@test "console-usage-check.sh detects console.log usage" {
    cat > console-log.ts << 'EOF'
function debug() {
    console.log('Debug message');
    console.warn('Warning');
    console.info('Info');
}
EOF
    
    git add console-log.ts
    
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/console-usage-check.sh"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "console.log" ]]
    [[ "$output" =~ "console.warn" ]]
    [[ "$output" =~ "console.info" ]]
}

# テスト9: console-usage-check.sh - Python版でprint使用を検出
@test "console-usage-check.sh Python version detects print usage" {
    cat > print-usage.py << 'EOF'
def debug():
    print("Debug message")
    print(f"Value: {value}")
EOF
    
    git add print-usage.py
    
    run "$TEMPLATE_DIR/stage2/python/scripts/code-review/console-usage-check.sh"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "print" ]]
    [[ "$output" =~ "print-usage.py" ]]
}

# ============================================================================
# type-safety-check.sh のテスト
# ============================================================================

# テスト10: type-safety-check.sh - any型使用を検出
@test "type-safety-check.sh detects any type usage" {
    cat > any-type.ts << 'EOF'
function process(data: any): any {
    return data;
}
const result: any = getData();
EOF
    
    git add any-type.ts
    
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/type-safety-check.sh"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "any型" ]]
    [[ "$output" =~ "any-type.ts" ]]
}

# テスト11: type-safety-check.sh - ALLOW_ANYコメントを尊重
@test "type-safety-check.sh respects ALLOW_ANY comments" {
    cat > allowed-any.ts << 'EOF'
// ALLOW_ANY: 外部ライブラリの型定義が不完全なため
const result: any = externalLib.getData();
EOF
    
    git add allowed-any.ts
    
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/type-safety-check.sh"
    
    # ALLOW_ANYコメントがあるので違反にならない
    [ "$status" -eq 0 ]
}

# ============================================================================
# dependency-injection-check.sh のテスト
# ============================================================================

# テスト12: dependency-injection-check.sh - 具象クラスへの依存を検出
@test "dependency-injection-check.sh detects concrete dependencies" {
    cat > concrete-dep.ts << 'EOF'
class UserService {
    constructor(private database: PostgresDatabase) {}
}
EOF
    
    git add concrete-dep.ts
    
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/dependency-injection-check.sh"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "具象クラスへの直接依存" ]]
}

# ============================================================================
# test-analysis.sh のテスト
# ============================================================================

# テスト13: test-analysis.sh - テストファイルの不足を検出
@test "test-analysis.sh detects missing test files" {
    # 実装ファイルを作成
    mkdir -p src
    echo "export class User {}" > src/user.ts
    echo "export class Product {}" > src/product.ts
    
    # user.tsのみテストを作成
    mkdir -p src/__tests__
    echo "describe('User', () => {});" > src/__tests__/user.test.ts
    
    # package.jsonを作成（Node.jsプロジェクトとして認識させる）
    echo '{"name": "test-project"}' > package.json
    
    cd "$TEST_DIR"
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/test-analysis/test-analysis.sh"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "テストが存在しないファイル" ]]
    [[ "$output" =~ "product.ts" ]]
}

# テスト14: test-analysis.sh - Python版の動作確認
@test "test-analysis.sh Python version works correctly" {
    # Pythonファイルを作成
    echo "class User: pass" > user.py
    echo "class Product: pass" > product.py
    
    # テストディレクトリを作成
    mkdir tests
    echo "def test_user(): pass" > tests/test_user.py
    
    cd "$TEST_DIR"
    run "$TEMPLATE_DIR/stage2/python/scripts/test-analysis/test-analysis.sh"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "product.py" ]]
}

# ============================================================================
# error-handling-duplication-check.sh のテスト
# ============================================================================

# テスト15: error-handling-duplication-check.sh - console.error直接使用を検出
@test "error-handling-duplication-check.sh detects direct console.error usage" {
    cat > duplicate-error.ts << 'EOF'
try {
    operation1();
} catch (error) {
    console.error('Operation failed:', error);
}

try {
    operation2();
} catch (error) {
    console.error('Another error:', error);
}
EOF
    
    git add duplicate-error.ts
    
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/error-handling-duplication-check.sh"
    
    [ "$status" -eq 0 ]  # 警告レベルなので成功扱い
    [[ "$output" =~ "console.error" ]]
    [[ "$output" =~ "logger.error" ]]
}

# テスト16: error-handling-duplication-check.sh - 統一エラーハンドラー未使用を検出
@test "error-handling-duplication-check.sh detects missing unified error handler" {
    cat > no-handler.ts << 'EOF'
async function process() {
    try {
        await doSomething();
    } catch (error) {
        throw new Error('Failed');
    }
}
EOF
    
    git add no-handler.ts
    
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/error-handling-duplication-check.sh"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "統一エラーハンドラー未使用" ]]
    [[ "$output" =~ "withErrorHandling" ]]
}

# テスト17: error-handling-duplication-check.sh - 統一ハンドラー使用時は問題なし
@test "error-handling-duplication-check.sh passes with unified handler" {
    cat > good-handler.ts << 'EOF'
const result = await withErrorHandling(async () => {
    return await doSomething();
});
EOF
    
    git add good-handler.ts
    
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/error-handling-duplication-check.sh"
    
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "good-handler.ts" ]]
}

# ============================================================================
# layer-separation-check.sh のテスト
# ============================================================================

# テスト18: layer-separation-check.sh - サービス層でのDB直接アクセスを検出
@test "layer-separation-check.sh detects direct DB access in service layer" {
    cat > userService.ts << 'EOF'
import { Database } from 'sqlite3';

export class UserService {
    async getUser(id: string) {
        const db = new Database();
        return db.get('SELECT * FROM users WHERE id = ?', id);
    }
}
EOF
    
    git add userService.ts
    
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/layer-separation-check.sh"
    
    # サービス層のファイルでDB直接アクセスがある場合は違反
    [ "$status" -eq 1 ]
    [[ "$output" =~ "データベース直接操作" ]] || [[ "$output" =~ "SQLクエリ直接実行" ]]
    [[ "$output" =~ "userService.ts" ]]
}

# テスト19: layer-separation-check.sh - fetch直接使用を検出
@test "layer-separation-check.sh detects direct fetch usage" {
    cat > apiService.ts << 'EOF'
export class ApiService {
    async getData() {
        const response = await fetch('https://api.example.com/data');
        return response.json();
    }
}
EOF
    
    git add apiService.ts
    
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/layer-separation-check.sh"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "HTTP/API直接呼び出し" ]]
}

# テスト20: layer-separation-check.sh - 例外許可コメントを尊重
@test "layer-separation-check.sh respects ALLOW_LAYER_VIOLATION comments" {
    cat > configService.ts << 'EOF'
export class ConfigService {
    // ALLOW_LAYER_VIOLATION: 設定読み込みは直接アクセスが必要
    async loadConfig() {
        const fs = require('fs');
        return fs.readFileSync('config.json');
    }
}
EOF
    
    git add configService.ts
    
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/layer-separation-check.sh"
    
    # configServiceはサービス層のファイルとして検出され、例外許可により成功
    [ "$status" -eq 0 ]
    # 例外許可の表示があるか、検出されないか
    [[ "$output" =~ "例外許可" ]] || [[ "$output" =~ "問題なし" ]]
}

# ============================================================================
# todo-comment-check.sh のテスト
# ============================================================================

# テスト21: todo-comment-check.sh - TODOコメントを検出
@test "todo-comment-check.sh detects TODO comments" {
    cat > with-todo.ts << 'EOF'
function process() {
    // TODO: エラーハンドリングを追加
    doSomething();
    
    // FIXME: パフォーマンス問題を修正
    heavyOperation();
}
EOF
    
    git add with-todo.ts
    
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/todo-comment-check.sh"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "TODO" ]]
    [[ "$output" =~ "FIXME" ]]
    [[ "$output" =~ "with-todo.ts" ]]
}

# テスト22: todo-comment-check.sh - ALLOW_TODOコメントを尊重
@test "todo-comment-check.sh respects ALLOW_TODO comments" {
    cat > allowed-todo.ts << 'EOF'
// ALLOW_TODO: v2.0で実装予定
// TODO: 新機能を追加
function futureFeature() {
    return null;
}
EOF
    
    git add allowed-todo.ts
    
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/todo-comment-check.sh"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "例外許可" ]]
}

# テスト23: todo-comment-check.sh - TodoクラスなどTODO機能は除外
@test "todo-comment-check.sh excludes TODO feature implementations" {
    cat > todo-feature.ts << 'EOF'
export class TodoService {
    createTodo(title: string): Todo {
        return new Todo(title);
    }
}

interface TodoTask {
    id: string;
    title: string;
}
EOF
    
    git add todo-feature.ts
    
    run "$TEMPLATE_DIR/stage2/node-typescript/scripts/code-review/todo-comment-check.sh"
    
    # TODO機能の実装は検出されないはず
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "違反" ]] || [[ ! "$output" =~ "todo-feature.ts" ]]
}

# テスト24: todo-comment-check.sh - Python版も動作確認
@test "todo-comment-check.sh Python version works correctly" {
    cat > with-todo.py << 'EOF'
def process():
    # TODO: Add error handling
    do_something()
    
    # FIXME: Performance issue
    heavy_operation()
EOF
    
    git add with-todo.py
    
    run "$TEMPLATE_DIR/stage2/python/scripts/code-review/todo-comment-check.sh"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "TODO" ]]
    [[ "$output" =~ "FIXME" ]]
}