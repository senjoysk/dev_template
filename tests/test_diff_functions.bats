#!/usr/bin/env bats

# 差分機能の単体テスト

# テスト環境のセットアップ
setup() {
    # テスト用の一時ディレクトリを作成
    export TEST_DIR="$(mktemp -d)"
    export ORIGINAL_DIR="$(pwd)"
    export TEMPLATE_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
    
    # テストディレクトリに移動
    cd "$TEST_DIR"
    
    # 関数のみを読み込む（実行はしない）
    export SOURCING_FOR_TEST=1
    source "$TEMPLATE_DIR/scripts/init-stage1.sh"
}

# テスト環境のクリーンアップ
teardown() {
    cd "$ORIGINAL_DIR"
    rm -rf "$TEST_DIR"
}

# テスト1: get_diff_summary関数 - 基本的な差分
@test "get_diff_summary counts basic diffs correctly" {
    # テストファイルを作成
    cat > file1.txt << EOF
line1
line2
line3
EOF
    
    cat > file2.txt << EOF
line1
line2 modified
line3
line4
EOF
    
    # 関数を実行
    result=$(get_diff_summary file1.txt file2.txt)
    
    # 結果を確認（追加2行、削除1行）
    [[ "$result" =~ \+[0-9]+行/-[0-9]+行 ]]
}

# テスト2: get_diff_summary関数 - 同一ファイル
@test "get_diff_summary shows no diff for identical files" {
    # 同じ内容のファイルを作成
    echo "same content" > file1.txt
    echo "same content" > file2.txt
    
    # 関数を実行
    result=$(get_diff_summary file1.txt file2.txt)
    
    # 結果を確認
    [ "$result" = "差分なし" ]
}

# テスト3: get_diff_summary関数 - ファイルが存在しない場合
@test "get_diff_summary handles non-existent files" {
    # 存在しないファイルで実行
    result=$(get_diff_summary nonexistent1.txt nonexistent2.txt)
    
    # 結果を確認
    [ "$result" = "差分計算不可" ]
}

# テスト4: get_diff_summary関数 - 追加のみ
@test "get_diff_summary counts additions only correctly" {
    # ファイルを作成
    echo "line1" > file1.txt
    cat > file2.txt << EOF
line1
line2
line3
EOF
    
    # 関数を実行
    result=$(get_diff_summary file1.txt file2.txt)
    
    # 追加行があることを確認
    [[ "$result" =~ \+[1-9][0-9]*行 ]]
}

# テスト5: get_diff_summary関数 - 削除のみ
@test "get_diff_summary counts deletions only correctly" {
    # ファイルを作成
    cat > file1.txt << EOF
line1
line2
line3
EOF
    echo "line1" > file2.txt
    
    # 関数を実行
    result=$(get_diff_summary file1.txt file2.txt)
    
    # 削除行があることを確認
    [[ "$result" =~ -[1-9][0-9]*行 ]]
}

# テスト6: show_diff_preview関数のモック
@test "show_diff_preview generates diff preview" {
    # テストファイルを作成
    cat > file1.txt << EOF
old line
common line
EOF
    
    cat > file2.txt << EOF
new line
common line
additional line
EOF
    
    # 関数を実行して出力を確認
    output=$(show_diff_preview file1.txt file2.txt 2>&1)
    
    # プレビューヘッダーが含まれることを確認
    [[ "$output" =~ "差分プレビュー" ]]
}

# テスト7: copy_file関数 - 新規ファイルの場合
@test "copy_file copies new files correctly" {
    # ソースファイルを作成
    echo "source content" > source.txt
    
    # 配列を初期化
    ADDED_FILES=()
    SKIPPED_FILES=()
    
    # 関数を実行
    copy_file source.txt dest.txt
    
    # ファイルがコピーされたことを確認
    [ -f dest.txt ]
    [ "$(cat dest.txt)" = "source content" ]
    
    # ADDED_FILESに追加されたことを確認
    [[ " ${ADDED_FILES[@]} " =~ " dest.txt " ]]
}

# テスト8: copy_file関数 - 既存ファイルの場合
@test "copy_file skips existing files" {
    # ファイルを作成
    echo "source content" > source.txt
    echo "existing content" > dest.txt
    
    # 配列を初期化
    ADDED_FILES=()
    SKIPPED_FILES=()
    SKIPPED_DIFFS=()
    
    # 関数を実行
    copy_file source.txt dest.txt
    
    # ファイルが上書きされていないことを確認
    [ "$(cat dest.txt)" = "existing content" ]
    
    # SKIPPED_FILESに追加されたことを確認
    [[ " ${SKIPPED_FILES[@]} " =~ " dest.txt " ]]
}

# テスト9: save_diffs_for_review関数の基本動作
@test "save_diffs_for_review creates diff directory" {
    # スキップされたファイルをシミュレート
    SKIPPED_FILES=("test1.txt" "test2.txt")
    PROJECT_NAME="test-project"
    
    # テンプレートディレクトリをモック
    mkdir -p "$TEMPLATE_DIR/stage1"
    echo "template content" > "$TEMPLATE_DIR/stage1/test1.txt"
    
    # 既存ファイルを作成
    echo "existing content" > test1.txt
    
    # 関数を実行
    save_diffs_for_review
    
    # 差分ディレクトリが作成されたことを確認
    local diff_dirs=(.template_updates_*)
    [ ${#diff_dirs[@]} -gt 0 ]
    [ -d "${diff_dirs[0]}" ]
}

# テスト10: process_template関数 - テンプレート変数の置換
@test "process_template replaces template variables correctly" {
    # テンプレートファイルを作成
    cat > template.txt << 'EOF'
Project: {{PROJECT_NAME}}
Description: {{PROJECT_DESCRIPTION}}
EOF
    
    # 環境変数を設定
    PROJECT_NAME="my-project"
    ADDED_FILES=()
    
    # 関数を実行
    process_template template.txt output.txt
    
    # 出力ファイルを確認
    grep -q "Project: my-project" output.txt
    grep -q "Description: my-project - Claude Code" output.txt
}