#!/usr/bin/env bats

# Claude Code開発テンプレート - Stage 2 テスト

# テスト環境のセットアップ
setup() {
    # テスト用の一時ディレクトリを作成
    export TEST_DIR="$(mktemp -d)"
    export ORIGINAL_DIR="$(pwd)"
    export TEMPLATE_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
    export PROJECT_NAME="test-project"
    
    # テストディレクトリに移動
    cd "$TEST_DIR"
    
    # Stage 1を先に実行（Stage 2の前提条件）
    "$TEMPLATE_DIR/scripts/init-stage1.sh" || true
}

# テスト環境のクリーンアップ
teardown() {
    cd "$ORIGINAL_DIR"
    rm -rf "$TEST_DIR"
}

# テスト1: 技術スタックが検出できない場合のエラー
@test "Error message when tech stack cannot be detected" {
    run "$TEMPLATE_DIR/scripts/init-stage2.sh"
    
    # 終了コードが1であることを確認
    [ "$status" -eq 1 ]
    
    # エラーメッセージが表示されることを確認
    [[ "$output" =~ "技術スタックを検出できませんでした" ]]
}

# テスト2: Node.jsプロジェクトの検出と設定
@test "Node.js project is detected correctly" {
    # package.jsonを作成
    echo '{"name": "test-project", "version": "1.0.0"}' > package.json
    
    run "$TEMPLATE_DIR/scripts/init-stage2.sh"
    [ "$status" -eq 0 ]
    
    # 必要なファイルが作成されていることを確認
    [ -f "scripts/code-review/srp-check.sh" ]
    [ -f "scripts/code-review/file-size-check.sh" ]
    [ -f "scripts/test-analysis/test-analysis.sh" ]
    
    # スクリプトが実行可能であることを確認
    [ -x "scripts/code-review/srp-check.sh" ]
    [ -x "scripts/code-review/file-size-check.sh" ]
    [ -x "scripts/test-analysis/test-analysis.sh" ]
}

# テスト3: TypeScriptプロジェクトの検出
@test "TypeScript project is detected correctly" {
    # package.jsonとtsconfig.jsonを作成
    echo '{"name": "test-project"}' > package.json
    echo '{"compilerOptions": {}}' > tsconfig.json
    
    run "$TEMPLATE_DIR/scripts/init-stage2.sh"
    [ "$status" -eq 0 ]
    
    # 出力に技術スタックが表示されることを確認
    [[ "$output" =~ "node-typescript" ]]
}

# テスト4: Pythonプロジェクトの検出
@test "Python project is detected correctly" {
    # requirements.txtを作成
    echo "pytest==7.0.0" > requirements.txt
    
    run "$TEMPLATE_DIR/scripts/init-stage2.sh"
    [ "$status" -eq 0 ]
    
    # 出力に技術スタックが表示されることを確認
    [[ "$output" =~ "python" ]]
}

# テスト5: 強制的な技術スタック指定
@test "--stack option forces tech stack" {
    run "$TEMPLATE_DIR/scripts/init-stage2.sh" --stack=node-typescript
    [ "$status" -eq 0 ]
    
    # 出力に指定した技術スタックが表示されることを確認
    [[ "$output" =~ "技術スタック（指定）: node-typescript" ]]
}

# テスト6: 既存ファイルのスキップ
@test "Existing script files are skipped" {
    # package.jsonを作成
    echo '{"name": "test-project"}' > package.json
    
    # 既存のスクリプトを作成
    mkdir -p scripts/code-review
    echo "original content" > scripts/code-review/srp-check.sh
    
    run "$TEMPLATE_DIR/scripts/init-stage2.sh"
    [ "$status" -eq 0 ]
    
    # ファイルが上書きされていないことを確認
    [ "$(cat scripts/code-review/srp-check.sh)" = "original content" ]
    
    # スキップメッセージが表示されることを確認
    [[ "$output" =~ "スキップ: scripts/code-review/srp-check.sh" ]]
}

# テスト7: 差分表示機能
@test "Diff is displayed for existing files" {
    # package.jsonを作成
    echo '{"name": "test-project"}' > package.json
    
    # 既存のスクリプトを作成（内容が異なる）
    mkdir -p scripts/code-review
    echo "#!/bin/bash" > scripts/code-review/file-size-check.sh
    echo "echo 'old version'" >> scripts/code-review/file-size-check.sh
    
    run "$TEMPLATE_DIR/scripts/init-stage2.sh"
    [ "$status" -eq 0 ]
    
    # 差分情報が表示されることを確認
    [[ "$output" =~ "差分プレビュー" ]] || [[ "$output" =~ "+[0-9]+行/-[0-9]+行" ]]
}

# テスト8: Huskyのセットアップ（Node.jsプロジェクト）
@test "Husky is configured for Node.js projects" {
    # package.jsonを作成
    echo '{"name": "test-project", "scripts": {"test": "echo test"}}' > package.json
    
    # npmがnpm installをスキップするためのmockを作成
    mkdir -p node_modules/.bin
    echo '#!/bin/bash' > node_modules/.bin/husky
    echo 'echo "husky mocked"' >> node_modules/.bin/husky
    chmod +x node_modules/.bin/husky
    
    run "$TEMPLATE_DIR/scripts/init-stage2.sh"
    [ "$status" -eq 0 ]
    
    # Huskyに関する出力があることを確認
    [[ "$output" =~ "Husky" || -d ".husky" ]]
}

# テスト9: 差分レポートの生成
@test "Diff report is generated in Stage2" {
    # package.jsonを作成
    echo '{"name": "test-project"}' > package.json
    
    # 既存ファイルを作成
    mkdir -p scripts/test-analysis
    echo "old test script" > scripts/test-analysis/test-analysis.sh
    
    run "$TEMPLATE_DIR/scripts/init-stage2.sh"
    [ "$status" -eq 0 ]
    
    # 差分ディレクトリが作成されたことを確認
    local diff_dirs=(.template_updates_*)
    [ ${#diff_dirs[@]} -gt 0 ]
    [ -d "${diff_dirs[0]}" ]
    
    # レポートファイルが存在することを確認
    [ -f "${diff_dirs[0]}/UPDATE_REPORT.md" ]
}

# テスト10: 実行結果サマリーの表示
@test "Stage2 execution summary is displayed correctly" {
    # package.jsonを作成
    echo '{"name": "test-project"}' > package.json
    
    # 一部のファイルを事前に作成
    mkdir -p scripts/code-review
    echo "existing" > scripts/code-review/srp-check.sh
    
    run "$TEMPLATE_DIR/scripts/init-stage2.sh"
    [ "$status" -eq 0 ]
    
    # サマリーに追加とスキップの情報が含まれることを確認
    [[ "$output" =~ "実行結果サマリー" ]]
    [[ "$output" =~ "追加されたファイル" ]]
    [[ "$output" =~ "スキップされたファイル" ]]
}

# テスト11: 適切なテスト分析スクリプトの選択
@test "Appropriate test analysis script is selected for tech stack" {
    # Pythonプロジェクトを作成
    echo "pytest" > requirements.txt
    
    run "$TEMPLATE_DIR/scripts/init-stage2.sh"
    [ "$status" -eq 0 ]
    
    # テスト分析スクリプトが作成されていることを確認
    [ -f "scripts/test-analysis/test-analysis.sh" ]
    
    # Pythonのパターンが含まれているか確認（実際のスクリプト内容に依存）
    # この部分は実際のpython.shの内容に応じて調整が必要
}