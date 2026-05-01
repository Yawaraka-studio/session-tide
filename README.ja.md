# session-tide

[English](README.md)

Claude Code / Codex の軽量なセッション準備リクエストを、macOS `launchd` で 07:00 / 12:00 / 17:00 / 22:00 に実行するための最小構成です。

`session-tide` は、AI CLI の5時間ウィンドウを生活リズムに寄せるための軽量ヘルスチェックツールです。利用制限を回避するための大量実行ではなく、作業前の疎通確認とログ記録に用途を絞っています。

## 方針

- 送るプロンプトは短く、「OK」だけを返すよう指示します。
- Claude Code はツールを無効化して非対話実行します。
- Codex は非対話実行、読み取り専用サンドボックス、承認なしで実行します。
- 各CLIは失敗しても次の処理へ進みます。
- `caffeinate` で実行中だけ短時間スリープを抑止します。
- ログは `~/Library/Logs/session-tide/session-tide.log` に出力します。

## ファイル

- `scripts/session-tide.zsh`
  - 実行本体です。
- `launchd/studio.yawaraka.session-tide.plist.template`
  - `launchd` 用の設定テンプレートです。
- `scripts/install.zsh`
  - 現在のチェックアウト先に合わせて `launchd` plist を生成し、登録します。
- `scripts/uninstall.zsh`
  - 登録済みの `launchd` plist を解除します。

## インストール

```zsh
./scripts/install.zsh
```

## 手動テスト

```zsh
./scripts/session-tide.zsh
tail -n 80 "$HOME/Library/Logs/session-tide/session-tide.log"
```

## モデル指定

デフォルトでは、それぞれのCLIのデフォルトモデルを使います。軽量モデルを使いたい場合は、環境変数で指定できます。

手動実行時だけ指定する例:

```zsh
SESSION_TIDE_CLAUDE_MODEL=haiku SESSION_TIDE_CODEX_MODEL=<codex-model> ./scripts/session-tide.zsh
```

`launchd` の定時実行で使う場合は、`~/.config/session-tide/config` を作成します。

```zsh
mkdir -p "$HOME/.config/session-tide"
$EDITOR "$HOME/.config/session-tide/config"
```

例:

```zsh
SESSION_TIDE_CLAUDE_MODEL=haiku
SESSION_TIDE_CODEX_MODEL=<codex-model>
```

モデル名は、インストール済みの `claude` / `codex` CLI が受け付けるものを指定してください。

ログの `reason` は以下のように分類されます。

- `ok`: 正常終了
- `usage_limit`: 利用量・レート制限
- `auth`: ログイン・認証・APIキー関連
- `network`: DNS・接続・タイムアウト関連
- `permission`: 権限・承認関連
- `timeout`: `session-tide` 側の実行時間上限
- `command_not_found`: CLI が見つからない
- `unknown`: 上記以外の失敗

## 反映状況の確認

```zsh
launchctl print gui/$(id -u)/studio.yawaraka.session-tide
```

## アンインストール

```zsh
./scripts/uninstall.zsh
```

## ライセンス

MIT

## スリープ中の扱い

Mac がスリープ中の場合、`launchd` の定時実行はその時刻に走らないことがあります。必要なら macOS の電源管理で起床スケジュールを別途組み合わせます。

例:

```zsh
sudo pmset repeat wakeorpoweron MTWRFSU 06:58:00
```

複数時刻の起床を厳密に組みたい場合は、カレンダーイベント、ショートカット、または別の管理ツールとの併用が現実的です。
