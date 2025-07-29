#!/bin/bash

# テスト分析スクリプト（汎用テンプレート）
# テスト実行 → 失敗抽出 → レポート生成

set -e

echo "🧪 テスト実行と失敗分析を開始..."

# テスト結果保存用ディレクトリ作成
mkdir -p test-reports

# テスト実行して結果を保存
echo "📊 テスト実行中..."
{{TEST_COMMAND}} > test-reports/test-results.txt 2>&1 || TEST_EXIT_CODE=$?

# テストが成功した場合
if [ -z "$TEST_EXIT_CODE" ] || [ "$TEST_EXIT_CODE" -eq 0 ]; then
    echo "✅ 全テスト成功！"
    # 成功時も統計を保存
    {{TEST_STATS_EXTRACTION}} > test-reports/test-success.txt
    exit 0
fi

# 失敗したテストを抽出
echo -e "\n=== 失敗分析 ==="
{{FAILURE_DETECTION}}

if [ $? -eq 0 ]; then
    # 失敗したテストスイート一覧
    echo "❌ 失敗したテストスイート:"
    {{FAILURE_LIST_EXTRACTION}}
    
    # 詳細な失敗情報を抽出
    echo -e "\n=== 失敗詳細 ==="
    {{FAILURE_DETAILS_EXTRACTION}} > test-reports/test-failures.txt
    
    # 失敗サマリーを抽出
    echo -e "\n=== 失敗サマリー ==="
    {{FAILURE_SUMMARY_EXTRACTION}} > test-reports/test-summary.txt 2>/dev/null || echo "サマリーなし"
    
    if [ -s test-reports/test-summary.txt ]; then
        cat test-reports/test-summary.txt
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