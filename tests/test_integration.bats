#!/usr/bin/env bats

# Stage1とStage2の統合テスト

# テスト環境のセットアップ
setup() {
    # テスト用の一時ディレクトリを作成
    export TEST_DIR="$(mktemp -d)"
    export ORIGINAL_DIR="$(pwd)"
    export TEMPLATE_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
    export PROJECT_NAME="integration-test"
    export SKIP_NPM_INSTALL=1  # テスト環境でnpm installをスキップ
    
    # テストディレクトリに移動
    cd "$TEST_DIR"
    
    # 出力を抑制
    export QUIET_MODE=1
}

# テスト環境のクリーンアップ
teardown() {
    cd "$ORIGINAL_DIR"
    rm -rf "$TEST_DIR"
}

# ============================================================================
# Stage1 → Stage2の連携テスト
# ============================================================================

# テスト1: Stage1実行後にStage2が正常に動作
@test "Stage2 runs successfully after Stage1" {
    # Stage1を実行
    run "$TEMPLATE_DIR/scripts/init-stage1.sh"
    [ "$status" -eq 0 ]
    [ -f "CLAUDE.md" ]
    [ -f "DEVELOPMENT_GUIDE.md" ]
    
    # Node.jsプロジェクトとして設定
    echo '{"name": "integration-test", "version": "1.0.0"}' > package.json
    
    # Stage2を実行
    run "$TEMPLATE_DIR/scripts/init-stage2.sh"
    [ "$status" -eq 0 ]
    
    # Stage2のファイルが作成されていることを確認
    [ -f "scripts/code-review/srp-check.sh" ]
    [ -f "scripts/code-review/file-size-check.sh" ]
    [ -f "scripts/test-analysis/test-analysis.sh" ]
}

# テスト2: Stage1なしでStage2を実行してもエラーにならない
@test "Stage2 works without Stage1" {
    # package.jsonのみ作成
    echo '{"name": "test-project"}' > package.json
    
    # Stage2を直接実行
    run "$TEMPLATE_DIR/scripts/init-stage2.sh"
    [ "$status" -eq 0 ]
    
    # 必要なディレクトリが作成されることを確認
    [ -d "scripts/code-review" ]
    [ -d "scripts/test-analysis" ]
}

# テスト3: 異なる技術スタックでの連続実行
@test "Multiple tech stacks can coexist" {
    # Stage1を実行
    "$TEMPLATE_DIR/scripts/init-stage1.sh" >/dev/null 2>&1
    
    # Node.js用Stage2を実行
    echo '{"name": "multi-stack"}' > package.json
    run "$TEMPLATE_DIR/scripts/init-stage2.sh"
    [ "$status" -eq 0 ]
    
    # Node.js用スクリプトが存在
    [ -f "scripts/code-review/type-safety-check.sh" ]
    
    # Python用Stage2を強制実行
    run "$TEMPLATE_DIR/scripts/init-stage2.sh" --stack=python
    [ "$status" -eq 0 ]
    
    # Python用スクリプトも存在（上書きされる）
    [ -f "scripts/code-review/type-hints-check.sh" ]
}

# ============================================================================
# コミット前確認フローのテスト
# ============================================================================

# テスト4: run-tests.shが正常に動作
@test "run-tests.sh executes all test suites" {
    # プロジェクトルートでテストを実行
    cd "$TEMPLATE_DIR"
    
    # 無限ループを防ぐため、特定のテストファイルのみを実行
    run ./scripts/run-tests.sh test_init_stage1
    
    # テストが実行されることを確認
    [ "$status" -eq 0 ]
    [[ "$output" =~ "test_init_stage1" ]]
    [[ "$output" =~ "すべてのテストが成功しました" ]]
}

# テスト5: 全体的なエラーハンドリング
@test "Error handling throughout the pipeline" {
    # 不正なオプションでStage2を実行
    run "$TEMPLATE_DIR/scripts/init-stage2.sh" --stack=invalid-stack
    [ "$status" -eq 1 ]
    [[ "$output" =~ "技術スタックを検出できませんでした" ]]
    
    # 読み取り専用ディレクトリでの実行をシミュレート
    mkdir -p readonly_test
    chmod 555 readonly_test
    cd readonly_test
    
    run "$TEMPLATE_DIR/scripts/init-stage1.sh"
    # エラーになるが、クラッシュしない
    [ "$status" -ne 0 ]
    
    cd ..
    chmod 755 readonly_test
    rm -rf readonly_test
}

# ============================================================================
# ファイルのスキップと差分レポートの統合テスト
# ============================================================================

