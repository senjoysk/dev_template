# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🚨 重要: プロジェクト情報
**プロジェクト名**: [プロジェクト名を記入]
**概要**: [プロジェクトの概要を記入]
**開発段階**: 初期開発

## 🔴🟢♻️ 開発方針: t_wada式TDD

**すべての開発はテスト駆動開発（TDD）のRed-Green-Refactorサイクルで実施してください**

### TDDの基本サイクル
1. **🔴 Red**: 失敗するテストを書く
2. **🟢 Green**: テストを通す最小限の実装
3. **♻️ Refactor**: テストが通る状態を保ちながらリファクタリング

### t_wadaさんのTDD原則
- **テストファースト**: 実装前に必ずテストを書く
- **小さなステップ**: 一度に一つのことだけ
- **YAGNI (You Aren't Gonna Need It)**: 必要になるまで作らない
- **三角測量**: 複数のテストケースから一般化を導く
- **明白な実装**: シンプルで分かりやすいコードを書く

## 🚨 必須: TDD開発フロー

### 新機能開発の手順
1. **🔴 Red Phase** - 失敗するテストを書く
   - TODOリストの作成（実装する機能を小さなタスクに分解）
   - 最初のテストケースの決定（最も簡単なケースから）
   - テストが失敗することを確認

2. **🟢 Green Phase** - テストを通す
   - 最小限の実装（仮実装でもOK）
   - テストが通ることを確認

3. **♻️ Refactor Phase** - リファクタリング
   - テストが通る状態を維持しながら改善
   - より良い設計に変更

4. **繰り返し**
   - 次のテストケースに進む

### コーディング前の必須確認
- [ ] TODOリストの作成（実装する機能を小さなタスクに分解）
- [ ] 最初のテストケースの決定（最も簡単なケースから）
- [ ] インターフェースの設計（使い方から考える）
- [ ] エラーケースの洗い出し

## TDDでのコーディング規約

### 1. テストファースト開発
- 実装を先に書かない
- テストから書き始める
- テストが失敗することを確認してから実装

### 2. インターフェース駆動設計
- **使い方から設計**: テストで理想的な使い方を先に書く
- **Interface First**: インターフェースを定義してから実装
- **依存性注入**: テスタブルな設計のためにインターフェースを注入

### 3. 実装規約
- エラーハンドリングを適切に行う
- 適切なログ出力を行う
- コメントは必要な箇所にのみ記載

## 🚨 Claude Code: タスク完了前の必須確認

**Claude Codeは依頼されたタスクを完了したと判断する前に、以下を必ず確認してください:**

### タスク完了前の品質ゲート
1. コードが正しく動作することを確認
2. テストが存在する場合は実行して確認
3. エラーハンドリングが適切に実装されていることを確認

### 実行タイミング
- **タスク実装完了後**: コードの実装やファイル変更が完了した時点
- **完了報告前**: ユーザーに「完了しました」と報告する前

### 目的
- **早期問題検出**: 開発時点で問題を検出
- **品質保証**: 動作確認
- **開発速度向上**: 後戻り作業の削減

## 📋 開発チェックリスト

### 🚨 絶対に守るべきTDDルール
1. **テストなしでコードを書かない**
2. **失敗するテストを確認してから実装**
3. **一度に一つのことだけ**
4. **明白な実装を心がける**
5. **TODOリストで進捗管理**

**🚨 CRITICAL: 実装前に必ずテストを書き、Red-Green-Refactorサイクルを守ること**

## 🔄 TDDコメント管理のベストプラクティス

### フェーズ別コメント管理手順

#### 1. **🔴 Red Phase - 失敗するテストを書く**
- テストコメントに「🔴 Red Phase: 機能名 - 実装前なので失敗する」と記載
- 失敗することを確認

#### 2. **🟢 Green Phase - テストを通す最小限の実装**
- コメントを「🟢 Green Phase: 機能名 - 最小限の実装でテストが通る」に更新
- テストが通ることを確認

#### 3. **♻️ Refactor Phase - リファクタリング**
- コメントを「♻️ Refactor Phase: 機能名 - リファクタリング完了」に更新
- テストが通る状態を維持

### 実装完了後のコメント整理
- フェーズ表記を削除し、機能説明に変更
- テストの意図を明確に記述

## 🚨 エラー処理規約

### 統一されたエラー処理の実装

#### 1. **カスタムエラークラスの使用**
```typescript
// ❌ 悪い例: 標準Errorの使用
throw new Error('データベースエラー');

// ✅ 良い例: カスタムエラークラスの使用
import { DatabaseError } from './errors';
throw new DatabaseError('データベース接続に失敗しました', {
  operation: 'connect',
  userId: user.id
});
```

#### 2. **catch節でのルール**
- エラーのログ記録は必須
- エラーの握りつぶし禁止
- 適切な処理後は必ず再スローまたはreturn

```typescript
// ❌ 悪い例: console.errorの使用、エラーの握りつぶし
catch (error) {
  console.error('エラー:', error);
  // エラーを無視して処理を続行
}

// ✅ 良い例: ロガー使用、適切なエラー処理
import { logger } from './utils/logger';
catch (error) {
  logger.error('DATABASE', 'データ保存エラー', error);
  
  // 復旧可能な場合はリトライ
  if (isRetryable(error)) {
    return retry();
  }
  
  // 復旧不可能な場合は必ず再スロー
  throw new DatabaseError('処理に失敗しました', { error });
}
```

## 🚨 ログ使用規約

### console.log/console.error の使用禁止

すべてのログ出力は統一されたLoggerサービスを使用してください。

```typescript
// ❌ 悪い例: console直接使用
console.log('メッセージ');
console.error('エラー');

// ✅ 良い例: Loggerサービス使用
import { logger } from './utils/logger';
logger.info('COMPONENT', 'メッセージ');
logger.error('COMPONENT', 'エラー', error);
```

### ログ使用の基本ルール
1. **必ず**Loggerサービスをインポートして使用
2. **絶対に**console.log/error/warn/infoを直接使わない
3. **常に**適切なログレベル（debug/info/warn/error/success）を選択
4. **必ず**コンポーネント名（operation）を指定
5. **推奨**構造化されたデータを第3引数に渡す

### Python向けログ規約
```python
# ❌ 悪い例: print文の使用
print('エラー:', error)

# ✅ 良い例: loggingモジュール使用
import logging
logger = logging.getLogger(__name__)
logger.error('エラーが発生しました', exc_info=True)
```

## 🚨 型安全性規約

### TypeScript: any型使用の原則禁止

```typescript
// ❌ 悪い例: any型の使用
const data: any = fetchData();
function process(input: any): any { ... }

// ✅ 良い例: 具体的な型定義
interface UserData {
  id: string;
  name: string;
}
const data: UserData = fetchData();
function process(input: UserData): ProcessResult { ... }
```

### any型使用の例外ルール
やむを得ずany型を使用する場合は、必ず`// ALLOW_ANY`コメントを付与し、理由を明記：

```typescript
// ALLOW_ANY: 外部ライブラリの型定義が不完全なため
const result = (externalLib as any).undocumentedMethod();
```

### Python: 型ヒントの必須化

```python
# ❌ 悪い例: 型ヒントなし
def process(data):
    return data['value']

# ✅ 良い例: 型ヒントあり
from typing import Dict, Any

def process(data: Dict[str, Any]) -> str:
    return data['value']
```

### 関数の型注釈必須
すべての関数には戻り値の型を明示的に指定してください。

## 🔧 コード品質自動チェック

### Pre-commitフックでの品質チェック
以下のスクリプトがコミット時に自動実行されます：

1. **error-handling-check.sh** - エラー処理規約の遵守確認
2. **console-usage-check.sh** - console/print使用の検出
3. **type-safety-check.sh** - any型使用と型注釈の確認
4. **dependency-injection-check.sh** - DI原則の遵守確認（TypeScript）

### スキップ方法（緊急時のみ）
```bash
git commit --no-verify -m "緊急修正"
# ただし、後で必ず修正すること
```

---

**🎯 本開発ガイドは、効率的で高品質な開発を実現するための指針です。TDD開発を徹底し、継続的にシステムを改善していきましょう。**