#!/bin/bash

# テスト分析スクリプト - Python版
# テストカバレッジ、テストの品質、TDD実践状況を分析

echo "🧪 テスト分析開始..."
echo ""

# 色の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 設定可能な閾値（環境変数で上書き可能）
MIN_COVERAGE="${TEST_MIN_COVERAGE:-80}"
MIN_TEST_RATIO="${TEST_MIN_RATIO:-0.8}"  # テストコード/実装コードの比率

# 結果を格納する変数
TOTAL_IMPL_FILES=0
TOTAL_TEST_FILES=0
MISSING_TESTS=()
LOW_COVERAGE_FILES=()
TDD_VIOLATIONS=()

# 実装ファイルとテストファイルの対応をチェック
echo "📂 ファイル構造分析..."

# 実装ファイルを検索（Python）
IMPL_FILES=$(find . -name "*.py" | \
    grep -v __pycache__ | \
    grep -v test_ | \
    grep -v _test.py | \
    grep -v conftest.py | \
    grep -v setup.py | \
    grep -v tests/ | \
    sort)

# 各実装ファイルに対してテストファイルの存在を確認
for impl_file in $IMPL_FILES; do
    if [ -f "$impl_file" ]; then
        TOTAL_IMPL_FILES=$((TOTAL_IMPL_FILES + 1))
        
        # テストファイルのパスパターンを生成
        base_name=$(basename "$impl_file" .py)
        dir_name=$(dirname "$impl_file")
        
        # 可能なテストファイルパス
        test_patterns=(
            "tests/test_${base_name}.py"
            "tests/${dir_name#./}/test_${base_name}.py"
            "${dir_name}/test_${base_name}.py"
            "${dir_name}/tests/test_${base_name}.py"
            "test_${base_name}.py"
            "${dir_name}/${base_name}_test.py"
        )
        
        test_found=false
        for test_file in "${test_patterns[@]}"; do
            if [ -f "$test_file" ]; then
                test_found=true
                TOTAL_TEST_FILES=$((TOTAL_TEST_FILES + 1))
                break
            fi
        done
        
        if [ "$test_found" = false ] && [ "$base_name" != "__init__" ]; then
            MISSING_TESTS+=("$impl_file")
        fi
    fi
done

