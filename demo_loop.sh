#!/usr/bin/env bash
# 連続稼働＋自動リスタート（Phase 3 / 方式A: OpenClaw 中心・数手ごと新セッション）。
#
# 外側ループが毎回フレッシュな --session-key で OpenClaw エージェントを呼び、
# play2048 スキルの手順で「いまのゲームを数手 step→narrate」→ 終局なら勝敗演出＋newgame。
# これで OpenClaw を制御の中心に保ったまま（受け入れ基準）、コンテキスト溢れも無限ゲームも回避。
#
# フォールバック堅牢化:
#   - 各セッションは timeout 付き。失敗/タイムアウトしても次セッションへ（デモは止めない）。
#   - サービス(gateway/Chrome CDP/three-vrm)が落ちていたら待って再確認してから回す。
#
# 使い方:
#   ./demo_loop.sh                 # 連続実行（Ctrl-C で停止）
#   DEMO_MOVES=12 ./demo_loop.sh   # 1セッションの手数を変更（既定 8）
#   DEMO_FRESH=0 ./demo_loop.sh    # 開始時の newgame をしない（現在のゲームを継続）
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="${ROOT}/openclaw-demo"
SKILL_CLI="/home/node/.openclaw/workspace/skills/play2048/play2048_cdp.py"

MOVES="${DEMO_MOVES:-8}"          # 1セッションあたりの手数
GAP="${DEMO_GAP:-2}"             # セッション間の待ち(秒)
SESSION_TIMEOUT="${DEMO_SESSION_TIMEOUT:-300}"
FRESH="${DEMO_FRESH:-1}"         # 1: 開始時に newgame して仕切り直す

GW_HEALTH="http://localhost:18789/healthz"
CDP_HEALTH="http://localhost:9222/json/version"
VRM_HEALTH="http://localhost:8000/status"

MSG="play2048 スキルの手順で、いまのゲームを step→narrate で最大${MOVES}手すすめて実況してください。\
step の event が won なら盛大に勝利演出（narrate --speaker 1）、over か stuck なら締めの実況をして、\
そのあと必ず newgame で次のゲームを始めてください。最後にその回の手数と現在の score / max を一言で報告してください。"

log() { printf '\033[1;36m[demo_loop]\033[0m %s\n' "$*"; }

compose() { ( cd "$COMPOSE_DIR" && docker compose "$@" ); }

services_ready() {
    curl -sf -o /dev/null -m2 "$GW_HEALTH"  2>/dev/null || return 1
    curl -sf -o /dev/null -m2 "$CDP_HEALTH" 2>/dev/null || return 1
    curl -sf -o /dev/null -m2 "$VRM_HEALTH" 2>/dev/null || return 1
    return 0
}

stopping=0
trap 'stopping=1; log "停止要求を受けました。現在のセッション後に終了します。"' INT TERM

[[ -f "${COMPOSE_DIR}/docker-compose.yml" ]] || { echo "compose が見つかりません: $COMPOSE_DIR" >&2; exit 1; }

# サービスが揃うまで待つ（start_all.sh 直後など）。
until services_ready; do
    (( stopping )) && exit 0
    log "サービス未準備（gateway/CDP/three-vrm のいずれか）。10秒待って再確認..."
    sleep 10
done

# 開始時に新規ゲームで仕切り直し（任意）。
if [[ "$FRESH" == "1" ]]; then
    log "新規ゲームで開始します"
    compose run --rm -T --entrypoint sh openclaw-cli -c "python3 ${SKILL_CLI} newgame" >/dev/null 2>&1 \
        || log "  newgame に失敗（無視して継続）"
fi

i=0
while (( ! stopping )); do
    i=$((i+1))
    if ! services_ready; then
        log "サービスが落ちています。10秒待って再確認..."
        sleep 10
        continue
    fi
    log "セッション #$i（最大 ${MOVES} 手）"
    if timeout "$SESSION_TIMEOUT" \
         bash -c "cd '$COMPOSE_DIR' && docker compose run --rm -T openclaw-cli \
           agent --agent main --session-key 'loop$(date +%s)_$i' --message \"\$1\"" _ "$MSG"; then
        :
    else
        rc=$?
        log "セッション #$i 失敗/タイムアウト (rc=$rc)。${GAP}s 後に再試行"
    fi
    sleep "$GAP"
done

log "ループ終了"
