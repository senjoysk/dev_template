# Claude Code開発テンプレート

Claude Code（claude.ai/code）で効率的に開発を始めるためのテンプレート集です。TDD（テスト駆動開発）とコード品質チェックを最初から組み込み、高品質なコードベースを維持できます。

## 🎯 最新機能

### 差分表示とレポート生成 (v1.4)
- **リアルタイム差分表示**: スキップされたファイルの差分を即座に確認
- **差分サイズ表示**: 各ファイルの+/-行数をサマリーに表示
- **詳細レポート**: `.template_updates_*`ディレクトリに差分情報を保存
- **手動マージサポート**: 新バージョンを別途保存し、後から簡単にマージ可能

### 既存ファイル保護 (v1.3)
- 既存ファイルを上書きせずスキップ
- 追加/スキップされたファイルの明確なサマリー表示

## 🎯 特徴

- **Claude Code最適化**: Claude Codeが効率的に動作する環境を自動構築
- **段階的セットアップ**: Stage 1（最小限）→ Stage 2（技術スタック固有）
- **技術スタック自動検出**: package.json、requirements.txt等から自動判定
- **TDD標準装備**: t_wada式TDD（Red-Green-Refactorサイクル）を標準採用
- **品質チェック自動化**: コミット時の自動品質チェック（SRP違反検出、ファイルサイズ監視）
- **多言語対応**: Node.js/TypeScript、Python、Go等の主要言語に対応

## 🚀 クイックスタート

### Stage 1: 最小限セットアップ（空のプロジェクトから開始）

```bash
# 新規プロジェクトディレクトリを作成
mkdir my-new-project
cd my-new-project

# Stage 1: Claude Codeですぐに開発を始められる最小限の環境
/path/to/dev_template/scripts/init-stage1.sh
```

この時点で以下がセットアップされ、Claude Codeが効率的に動作します：
- `CLAUDE.md` - Claude Code用開発ガイド
- `DEVELOPMENT_GUIDE.md` - 開発者ガイド
- `DEVELOPMENT_CHECKLIST.md` - TDDチェックリスト
- `README.md` - プロジェクト説明テンプレート
- `.gitignore` - 汎用的な除外設定
- `scripts/worktree.sh` - Git Worktree管理

### Stage 2: 技術スタック固有の拡張（技術スタック決定後）

```bash
# package.json、requirements.txt等を作成後
npm init -y  # または pip init、go mod init等

# Stage 2: 技術スタックを自動検出して固有の設定を追加
/path/to/dev_template/scripts/init-stage2.sh

# オプション：技術スタックを明示的に指定
/path/to/dev_template/scripts/init-stage2.sh --stack=node-typescript
```

技術スタックに応じて以下が追加されます：
- Huskyによるpre-commitフック（Node.js）
- 言語別テスト分析スクリプト
- コード品質チェックスクリプト
- 技術スタック固有の設定ファイル

## 📁 ディレクトリ構造

```
dev_template/
├── stage1/                    # Stage 1: 最小限セットアップ
│   ├── CLAUDE.md             # Claude Code用ガイド（汎用版）
│   ├── DEVELOPMENT_GUIDE.md  # 開発者ガイド（基本版）
│   ├── DEVELOPMENT_CHECKLIST.md # TDDチェックリスト
│   ├── README.md.template    # READMEテンプレート
│   ├── .gitignore           # Git除外設定
│   └── scripts/
│       └── worktree.sh      # Git Worktree管理
├── stage2/                   # Stage 2: 技術スタック固有
│   ├── node-typescript/      # Node.js + TypeScript用
│   │   └── .nvmrc           # Node.jsバージョン指定
│   ├── python/              # Python用
│   └── go/                  # Go用
├── scripts/                  # 実行スクリプト
│   ├── init-stage1.sh       # Stage 1セットアップ
│   ├── init-stage2.sh       # Stage 2セットアップ（自動検出）
│   ├── test-analysis/       # 言語別テスト分析
│   │   ├── node.sh
│   │   ├── python.sh
│   │   └── go.sh
│   └── code-review/         # コード品質チェック
│       ├── srp-check.sh     # SRP違反検出
│       └── file-size-check.sh # ファイルサイズ監視
├── templates/               # 旧テンプレート（互換性のため保持）
├── .husky/                  # Huskyテンプレート
└── README.md               # このファイル
```