# テストカバレッジの確認（pytestとcoverage.pyが利用可能な場合）
if command -v python3 >/dev/null 2>&1; then
    echo ""
    echo "📊 テストカバレッジ分析..."
    
    # pytest/coverageがインストールされているか確認
    if python3 -c "import pytest" 2>/dev/null && python3 -c "import coverage" 2>/dev/null; then
        # カバレッジレポートが存在する場合
        if [ -f ".coverage" ] || [ -f "htmlcov/index.html" ]; then
            echo "  既存のカバレッジレポートを検出"
            
            # カバレッジ情報を取得
            if [ -f ".coverage" ]; then
                total_coverage=$(python3 -c "
import coverage
cov = coverage.Coverage()
cov.load()
try:
    print(int(cov.report()))
except:
    print(0)
" 2>/dev/null || echo "0")
                
                echo "  📈 全体カバレッジ: ${total_coverage}%"
                
                if [ "$total_coverage" -lt "$MIN_COVERAGE" ]; then
                    echo -e "  ${YELLOW}⚠️  カバレッジが目標値（${MIN_COVERAGE}%）を下回っています${NC}"
                else
                    echo -e "  ${GREEN}✅ カバレッジが目標値を満たしています${NC}"
                fi
            fi
        else
            echo "  💡 ヒント: 'pytest --cov=. --cov-report=html' でカバレッジレポートを生成できます"
        fi
    elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
        echo "  💡 pytest と coverage のインストールを推奨します:"
        echo "     pip install pytest coverage pytest-cov"
    fi
fi

# TDD実践チェック（Gitログから分析）
echo ""
echo "🔍 TDD実践状況分析..."
if command -v git >/dev/null 2>&1 && [ -d ".git" ]; then
    # 最近のコミットでテストファイルが先にコミットされているかチェック
    recent_commits=$(git log --oneline -20 --name-only --diff-filter=A 2>/dev/null | grep '\.py$' || true)
    
    if [ -n "$recent_commits" ]; then
        echo "  最近20コミットのファイル追加パターンを分析中..."
        
        # 実装ファイルとテストファイルのコミット順序を簡易チェック
        impl_first_count=0
        test_first_count=0
        
        # 簡易的な分析（完全な分析は複雑なため基本的なチェックのみ）
        echo "  📝 TDDの実践を推奨します（テストファイルを先にコミット）"
    else
        echo "  分析可能なコミット履歴がありません"
    fi
fi

# テストの品質分析
echo ""
echo "🔬 テスト品質分析..."
if [ $TOTAL_IMPL_FILES -gt 0 ]; then
    # テストファイルの行数を集計
    total_test_lines=0
    total_impl_lines=0
    
    # テストファイルの行数をカウント
    for test_file in $(find . -name "test_*.py" -o -name "*_test.py" | grep -v __pycache__); do
        if [ -f "$test_file" ]; then
            lines=$(wc -l < "$test_file" | tr -d ' ')
            total_test_lines=$((total_test_lines + lines))
        fi
    done
    
    # 実装ファイルの行数をカウント
    for impl_file in $IMPL_FILES; do
        if [ -f "$impl_file" ]; then
            lines=$(wc -l < "$impl_file" | tr -d ' ')
            total_impl_lines=$((total_impl_lines + lines))
        fi
    done
    
    if [ $total_impl_lines -gt 0 ]; then
        test_ratio=$(python3 -c "print(f'{$total_test_lines / $total_impl_lines:.2f}')" 2>/dev/null || echo "0")
        echo "  📏 テストコード/実装コード比率: ${test_ratio}"
        
        if python3 -c "exit(0 if $test_ratio >= $MIN_TEST_RATIO else 1)" 2>/dev/null; then
            echo -e "  ${GREEN}✅ 十分なテストコードが存在します${NC}"
        else
            echo -e "  ${YELLOW}⚠️  テストコードが不足している可能性があります${NC}"
        fi
    fi
    
    # pytest設定の確認
    echo ""
    echo "  🔧 テスト設定:"
    if [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] || [ -f "setup.cfg" ]; then
        echo "    ✅ pytest設定ファイルが存在します"
    else
        echo "    💡 pytest.ini または pyproject.toml の作成を推奨します"
    fi
    
    if [ -f "conftest.py" ] || find . -name "conftest.py" -not -path "./__pycache__/*" | head -1 >/dev/null 2>&1; then
        echo "    ✅ conftest.py が存在します（フィクスチャ定義）"
    fi
fi

# 結果サマリー
echo ""
echo "📊 分析結果サマリー"
echo "========================"
echo "📁 ファイル統計:"
echo "  - 実装ファイル数: $TOTAL_IMPL_FILES"
echo "  - テストファイル数: $TOTAL_TEST_FILES"
echo "  - テスト未作成: ${#MISSING_TESTS[@]}ファイル"

if [ ${#MISSING_TESTS[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}❌ テストが存在しないファイル:${NC}"
    for file in "${MISSING_TESTS[@]:0:10}"; do
        echo "  - $file"
    done
    if [ ${#MISSING_TESTS[@]} -gt 10 ]; then
        echo "  ... 他 $((${#MISSING_TESTS[@]} - 10))ファイル"
    fi
fi

echo ""
echo "💡 推奨アクション:"
echo "  1. テストファーストでの開発を心がける"
echo "  2. 各実装ファイルに対応するテストを作成"
echo "  3. カバレッジ目標値（${MIN_COVERAGE}%）を維持"
echo "  4. Red-Green-Refactorサイクルを実践"
echo "  5. pytest-covでカバレッジを定期的に確認"

# Pythonテスト特有の推奨事項
echo ""
echo "🐍 Python固有の推奨事項:"
echo "  - doctestの活用（関数のdocstring内にテストを記述）"
echo "  - pytestのフィクスチャを使った効率的なテスト"
echo "  - モックを使った外部依存の分離（unittest.mock）"
echo "  - 型ヒントとmypyを使った静的型チェック"

# 終了コード
if [ ${#MISSING_TESTS[@]} -gt 0 ] || [ -n "$LOW_COVERAGE_FILES" ]; then
    echo ""
    echo -e "${YELLOW}⚠️  改善が必要な項目があります${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}✅ テスト分析完了 - 良好な状態です${NC}"
    exit 0
fi