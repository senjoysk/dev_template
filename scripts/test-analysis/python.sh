#!/bin/bash

# Python/pytest用テスト分析スクリプト
# テスト実行 → 失敗抽出 → レポート生成

set -e

echo "🧪 テスト実行と失敗分析を開始..."

# テスト結果保存用ディレクトリ作成
mkdir -p test-reports

# テスト実行して結果を保存
echo "📊 テスト実行中..."
pytest -v > test-reports/test-results.txt 2>&1 || TEST_EXIT_CODE=$?

# テストが成功した場合
if [ -z "$TEST_EXIT_CODE" ] || [ "$TEST_EXIT_CODE" -eq 0 ]; then
    echo "✅ 全テスト成功！"
    # 成功時も統計を保存
    grep -E "passed|failed|error" test-reports/test-results.txt | tail -1 > test-reports/test-success.txt
    exit 0
fi

# 成功/失敗の統計を表示
echo "=== テスト統計 ==="
grep -E "passed|failed|error" test-reports/test-results.txt | tail -1

# 失敗したテストを抽出
echo -e "\n=== 失敗分析 ==="
if grep -q "FAILED\|ERROR" test-reports/test-results.txt; then
    # 失敗したテスト一覧
    echo "❌ 失敗したテスト:"
    grep -E "FAILED|ERROR" test-reports/test-results.txt | sed 's/^/  - /'
    
    # 詳細な失敗情報を抽出
    echo -e "\n=== 失敗詳細 ==="
    grep -A 15 -B 2 "FAILED\|ERROR\|AssertionError" test-reports/test-results.txt > test-reports/test-failures.txt
    
    # 失敗サマリーを抽出
    echo -e "\n=== 失敗サマリー ==="
    grep -A 30 "FAILURES\|ERRORS" test-reports/test-results.txt > test-reports/test-summary.txt 2>/dev/null || echo "サマリーなし"
    
    if [ -s test-reports/test-summary.txt ]; then
        head -50 test-reports/test-summary.txt
    else
        head -20 test-reports/test-failures.txt
    fi
    
    echo -e "\n📁 詳細は以下ファイルを確認:"
    echo "  - test-reports/test-results.txt (全結果)"
    echo "  - test-reports/test-failures.txt (失敗詳細)"
    echo "  - test-reports/test-summary.txt (失敗サマリー)"
    
    exit 1
else
    echo "⚠️  テスト結果の解析に失敗しました"
    echo "📁 test-reports/test-results.txt を手動で確認してください"
    exit 1
fi