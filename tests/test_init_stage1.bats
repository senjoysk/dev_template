#!/usr/bin/env bats

# Claude Code開発テンプレート - Stage 1 テスト

# テスト環境のセットアップ
setup() {
    # テスト用の一時ディレクトリを作成
    export TEST_DIR="$(mktemp -d)"
    export ORIGINAL_DIR="$(pwd)"
    export TEMPLATE_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
    export PROJECT_NAME="test-project"
    
    # テストディレクトリに移動
    cd "$TEST_DIR"
    
    # 出力を抑制するためのフラグ
    export QUIET_MODE=1
}

# テスト環境のクリーンアップ
teardown() {
    cd "$ORIGINAL_DIR"
    rm -rf "$TEST_DIR"
}

# ヘルパー関数: ファイルの行数をカウント
count_lines() {
    wc -l < "$1" | tr -d ' '
}

# テスト1: 新規プロジェクトでStage1が正常に実行される
@test "Stage1 runs successfully on new project" {
    run "$TEMPLATE_DIR/scripts/init-stage1.sh"
    
    # 終了コードが0であることを確認
    [ "$status" -eq 0 ]
    
    # 必要なファイルが作成されていることを確認
    [ -f "CLAUDE.md" ]
    [ -f "DEVELOPMENT_GUIDE.md" ]
    [ -f "DEVELOPMENT_CHECKLIST.md" ]
    [ -f "README.md" ]
    [ -f ".gitignore" ]
    [ -f "scripts/worktree.sh" ]
    
    # スクリプトが実行可能であることを確認
    [ -x "scripts/worktree.sh" ]
}

# テスト2: 既存ファイルがスキップされる
@test "Existing files are skipped without overwriting" {
    # 既存ファイルを作成
    echo "original content" > CLAUDE.md
    echo "original readme" > README.md
    
    # スクリプトを実行
    run "$TEMPLATE_DIR/scripts/init-stage1.sh"
    [ "$status" -eq 0 ]
    
    # ファイルが上書きされていないことを確認
    [ "$(cat CLAUDE.md)" = "original content" ]
    [ "$(cat README.md)" = "original readme" ]
    
    # 出力にスキップメッセージが含まれることを確認
    [[ "$output" =~ "スキップ: CLAUDE.md" ]]
    [[ "$output" =~ "スキップ: README.md" ]]
}

# テスト3: プロジェクト名が正しく処理される
@test "Project name is correctly reflected in templates" {
    run "$TEMPLATE_DIR/scripts/init-stage1.sh"
    [ "$status" -eq 0 ]
    
    # README.mdに実際のディレクトリ名が含まれていることを確認
    # スクリプトはbasename "$PWD"を使用するため
    local actual_project_name=$(basename "$TEST_DIR")
    grep -q "$actual_project_name" README.md
}

# テスト4: 実行結果サマリーが表示される
@test "Execution summary displays correct information" {
    # 一部のファイルを事前に作成
    echo "existing" > CLAUDE.md
    
    run "$TEMPLATE_DIR/scripts/init-stage1.sh"
    [ "$status" -eq 0 ]
    
    # サマリーに追加とスキップの情報が含まれることを確認
    [[ "$output" =~ "追加されたファイル" ]]
    [[ "$output" =~ "スキップされたファイル" ]]
    [[ "$output" =~ "CLAUDE.md (既存ファイル)" ]]
}

# テスト5: 差分情報が表示される
@test "Diff information is displayed for existing files" {
    # 既存ファイルを作成（テンプレートとは異なる内容）
    echo "old content" > DEVELOPMENT_GUIDE.md
    
    run "$TEMPLATE_DIR/scripts/init-stage1.sh"
    [ "$status" -eq 0 ]
    
    # 差分情報が表示されることを確認
    [[ "$output" =~ "差分プレビュー" ]] || [[ "$output" =~ "+[0-9]+行/-[0-9]+行" ]]
}

# テスト6: 差分レポートが生成される
@test "Diff report directory is created" {
    # 既存ファイルを作成
    mkdir -p scripts
    echo "old script" > scripts/worktree.sh
    
    run "$TEMPLATE_DIR/scripts/init-stage1.sh"
    [ "$status" -eq 0 ]
    
    # 差分ディレクトリが作成されたことを確認
    local diff_dirs=(.template_updates_*)
    [ ${#diff_dirs[@]} -gt 0 ]
    [ -d "${diff_dirs[0]}" ]
    
    # レポートファイルが存在することを確認
    [ -f "${diff_dirs[0]}/UPDATE_REPORT.md" ]
}

# テスト7: 新バージョンファイルが保存される
@test "New version files are saved for skipped files" {
    # 既存ファイルを作成
    echo "old content" > README.md
    
    run "$TEMPLATE_DIR/scripts/init-stage1.sh"
    [ "$status" -eq 0 ]
    
    # 差分ディレクトリを取得
    local diff_dirs=(.template_updates_*)
    [ ${#diff_dirs[@]} -gt 0 ]
    
    # 新バージョンファイルが存在することを確認
    [ -f "${diff_dirs[0]}/README.md.new" ]
    
    # 新バージョンに実際のディレクトリ名が含まれることを確認
    local actual_project_name=$(basename "$TEST_DIR")
    grep -q "$actual_project_name" "${diff_dirs[0]}/README.md.new"
}

# テスト8: 差分ファイルが生成される
@test "Diff files are generated correctly" {
    # 既存ファイルを作成
    echo "# Old Title" > README.md
    
    run "$TEMPLATE_DIR/scripts/init-stage1.sh"
    [ "$status" -eq 0 ]
    
    # 差分ディレクトリを取得
    local diff_dirs=(.template_updates_*)
    [ ${#diff_dirs[@]} -gt 0 ]
    
    # 差分ファイルが存在することを確認
    [ -f "${diff_dirs[0]}/README.md.diff" ]
    
    # 差分ファイルに+/-が含まれることを確認
    grep -E "^[+-]" "${diff_dirs[0]}/README.md.diff"
}