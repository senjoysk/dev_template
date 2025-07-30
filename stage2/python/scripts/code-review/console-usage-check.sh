#!/bin/bash

# print()使用チェックスクリプト - Python版
# デバッグ用のprint文の使用を検出

echo "🔍 print()使用チェックを開始します..."

# 設定可能な変数（プロジェクトでカスタマイズ可能）
CHECK_DIR="${PRINT_CHECK_DIR:-src}"
EXCLUDE_PATTERNS="${PRINT_CHECK_EXCLUDE:-__pycache__|test_|_test\.py|conftest\.py|setup\.py}"

# 一時ファイルを作成
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# print使用を検出
echo "📁 検索対象: $CHECK_DIR"

# ディレクトリが存在しない場合はカレントディレクトリを検索
if [ ! -d "$CHECK_DIR" ]; then
    CHECK_DIR="."
fi

# findとgrepを使用してprint使用を検出
# コメント行や文字列内のprintは除外
find "$CHECK_DIR" -type f -name "*.py" | \
  grep -vE "$EXCLUDE_PATTERNS" | \
  xargs grep -n "^[^#]*\bprint\s*(" 2>/dev/null | \
  grep -v '""".*print.*"""' | \
  grep -v "'''.*print.*'''" > "$TEMP_FILE" || true

# 結果をカウント
PRINT_USAGE_COUNT=$(cat "$TEMP_FILE" | wc -l | tr -d ' ')

if [ "$PRINT_USAGE_COUNT" -gt 0 ]; then
  echo ""
  echo "❌ エラー: $PRINT_USAGE_COUNT 箇所でprint()使用が検出されました"
  echo ""
  
  # 最初の10件を表示
  echo "📍 検出箇所（最初の10件）:"
  head -10 "$TEMP_FILE" | while IFS=: read -r file line content; do
    # 行の内容を簡潔に表示
    content_trimmed=$(echo "$content" | sed 's/^[[:space:]]*//' | cut -c1-60)
    if [ ${#content_trimmed} -eq 60 ]; then
      content_trimmed="${content_trimmed}..."
    fi
    echo "  $file:$line - $content_trimmed"
  done
  
  if [ "$PRINT_USAGE_COUNT" -gt 10 ]; then
    echo "  ... 他 $((PRINT_USAGE_COUNT - 10)) 箇所"
  fi
  
  echo ""
  echo "📝 修正方法:"
  echo "1. loggingモジュールをインポート:"
  echo "   import logging"
  echo "   logger = logging.getLogger(__name__)"
  echo ""
  echo "2. print()を置き換え:"
  echo "   print('メッセージ') → logger.info('メッセージ')"
  echo "   print(f'値: {value}') → logger.debug(f'値: {value}')"
  echo "   print('エラー:', error) → logger.error('エラー', exc_info=True)"
  echo ""
  echo "3. 本当に標準出力が必要な場合（CLIツール等）:"
  echo "   - sys.stdout.write()を使用"
  echo "   - またはコメントで意図を明確化"
  echo "     # CLI出力のため意図的にprintを使用"
  echo "     print('ユーザー向けメッセージ')"
  echo ""
  
  # git hookから呼ばれている場合の追加情報
  if [ -n "$GIT_DIR" ]; then
    echo "💡 ヒント: 一時的にスキップする場合は --no-verify オプションを使用してください"
    echo "   git commit --no-verify -m 'メッセージ'"
    echo ""
  fi
  
  exit 1
else
  echo "✅ print()使用チェック: 問題なし"
  exit 0
fi