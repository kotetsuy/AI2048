---
name: play2048
description: 2048を自動プレイし毎手ずんだもんが実況する。AIが盤面を見て考えて指す実況デモ。
user-invocable: true
metadata: { "openclaw": { "requires": { "bins": ["python3"] }, "os": ["linux"] } }
---

# play2048 — 2048 自動プレイ＆実況

ホストの Chrome に表示された 2048 を、expectimax で解きながら自動プレイし、
1手ごとにずんだもん口調で実況するデモ。手の決定は同梱 Python(expectimax) が行い、
あなた（エージェント）は毎ターンの制御ループを回す役。

ツールはすべて同梱 CLI を `exec` で呼ぶ:
`python3 {baseDir}/play2048_cdp.py <サブコマンド>`（stdout に1行 JSON が返る）。

## 手順

1. **開始**: `python3 {baseDir}/play2048_cdp.py newgame` で新規ゲームを始める。
2. **毎ターン、次を繰り返す**:
   1. `python3 {baseDir}/play2048_cdp.py step`
      → `read+solve+press` を1回で実行し、結果 JSON を返す。
        - `{"event":"move", "dir_ja":"左", "score":.., "max_tile":.., "board":[...]}` … 着手成功
        - `{"event":"won", ...}` … 2048達成
        - `{"event":"over", ...}` … ゲームオーバー
        - `{"event":"stuck", ...}` … 動かせる手なし
   2. 直前の `move` の `board`/`dir_ja`/`max_tile` を一言でずんだもん実況にして
      `python3 {baseDir}/play2048_cdp.py narrate --text "<実況>"` を呼ぶ（語尾は「〜のだ」）。
      例: 「左に寄せて大きいタイルを左上に集めるのだ！」
   3. `event` が `won` / `over` / `stuck` になったらループを終了する。
3. **終了**: 結果（勝敗・最大タイル）を一言まとめて実況して締める。

## 注意
- 手の選択は CLI(expectimax) に任せる。あなたが方向を決めてはいけない。
- 実況は短く（テンポ重視）。盤面 JSON をそのまま読み上げない。
- 連続稼働や耐久確認では、毎ターン回す代わりに一括実行も可:
  `python3 {baseDir}/play2048_cdp.py play --newgame`（モノリシックに最後までプレイ。実況なし）。
  これはテンポ破綻時のフォールバック。通常デモは上の step→narrate ループを使う。
