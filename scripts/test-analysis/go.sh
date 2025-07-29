#!/bin/bash

# Go用テスト分析スクリプト
# テスト実行 → 失敗抽出 → レポート生成

set -e

echo "🧪 テスト実行と失敗分析を開始..."

# テスト結果保存用ディレクトリ作成
mkdir -p test-reports

# テスト実行して結果を保存
echo "📊 テスト実行中..."
go test -v ./... > test-reports/test-results.txt 2>&1 || TEST_EXIT_CODE=$?

# テストが成功した場合
if [ -z "$TEST_EXIT_CODE" ] || [ "$TEST_EXIT_CODE" -eq 0 ]; then
    echo "✅ 全テスト成功！"
    # 成功時も統計を保存
    grep -E "PASS:|ok\s+" test-reports/test-results.txt > test-reports/test-success.txt
    exit 0
fi

# 成功/失敗の統計を表示
echo "=== テスト統計 ==="
grep -E "PASS:|FAIL:|ok\s+|FAIL\s+" test-reports/test-results.txt | tail -10

# 失敗したテストを抽出
echo -e "\n=== 失敗分析 ==="
if grep -q "FAIL" test-reports/test-results.txt; then
    # 失敗したテスト一覧
    echo "❌ 失敗したテスト:"
    grep "FAIL" test-reports/test-results.txt | grep -v "FAIL\s*\[build failed\]" | sed 's/^/  - /'
    
    # 詳細な失敗情報を抽出
    echo -e "\n=== 失敗詳細 ==="
    grep -A 10 -B 2 "FAIL\|panic:\|Error:" test-reports/test-results.txt > test-reports/test-failures.txt
    
    # エラー出力を抽出
    echo -e "\n=== エラー詳細 ==="
    awk '/--- FAIL:/{flag=1} flag; /^(PASS:|FAIL:|ok\s+|===)/{flag=0}' test-reports/test-results.txt > test-reports/test-summary.txt 2>/dev/null || echo "サマリーなし"
    
    if [ -s test-reports/test-summary.txt ]; then
        head -50 test-reports/test-summary.txt
    else
        head -20 test-reports/test-failures.txt
    fi
    
    echo -e "\n📁 詳細は以下ファイルを確認:"
    echo "  - test-reports/test-results.txt (全結果)"
    echo "  - test-reports/test-failures.txt (失敗詳細)"
    echo "  - test-reports/test-summary.txt (エラー詳細)"
    
    exit 1
else
    echo "⚠️  テスト結果の解析に失敗しました"
    echo "📁 test-reports/test-results.txt を手動で確認してください"
    exit 1
fi