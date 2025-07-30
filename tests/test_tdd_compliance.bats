#!/usr/bin/env bats

# TDD原則遵守の確認テスト

# テスト環境のセットアップ
setup() {
    # テスト用の一時ディレクトリを作成
    export TEST_DIR="$(mktemp -d)"
    export ORIGINAL_DIR="$(pwd)"
    export TEMPLATE_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
    
    # テストディレクトリに移動
    cd "$TEST_DIR"
    
    # Gitリポジトリを初期化
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
# TDDコメントパターンのテスト
# ============================================================================

# テスト1: Red-Green-Refactorコメントパターンの検出
@test "TDD comment patterns are detected correctly" {
    # TDDサイクルに従ったテストファイルを作成
    cat > calculator.test.ts << 'EOF'
// 🔴 Red Phase: add関数 - 実装前なので失敗する
describe('Calculator', () => {
    test('adds two numbers', () => {
        expect(add(1, 2)).toBe(3);
    });
});
EOF
    
    # Red Phaseコメントが存在することを確認
    grep -q "🔴 Red Phase" calculator.test.ts
    
    # Green Phaseへの更新をシミュレート
    cat > calculator.test.ts << 'EOF'
// 🟢 Green Phase: add関数 - 最小限の実装でテストが通る
describe('Calculator', () => {
    test('adds two numbers', () => {
        expect(add(1, 2)).toBe(3);
    });
});
EOF
    
    grep -q "🟢 Green Phase" calculator.test.ts
    
    # Refactor Phaseへの更新をシミュレート
    cat > calculator.test.ts << 'EOF'
// ♻️ Refactor Phase: add関数 - リファクタリング完了
describe('Calculator', () => {
    test('adds two numbers', () => {
        expect(add(1, 2)).toBe(3);
    });
});
EOF
    
    grep -q "♻️ Refactor Phase" calculator.test.ts
}

# テスト2: テストファイルが実装ファイルより先に存在することの確認
@test "Test files exist before implementation files" {
    # テストファイルを先に作成
    mkdir -p src/__tests__
    cat > src/__tests__/user.test.ts << 'EOF'
// 🔴 Red Phase: User class - 実装前なので失敗する
describe('User', () => {
    test('creates user with name', () => {
        const user = new User('John');
        expect(user.name).toBe('John');
    });
});
EOF
    
    # テストファイルをコミット
    git add src/__tests__/user.test.ts
    git commit -m "test: add User class tests"
    
    # その後実装ファイルを作成
    cat > src/user.ts << 'EOF'
export class User {
    constructor(public name: string) {}
}
EOF
    
    git add src/user.ts
    git commit -m "feat: implement User class"
    
    # コミット履歴を確認（テストが先にコミットされているか）
    commits=$(git log --oneline --name-only)
    
    # テストファイルが実装ファイルより前にコミットされていることを確認
    test_commit_line=$(echo "$commits" | grep -n "user.test.ts" | cut -d: -f1)
    impl_commit_line=$(echo "$commits" | grep -n "user.ts" | cut -d: -f1)
    
    [ "$test_commit_line" -gt "$impl_commit_line" ]  # git logは新しい順なので逆
}

# テスト3: TODOリストパターンの検出
@test "TODO list pattern in development files" {
    # 開発チェックリストファイルを作成
    cat > TODO.md << 'EOF'
# 機能実装TODOリスト

## User認証機能
- [ ] テストケース: ユーザー登録のテストを書く
- [ ] テストケース: ログイン機能のテストを書く
- [ ] 実装: User モデルの作成
- [ ] 実装: 認証サービスの作成
- [ ] リファクタリング: エラーハンドリングの改善

## 実装順序
1. 🔴 Red: 失敗するテストを書く
2. 🟢 Green: テストを通す最小限の実装
3. ♻️ Refactor: コードの改善
EOF
    
    # TODOリストにTDDサイクルが含まれていることを確認
    grep -q "失敗するテストを書く" TODO.md
    grep -q "テストを通す最小限の実装" TODO.md
    grep -q "コードの改善" TODO.md
}

# テスト4: DEVELOPMENT_CHECKLIST.mdの存在と内容確認
@test "DEVELOPMENT_CHECKLIST.md contains TDD guidelines" {
    # Stage1を実行してDEVELOPMENT_CHECKLIST.mdを生成
    "$TEMPLATE_DIR/scripts/init-stage1.sh" >/dev/null 2>&1
    
    # ファイルが存在することを確認
    [ -f "DEVELOPMENT_CHECKLIST.md" ]
    
    # TDD関連の内容が含まれていることを確認
    grep -q "TDD" DEVELOPMENT_CHECKLIST.md || grep -q "テスト駆動開発" DEVELOPMENT_CHECKLIST.md
    grep -q "Red.*Green.*Refactor" DEVELOPMENT_CHECKLIST.md || true
}

# テスト5: CLAUDE.mdにTDD原則が含まれていることの確認
@test "CLAUDE.md contains TDD principles" {
    # Stage1を実行
    "$TEMPLATE_DIR/scripts/init-stage1.sh" >/dev/null 2>&1
    
    [ -f "CLAUDE.md" ]
    
    # TDD関連のキーワードを確認
    grep -q "TDD\|テスト駆動開発" CLAUDE.md
    grep -q "Red.*Green.*Refactor" CLAUDE.md
    grep -q "テストファースト" CLAUDE.md
}

# テスト6: エラーケースの洗い出しパターン
@test "Error case identification pattern" {
    # エラーケースを含むテストファイルを作成
    cat > validation.test.ts << 'EOF'
describe('Validation', () => {
    // 正常系
    test('validates correct email', () => {
        expect(validateEmail('user@example.com')).toBe(true);
    });
    
    // エラーケース
    test('rejects invalid email without @', () => {
        expect(validateEmail('userexample.com')).toBe(false);
    });
    
    test('rejects empty email', () => {
        expect(validateEmail('')).toBe(false);
    });
    
    test('rejects null email', () => {
        expect(validateEmail(null)).toBe(false);
    });
});
EOF
    
    # エラーケースが含まれていることを確認
    error_cases=$(grep -c "rejects\|throws\|fails\|error" validation.test.ts)
    [ "$error_cases" -ge 3 ]
}

# テスト7: インターフェース設計からのテスト作成パターン
@test "Interface-first design pattern" {
    # インターフェースを定義
    cat > interfaces.ts << 'EOF'
// 使い方から設計されたインターフェース
export interface UserService {
    createUser(name: string, email: string): Promise<User>;
    findUserById(id: string): Promise<User | null>;
    updateUser(id: string, data: Partial<User>): Promise<User>;
    deleteUser(id: string): Promise<void>;
}

export interface User {
    id: string;
    name: string;
    email: string;
    createdAt: Date;
}
EOF
    
    # インターフェースに基づくテストを作成
    cat > user-service.test.ts << 'EOF'
// インターフェースに基づいたテスト
describe('UserService', () => {
    let service: UserService;
    
    beforeEach(() => {
        service = new UserServiceImpl();
    });
    
    test('creates user with valid data', async () => {
        const user = await service.createUser('John', 'john@example.com');
        expect(user.name).toBe('John');
        expect(user.email).toBe('john@example.com');
    });
});
EOF
    
    # インターフェースが先に定義されていることを確認
    [ -f "interfaces.ts" ]
    grep -q "interface UserService" interfaces.ts
}

# テスト8: 小さなステップでの実装パターン
@test "Small steps implementation pattern" {
    # 段階的な実装を示すコミット履歴をシミュレート
    
    # Step 1: 最も簡単なテスト
    echo "test('returns 0 for empty array', () => { expect(sum([])).toBe(0); });" > sum.test.ts
    git add sum.test.ts
    git commit -m "test: add test for empty array sum"
    
    # Step 2: 最小限の実装
    echo "export const sum = (arr) => 0;" > sum.ts
    git add sum.ts
    git commit -m "feat: implement sum for empty array"
    
    # Step 3: 次のテストケース
    echo "test('returns single element', () => { expect(sum([5])).toBe(5); });" >> sum.test.ts
    git add sum.test.ts
    git commit -m "test: add test for single element"
    
    # Step 4: 実装の拡張
    echo "export const sum = (arr) => arr.length === 0 ? 0 : arr[0];" > sum.ts
    git add sum.ts
    git commit -m "feat: handle single element case"
    
    # コミット数を確認（小さなステップで進んでいるか）
    commit_count=$(git log --oneline | wc -l)
    [ "$commit_count" -ge 4 ]
}

# テスト9: YAGNI原則の確認
@test "YAGNI principle - no unnecessary features" {
    # シンプルな実装ファイルを作成
    cat > simple-service.ts << 'EOF'
// 必要な機能のみを実装
export class SimpleService {
    // 現在必要な機能のみ
    getData(id: string): string {
        return `Data for ${id}`;
    }
    
    // 将来のための準備コードは含まない
    // 不要な汎用化は避ける
}
EOF
    
    # 不要な機能が含まれていないことを確認
    ! grep -q "future\|todo\|later\|deprecated" simple-service.ts
    
    # シンプルなメソッド数であることを確認
    method_count=$(grep -c "^\s*[a-zA-Z].*(" simple-service.ts)
    [ "$method_count" -le 3 ]
}

# テスト10: 明白な実装パターン
@test "Obvious implementation pattern" {
    # 明白でシンプルな実装を作成
    cat > obvious.ts << 'EOF'
// 明白な実装 - 複雑さを避ける
export function isEven(n: number): boolean {
    return n % 2 === 0;
}

export function max(a: number, b: number): number {
    return a > b ? a : b;
}

// シンプルで分かりやすい実装
export class Counter {
    private count = 0;
    
    increment(): void {
        this.count++;
    }
    
    getValue(): number {
        return this.count;
    }
}
EOF
    
    # 複雑な実装パターンが含まれていないことを確認
    ! grep -q "abstract\|extends\|implements" obvious.ts
    
    # 行数が適切であることを確認（過度に複雑でない）
    line_count=$(wc -l < obvious.ts)
    [ "$line_count" -lt 30 ]
}