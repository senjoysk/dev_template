#!/bin/bash

# Claude Code開発テンプレート - テスト実行スクリプト

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TESTS_DIR="$PROJECT_DIR/tests"

# 色付きログ用の定数
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Claude Code開発テンプレート - テスト実行${NC}"
echo ""

# Batsがインストールされているか確認
check_bats() {
    if ! command -v bats &> /dev/null; then
        echo -e "${RED}❌ Batsがインストールされていません${NC}"
        echo ""
        echo "Batsをインストールしてください:"
        echo ""
        echo "  # macOS (Homebrew)"
        echo "  brew install bats-core"
        echo ""
        echo "  # npm"
        echo "  npm install -g bats"
        echo ""
        echo "  # その他のインストール方法"
        echo "  https://github.com/bats-core/bats-core#installation"
        echo ""
        exit 1
    fi
    
    echo -e "${GREEN}✅ Bats $(bats --version | head -1)${NC}"
    echo ""
}

# テストファイルの存在確認
check_test_files() {
    if [ ! -d "$TESTS_DIR" ]; then
        echo -e "${RED}❌ テストディレクトリが見つかりません: $TESTS_DIR${NC}"
        exit 1
    fi
    
    local test_files=("$TESTS_DIR"/*.bats)
    if [ ${#test_files[@]} -eq 0 ]; then
        echo -e "${RED}❌ テストファイルが見つかりません${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}📋 テストファイル:${NC}"
    for file in "${test_files[@]}"; do
        echo "   - $(basename "$file")"
    done
    echo ""
}

# テスト実行
run_tests() {
    local test_pattern="$1"
    
    # 文字エンコーディングを明示的に設定
    export LC_ALL=C.UTF-8
    export LANG=C.UTF-8
    
    if [ -n "$test_pattern" ]; then
        echo -e "${BLUE}🔍 パターンに一致するテストを実行: $test_pattern${NC}"
        echo ""
        bats "$TESTS_DIR"/*"$test_pattern"*.bats 2>&1 | iconv -f utf-8 -t utf-8 -c
    else
        echo -e "${BLUE}🏃 すべてのテストを実行${NC}"
        echo ""
        bats "$TESTS_DIR"/*.bats 2>&1 | iconv -f utf-8 -t utf-8 -c
    fi
}

# ヘルプメッセージ
show_help() {
    echo "使い方: $0 [オプション] [テストパターン]"
    echo ""
    echo "オプション:"
    echo "  -h, --help      このヘルプを表示"
    echo "  -v, --verbose   詳細な出力を表示"
    echo "  -t, --tap       TAP形式で出力"
    echo ""
    echo "例:"
    echo "  $0                    # すべてのテストを実行"
    echo "  $0 stage1             # 'stage1'を含むテストファイルを実行"
    echo "  $0 -v                 # 詳細モードですべてのテストを実行"
    echo ""
}

# メイン処理
main() {
    local test_pattern=""
    local bats_options=""
    
    # オプション解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                bats_options="$bats_options --verbose-run"
                shift
                ;;
            -t|--tap)
                bats_options="$bats_options --tap"
                shift
                ;;
            *)
                test_pattern="$1"
                shift
                ;;
        esac
    done
    
    # Batsの確認
    check_bats
    
    # テストファイルの確認
    check_test_files
    
    # テスト実行
    if [ -n "$bats_options" ]; then
        export BATS_OPTIONS="$bats_options"
    fi
    
    # 実行時間の計測開始
    start_time=$(date +%s)
    
    # テスト実行
    if run_tests "$test_pattern"; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        
        echo ""
        echo -e "${GREEN}✅ すべてのテストが成功しました！${NC}"
        echo -e "${BLUE}⏱️  実行時間: ${duration}秒${NC}"
        exit 0
    else
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        
        echo ""
        echo -e "${RED}❌ テストが失敗しました${NC}"
        echo -e "${BLUE}⏱️  実行時間: ${duration}秒${NC}"
        exit 1
    fi
}

# エントリーポイント
main "$@"