## 🔍 技術スタック自動検出

`init-stage2.sh`は以下のファイルから技術スタックを自動検出します：

- **package.json** → Node.js（tsconfig.jsonがあればTypeScript）
- **requirements.txt/setup.py/pyproject.toml** → Python
- **go.mod** → Go
- **Gemfile** → Ruby
- Reactは package.json の依存関係から判定

## 📋 主要コンポーネント

### Stage 1: 最小限セットアップ

#### CLAUDE.md
Claude Codeが参照する開発ガイド。TDD原則と基本的なコーディング規約を含みます。

#### DEVELOPMENT_GUIDE.md
開発者向けの包括的なガイド。TDD開発フロー、コーディング規約、テスト戦略を説明。

#### DEVELOPMENT_CHECKLIST.md
TimeLoggerプロジェクトから提供される実践的なTDDチェックリスト。

### Stage 2: 技術スタック固有の拡張

#### pre-commitフック（Node.js）
コミット前に自動実行される品質チェック：
1. ビルド確認
2. テスト実行と失敗分析
3. SRP違反チェック
4. ファイルサイズ監視

#### コード品質チェックスクリプト

**SRP違反チェック (srp-check.sh)**
- ファイル行数の上限チェック（デフォルト: 500行）
- クラス/ファイルのメソッド数チェック（デフォルト: 20個）
- import数による複雑度チェック（デフォルト: 30個）
- `@SRP-EXCEPTION`コメントによる例外指定可能

**ファイルサイズ監視 (file-size-check.sh)**
- ファイルサイズ上限チェック（デフォルト: 100KB）
- 警告サイズ設定（デフォルト: 50KB）
- 早期の分割を促進

## 🔧 カスタマイズ

### 環境変数による設定

```bash
# SRP違反チェックのカスタマイズ
export MAX_LINES=800      # ファイル最大行数を800行に変更
export MAX_METHODS=30     # メソッド数上限を30個に変更

# ファイルサイズチェックのカスタマイズ
export MAX_FILE_SIZE=150  # ファイルサイズ上限を150KBに変更
export WARNING_SIZE=75    # 警告サイズを75KBに変更
```

## 💡 使用例

### 新規Node.jsプロジェクトの例

```bash
# 1. プロジェクト作成とStage 1
mkdir todo-app
cd todo-app
/path/to/dev_template/scripts/init-stage1.sh

# 2. Claude Codeで基本的な設計を開始
# CLAUDE.mdを参考にTDDで開発開始

# 3. package.json作成後、Stage 2を実行
npm init -y
npm install --save-dev typescript jest @types/jest
/path/to/dev_template/scripts/init-stage2.sh

# 4. Huskyとpre-commitフックが自動設定される
```

## 📋 実行例

### 新規プロジェクトの場合
```bash
$ ./scripts/init-stage1.sh

🚀 Claude Code開発テンプレート Stage 1 初期化
📁 プロジェクト: my-project

📋 Stage 1: 最小限のClaude Code環境をセットアップ中...

✅ 作成: CLAUDE.md
✅ 作成: DEVELOPMENT_GUIDE.md
✅ 作成: DEVELOPMENT_CHECKLIST.md
✅ 作成: README.md
✅ 作成: .gitignore
✅ 作成: scripts/worktree.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 実行結果サマリー
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ 追加されたファイル (6件):
   - CLAUDE.md
   - DEVELOPMENT_GUIDE.md
   - DEVELOPMENT_CHECKLIST.md
   - README.md
   - .gitignore
   - scripts/worktree.sh
```

