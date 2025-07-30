#!/bin/bash

# Console使用チェックスクリプト（汎用版）
# console.log, console.error, console.warn, console.info の使用を検出

echo "🔍 Console使用チェックを開始します..."

# 設定可能な変数（プロジェクトでカスタマイズ可能）
CHECK_DIR="${CONSOLE_CHECK_DIR:-src}"
EXCLUDE_PATTERNS="${CONSOLE_CHECK_EXCLUDE:-__tests__|test\.|spec\.|logger\.|mockLogger\.|/factories/}"
FILE_EXTENSIONS="${CONSOLE_CHECK_EXTENSIONS:-(ts|tsx|js|jsx)}"

# 一時ファイルを作成
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# console使用を検出
echo "📁 検索対象: $CHECK_DIR"
echo "📝 対象拡張子: $FILE_EXTENSIONS"

# ディレクトリが存在しない場合はカレントディレクトリを検索
if [ ! -d "$CHECK_DIR" ]; then
    CHECK_DIR="."
fi

# findとgrepを使用してconsole使用を検出
find "$CHECK_DIR" -type f -name "*" | \
  grep -E "\.${FILE_EXTENSIONS}$" | \
  grep -vE "$EXCLUDE_PATTERNS" | \
  xargs grep -n "console\.\(log\|error\|warn\|info\)" 2>/dev/null > "$TEMP_FILE" || true

# 結果をカウント
CONSOLE_USAGE_COUNT=$(cat "$TEMP_FILE" | wc -l | tr -d ' ')

if [ "$CONSOLE_USAGE_COUNT" -gt 0 ]; then
  echo ""
  echo "❌ エラー: $CONSOLE_USAGE_COUNT 箇所でconsole使用が検出されました"
  echo ""
  
  # 最初の10件を表示
  echo "📍 検出箇所（最初の10件）:"
  head -10 "$TEMP_FILE" | while IFS=: read -r file line content; do
    echo "  $file:$line - $content"
  done
  
  if [ "$CONSOLE_USAGE_COUNT" -gt 10 ]; then
    echo "  ... 他 $((CONSOLE_USAGE_COUNT - 10)) 箇所"
  fi
  
  echo ""
  echo "📝 修正方法:"
  echo "1. ロガーライブラリをインポート"
  echo "   例: import { logger } from './utils/logger';"
  echo ""
  echo "2. console使用を置き換え:"
  echo "   console.log() → logger.info() または logger.debug()"
  echo "   console.error() → logger.error()"
  echo "   console.warn() → logger.warn()"
  echo ""
  echo "例:"
  echo "  console.log('メッセージ') → logger.info('COMPONENT', 'メッセージ')"
  echo "  console.error('エラー', error) → logger.error('COMPONENT', 'エラー', error)"
  echo ""
  
  # git hookから呼ばれている場合の追加情報
  if [ -n "$GIT_DIR" ]; then
    echo "💡 ヒント: 一時的にスキップする場合は --no-verify オプションを使用してください"
    echo "   git commit --no-verify -m 'メッセージ'"
    echo ""
  fi
  
  exit 1
else
  echo "✅ console使用チェック: 問題なし"
  exit 0
fi