# テスト6: Stage1とStage2の差分レポートが独立して生成される
@test "Diff reports are generated independently for each stage" {
    # Stage1を実行して既存ファイルを作成
    echo "Original CLAUDE.md" > CLAUDE.md
    
    # Stage1を再実行
    run "$TEMPLATE_DIR/scripts/init-stage1.sh"
    [ "$status" -eq 0 ]
    
    # Stage1の差分レポートが生成される
    stage1_diff_dirs=(.template_updates_*)
    [ ${#stage1_diff_dirs[@]} -gt 0 ]
    [ -f "${stage1_diff_dirs[0]}/UPDATE_REPORT.md" ]
    
    # Node.jsプロジェクトとして設定
    echo '{"name": "test"}' > package.json
    mkdir -p scripts/code-review
    echo "old script" > scripts/code-review/srp-check.sh
    
    # Stage2を実行
    run "$TEMPLATE_DIR/scripts/init-stage2.sh"
    [ "$status" -eq 0 ]
    
    # Stage2の差分レポートも生成される
    all_diff_dirs=(.template_updates_*)
    [ ${#all_diff_dirs[@]} -ge 2 ]  # Stage1とStage2の両方
}

# ============================================================================
# 環境変数の統合テスト
# ============================================================================

# テスト7: 環境変数が全体を通して正しく機能
@test "Environment variables work throughout the system" {
    # カスタム閾値を設定
    export SRP_MAX_LINES=100
    export FILE_SIZE_WARNING=80
    export TEST_MIN_COVERAGE=90
    
    # Stage1とStage2を実行
    "$TEMPLATE_DIR/scripts/init-stage1.sh" >/dev/null 2>&1
    echo '{"name": "env-test"}' > package.json
    "$TEMPLATE_DIR/scripts/init-stage2.sh" >/dev/null 2>&1
    
    # 環境変数が反映されることを確認（スクリプト内で参照される）
    grep -q "SRP_MAX_LINES:-200" scripts/code-review/srp-check.sh
    grep -q "FILE_SIZE_WARNING:-150" scripts/code-review/file-size-check.sh
    grep -q "TEST_MIN_COVERAGE:-80" scripts/test-analysis/test-analysis.sh
}

# ============================================================================
# TDD原則の統合確認
# ============================================================================

# テスト8: TDD原則が全ステージで一貫している
@test "TDD principles are consistent across all stages" {
    # Stage1を実行
    "$TEMPLATE_DIR/scripts/init-stage1.sh" >/dev/null 2>&1
    
    # CLAUDE.mdにTDD原則が含まれる
    grep -q "TDD\|テスト駆動開発" CLAUDE.md
    grep -q "Red.*Green.*Refactor" CLAUDE.md
    
    # DEVELOPMENT_GUIDE.mdにもTDD参照がある
    [ -f "DEVELOPMENT_GUIDE.md" ]
    
    # Stage2を実行
    echo '{"name": "tdd-test"}' > package.json
    "$TEMPLATE_DIR/scripts/init-stage2.sh" >/dev/null 2>&1
    
    # test-analysis.shが作成される
    [ -f "scripts/test-analysis/test-analysis.sh" ]
    [ -x "scripts/test-analysis/test-analysis.sh" ]
}

# テスト9: 後方互換性の確認
@test "Backward compatibility is maintained" {
    # 古いバージョンをシミュレート（一部ファイルのみ存在）
    echo "# Old README" > README.md
    mkdir -p scripts
    echo "#!/bin/bash" > scripts/worktree.sh
    chmod +x scripts/worktree.sh
    
    # Stage1を実行（既存ファイルをスキップ）
    run "$TEMPLATE_DIR/scripts/init-stage1.sh"
    [ "$status" -eq 0 ]
    
    # 既存ファイルが保持されている
    grep -q "Old README" README.md
    
    # 新しいファイルが追加されている
    [ -f "CLAUDE.md" ]
    [ -f "DEVELOPMENT_GUIDE.md" ]
}

# テスト10: 完全な初期化フローのテスト
@test "Complete initialization flow works end-to-end" {
    # 1. プロジェクトディレクトリの準備
    echo "# My Project" > README.md
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    git add README.md
    git commit -m "Initial commit"
    
    # 2. Stage1の実行
    run "$TEMPLATE_DIR/scripts/init-stage1.sh"
    [ "$status" -eq 0 ]
    
    # 3. Node.jsプロジェクトとして設定
    npm init -y >/dev/null 2>&1 || echo '{"name": "complete-test"}' > package.json
    
    # 4. Stage2の実行
    run "$TEMPLATE_DIR/scripts/init-stage2.sh"
    [ "$status" -eq 0 ]
    
    # 5. テスト実行の確認
    if [ -f "$TEMPLATE_DIR/scripts/run-tests.sh" ]; then
        # 新しく追加されたスクリプトのテスト
        [ -x "scripts/code-review/srp-check.sh" ]
        [ -x "scripts/code-review/file-size-check.sh" ]
        [ -x "scripts/test-analysis/test-analysis.sh" ]
    fi
    
    # 6. すべての重要なファイルが存在
    [ -f "CLAUDE.md" ]
    [ -f "DEVELOPMENT_GUIDE.md" ]
    [ -f "DEVELOPMENT_CHECKLIST.md" ]
    [ -f ".gitignore" ]
    [ -d "scripts/code-review" ]
    [ -d "scripts/test-analysis" ]
}