### 既存ファイルがある場合
```bash
$ ./scripts/init-stage2.sh

🚀 Claude Code開発テンプレート Stage 2 初期化
📁 プロジェクト: my-project
📦 技術スタック（検出）: node-typescript

📋 Stage 2: 技術スタック固有の設定を適用中...

📋 共通スクリプトをコピー中...
⚠️  スキップ: scripts/code-review/srp-check.sh (既存ファイル)
    📊 差分プレビュー:
    +# ファイルサイズチェックを追加
    +if [ $(stat -f%z "$file" 2>/dev/null || stat -c%s "$file") -gt 100000 ]; then
    +    echo "  ⚠️  ファイルサイズが100KBを超えています"
    ...

✅ 作成: scripts/code-review/file-size-check.sh
✅ 作成: scripts/test-analysis/test-analysis.sh

📁 差分を保存中...
✅ 差分情報を保存しました: .template_updates_20250130_143022/
   📄 レポート: .template_updates_20250130_143022/UPDATE_REPORT.md
   📁 新バージョン: .template_updates_20250130_143022/*.new
   📊 差分ファイル: .template_updates_20250130_143022/*.diff

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 実行結果サマリー
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ 追加されたファイル (3件):
   - scripts/code-review/file-size-check.sh
   - scripts/test-analysis/test-analysis.sh
   - .husky/pre-commit

⚠️  スキップされたファイル (2件):
   - scripts/code-review/srp-check.sh (既存ファイル) [+8行/-2行]
   - .nvmrc (既存ファイル) [差分なし]
```

## 🧪 テスト

スクリプトの動作を検証するためのテストスイートが用意されています。

### Batsのインストール

```bash
# macOS (Homebrew)
brew install bats-core

# npm
npm install -g bats

# その他の方法
# https://github.com/bats-core/bats-core#installation
```

### テストの実行

```bash
# すべてのテストを実行
./scripts/run-tests.sh

# 特定のテストのみ実行
./scripts/run-tests.sh stage1
./scripts/run-tests.sh stage2
./scripts/run-tests.sh diff

# 詳細モードで実行
./scripts/run-tests.sh -v

# TAP形式で出力
./scripts/run-tests.sh -t
```

### テスト内容

- **test_init_stage1.bats**: Stage 1初期化スクリプトのテスト
  - 新規ファイル作成
  - 既存ファイルのスキップ
  - Git初期化
  - 差分レポート生成

- **test_init_stage2.bats**: Stage 2初期化スクリプトのテスト
  - 技術スタック検出
  - ファイルコピー
  - Huskyセットアップ

- **test_diff_functions.bats**: 差分機能の単体テスト
  - get_diff_summary関数
  - show_diff_preview関数
  - copy_file関数
  - process_template関数

## 💡 差分の手動マージ方法

スキップされたファイルの更新を後から取り込みたい場合：

```bash
# 1. 最新の差分ディレクトリを確認
ls -la .template_updates_*

# 2. レポートを確認
cat .template_updates_20250130_143022/UPDATE_REPORT.md

# 3. 特定のファイルの差分を確認
cat .template_updates_20250130_143022/scripts/code-review/srp-check.sh.diff

# 4. マージツールで比較しながら編集
vimdiff scripts/code-review/srp-check.sh .template_updates_20250130_143022/scripts/code-review/srp-check.sh.new

# 5. または、新バージョンで上書き（事前にバックアップを推奨）
cp scripts/code-review/srp-check.sh scripts/code-review/srp-check.sh.bak
cp .template_updates_20250130_143022/scripts/code-review/srp-check.sh.new scripts/code-review/srp-check.sh
```


## 📝 ライセンス

MITライセンス - 詳細は[LICENSE](LICENSE)を参照してください。

## 🙏 謝辞

- t_wadaさんのTDD手法に基づいています

---

**🚀 Claude Codeで効率的な開発を始めましょう！**