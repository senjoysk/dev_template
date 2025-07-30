#!/bin/bash

# テスト分析スクリプト - Node.js/TypeScript版
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

# 実装ファイルを検索（TypeScript/JavaScript）
IMPL_FILES=$(find . -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" | \
    grep -v node_modules | \
    grep -v '\.test\.' | \
    grep -v '\.spec\.' | \
    grep -v '__tests__' | \
    grep -v '\.d\.ts$' | \
    sort)

# 各実装ファイルに対してテストファイルの存在を確認
for impl_file in $IMPL_FILES; do
    if [ -f "$impl_file" ]; then
        TOTAL_IMPL_FILES=$((TOTAL_IMPL_FILES + 1))
        
        # テストファイルのパスパターンを生成
        base_name=$(basename "$impl_file" | sed 's/\.[^.]*$//')
        dir_name=$(dirname "$impl_file")
        
        # 可能なテストファイルパス
        test_patterns=(
            "${dir_name}/__tests__/${base_name}.test.ts"
            "${dir_name}/__tests__/${base_name}.test.tsx"
            "${dir_name}/__tests__/${base_name}.test.js"
            "${dir_name}/__tests__/${base_name}.spec.ts"
            "${dir_name}/__tests__/${base_name}.spec.tsx"
            "${dir_name}/__tests__/${base_name}.spec.js"
            "${dir_name}/${base_name}.test.ts"
            "${dir_name}/${base_name}.test.tsx"
            "${dir_name}/${base_name}.test.js"
            "${dir_name}/${base_name}.spec.ts"
            "${dir_name}/${base_name}.spec.tsx"
            "${dir_name}/${base_name}.spec.js"
        )
        
        test_found=false
        for test_file in "${test_patterns[@]}"; do
            if [ -f "$test_file" ]; then
                test_found=true
                TOTAL_TEST_FILES=$((TOTAL_TEST_FILES + 1))
                break
            fi
        done
        
        if [ "$test_found" = false ]; then
            MISSING_TESTS+=("$impl_file")
        fi
    fi
done

# テストカバレッジの確認（Jestが利用可能な場合）
if [ -f "package.json" ] && command -v npm >/dev/null 2>&1; then
    echo ""
    echo "📊 テストカバレッジ分析..."
    
    # jest設定の確認
    if grep -q "\"jest\"" package.json || [ -f "jest.config.js" ] || [ -f "jest.config.ts" ]; then
        # カバレッジレポートの生成を試みる
        if [ -d "coverage" ]; then
            echo "  既存のカバレッジレポートを使用"
            
            # coverage-summary.jsonがある場合は解析
            if [ -f "coverage/coverage-summary.json" ]; then
                total_coverage=$(node -e "
                    const coverage = require('./coverage/coverage-summary.json');
                    const total = coverage.total;
                    const avg = (total.lines.pct + total.statements.pct + total.functions.pct + total.branches.pct) / 4;
                    console.log(Math.round(avg));
                " 2>/dev/null || echo "0")
                
                echo "  📈 全体カバレッジ: ${total_coverage}%"
                
                if [ "$total_coverage" -lt "$MIN_COVERAGE" ]; then
                    echo -e "  ${YELLOW}⚠️  カバレッジが目標値（${MIN_COVERAGE}%）を下回っています${NC}"
                else
                    echo -e "  ${GREEN}✅ カバレッジが目標値を満たしています${NC}"
                fi
            fi
        else
            echo "  💡 ヒント: 'npm test -- --coverage' でカバレッジレポートを生成できます"
        fi
    fi
fi

# TDD実践チェック（Gitログから分析）
echo ""
echo "🔍 TDD実践状況分析..."
if command -v git >/dev/null 2>&1 && [ -d ".git" ]; then
    # 最近のコミットでテストファイルが先にコミットされているかチェック
    recent_commits=$(git log --oneline -20 --name-only --diff-filter=A 2>/dev/null | grep -E '\.(ts|tsx|js|jsx)$' || true)
    
    if [ -n "$recent_commits" ]; then
        echo "  最近20コミットのファイル追加パターンを分析中..."
        # 簡易的なTDDチェック（実装が複雑なため、基本的な分析のみ）
    else
        echo "  分析可能なコミット履歴がありません"
    fi
fi

# テストの品質分析
echo ""
echo "🔬 テスト品質分析..."
if [ ${#IMPL_FILES[@]} -gt 0 ]; then
    # テストファイルの行数を集計
    total_test_lines=0
    total_impl_lines=0
    
    for test_file in $(find . -name "*.test.ts" -o -name "*.test.tsx" -o -name "*.test.js" -o -name "*.spec.ts" -o -name "*.spec.tsx" -o -name "*.spec.js" | grep -v node_modules); do
        if [ -f "$test_file" ]; then
            lines=$(wc -l < "$test_file" | tr -d ' ')
            total_test_lines=$((total_test_lines + lines))
        fi
    done
    
    for impl_file in $IMPL_FILES; do
        if [ -f "$impl_file" ]; then
            lines=$(wc -l < "$impl_file" | tr -d ' ')
            total_impl_lines=$((total_impl_lines + lines))
        fi
    done
    
    if [ $total_impl_lines -gt 0 ]; then
        test_ratio=$(echo "scale=2; $total_test_lines / $total_impl_lines" | bc 2>/dev/null || echo "0")
        echo "  📏 テストコード/実装コード比率: ${test_ratio}"
        
        if (( $(echo "$test_ratio < $MIN_TEST_RATIO" | bc -l) )); then
            echo -e "  ${YELLOW}⚠️  テストコードが不足している可能性があります${NC}"
        else
            echo -e "  ${GREEN}✅ 十分なテストコードが存在します${NC}"
        fi
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