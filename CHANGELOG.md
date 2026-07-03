# Changelog

All notable changes to Perch are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-07-03

### Added

- シェルフのキーボード操作（シェルフをクリックする、またはショートカットで呼び出してフォーカスがあるときのみ有効）:
  - クリックで選択、⌘クリックで複数選択、⌘A で全選択。選択行はハイライト表示。
  - ⌘C — 選択アイテムをクリップボードへコピー。ファイル/画像は実ファイルとしてコピーされるので、
    Finder のフォルダで ⌘V するとファイルが複製される。テキスト/URL は文字列として貼り付け可能。
  - ⌘V — クリップボードの内容（ファイル・画像・テキスト・URL）をシェルフへ取り込み。
  - Delete — 選択アイテムを削除。
  - Esc — 選択解除、もう一度押すとシェルフを閉じる。
- キーボード操作中（シェルフがフォーカスを持つ間）は自動非表示を保留し、フォーカスが外れると再開。
- シェルフへのフォーカスは Perch をアクティブにしない方式のため、ドラッグ＆ドロップ時に
  元アプリのフォーカスを奪わない従来の挙動はそのまま。

## [0.1.1] - 2026-06-29

### Fixed

- シェルフからのドラッグ取り出しが「ファイルプロミス」方式になっており、Teams・Slack・VS Code など
  Electron / Web 系のドロップ先で実体のファイルにならず、テキスト扱いになってしまう問題を修正。
  実ファイル URL（`public.file-url`）を直接渡す AppKit ドラッグ源に置き換え、あらゆるアプリへ
  ファイルとして取り出せるようにした。

## [0.1.0] - 2026-06-20

最初のリリース。Yoink 系の「画面端の一時シェルフ」ワークフローを再現。

### Added

- 画面端に出てくるシェルフ（左右どちらにも配置可）。
- 端へのドラッグでシェルフを自動表示（ON/OFF 可）。
- ファイル / フォルダ / 画像 / テキスト / URL のドロップ取り込み。
- 取り込んだファイルはコピーして保持（元ファイルの移動・削除に強い）。
- シェルフのアイテムを他アプリ・フォルダへドラッグして取り出し。
- アイテムのダブルクリックで開く、ホバーで個別削除、ヘッダーから全消去。
- グローバルショートカット（表示/非表示・クリップボード取り込み・全消去）。
- 操作後の自動非表示（遅延時間を調整可能）。
- メニューバー常駐アイコン（中身の有無で表示が変化）と設定ウィンドウ。
- ログイン時起動オプション。
- アプリ終了後のアイテム保持オプション。
- GitHub Releases ベースの自動アップデート（通知 → ダウンロード → その場で置き換え）。

[0.2.0]: https://github.com/liasvistreamgamemusic-sketch/mac-tempstay/releases/tag/v0.2.0
[0.1.1]: https://github.com/liasvistreamgamemusic-sketch/mac-tempstay/releases/tag/v0.1.1
[0.1.0]: https://github.com/liasvistreamgamemusic-sketch/mac-tempstay/releases/tag/v0.1.0
