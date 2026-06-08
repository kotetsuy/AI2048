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

このスキルは「数手ごとに新セッションで呼ばれる」連続稼働を前提にする（方式A）。
**セッション開始時に newgame はしない**（前セッションのゲームを継続する）。ゲームは
ブラウザ側に残っているので、いきなり step から始めてよい。

1. **継続プレイ**: 指定手数（既定 8 手）まで次を繰り返す:
   1. `python3 {baseDir}/play2048_cdp.py step`
      → `read+solve+press` を1回で実行し、結果 JSON を返す。
        - `{"event":"move", "dir_ja":"左", "score":.., "max_tile":.., "board":[...]}` … 着手成功
        - `{"event":"won", ...}` … 2048達成 🎉
        - `{"event":"over", ...}` … ゲームオーバー
        - `{"event":"stuck", ...}` … 動かせる手なし
        - `{"event":"wait"}` … 盤面が過渡的に欠落。少し待って step を再試行。
   2. 直前の `move` の `dir_ja`/`max_tile`/`score` を一言でずんだもん実況にして
      `python3 {baseDir}/play2048_cdp.py narrate --text "<実況>"` を呼ぶ（語尾は「〜のだ」）。
      例: 「左に寄せて大きいタイルを左上に集めるのだ！」
2. **勝敗の演出**（event が won / over / stuck になったら）:
   - **won（2048達成）**: 盛大に勝利実況する。声色も変える＝
     `narrate --speaker 1 --text "やったのだーっ！ついに2048を作ったのだ！すごいのだ〜！"`
     （--speaker 1 = あまあま。盤面には 2048 の "You win!" が出るのでそれに合わせる）。
     その後 `python3 {baseDir}/play2048_cdp.py newgame` で次のゲームを始める。
   - **over（ゲームオーバー）/ stuck（手詰まり）**: 締めの実況をする＝
     `narrate --text "あ〜、ここで終わりなのだ……でも最大{max_tile}まで育てたのだ、惜しいのだ！"`
     その後 `newgame` で次のゲームを始める。
3. **報告**: その回で進めた手数と現在の score / max を一言で報告して終了（次セッションが続きを回す）。

## 注意
- 手の選択は CLI(expectimax) に任せる。あなたが方向を決めてはいけない。
- 実況は短く（テンポ重視）。盤面 JSON をそのまま読み上げない。
- narrate は喋り終わるまで自動で待つ（テンポ同期）。被らないので連続で呼んでよい。
- 喋れない/盤面が取れない等のエラーが出ても、ループは止めず次の step を試す（フォールバック）。
- 一括実行のフォールバック（実況なし・テンポ破綻時の保険）:
  `python3 {baseDir}/play2048_cdp.py play --newgame`（モノリシックに最後までプレイ）。
