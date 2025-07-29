# Claude Code開発テンプレート

Claude Code（claude.ai/code）で効率的に開発を始めるためのテンプレート集です。TDD（テスト駆動開発）とコード品質チェックを最初から組み込み、高品質なコードベースを維持できます。

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


## 📝 ライセンス

MITライセンス - 詳細は[LICENSE](LICENSE)を参照してください。

## 🙏 謝辞

- t_wadaさんのTDD手法に基づいています

---

**🚀 Claude Codeで効率的な開発を始めましょう！**