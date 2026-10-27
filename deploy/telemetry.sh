#!/usr/bin/env bash
#
# Usage per app, from the access log the proxy writes to the journal -- see
# "Usage telemetry" in docker/nginx.conf. Run on the VM as root, since the
# system journal is readable only by root and the systemd-journal group:
#
#   sudo ~/shiny-multiapp/deploy/telemetry.sh                # the last 7 days
#   sudo ~/shiny-multiapp/deploy/telemetry.sh 2026-10-01     # since a date
#   sudo ~/shiny-multiapp/deploy/telemetry.sh "30 days ago"  # any journalctl --since
#
# Or pass "-" and give it a log on stdin, which is how to try it locally:
#
#   docker compose logs --no-log-prefix proxy | deploy/telemetry.sh -
#
# Days are counted in Canberra time; set TZ to count them in another zone.

set -euo pipefail

since="${1:-7 days ago}"
export TZ="${TZ:-Australia/Canberra}"

if [[ "${since}" == "-" ]]; then
  read_log() { cat; }
else
  if [[ $EUID -ne 0 ]]; then
    echo "telemetry.sh reads the system journal and must run as root: sudo $0" >&2
    exit 1
  fi
  # By unit rather than by container: every deploy recreates the container,
  # but the unit keeps its name, so this reaches back across restarts. nginx's
  # stdout is there because podman's log driver defaults to journald.
  read_log() {
    journalctl -u shiny-proxy.service --since "${since}" -o cat --no-pager
  }
fi

read_log | jq -nRr '
  # A websocket needs JavaScript, so a session is a person in a browser. A page
  # load can be anything, so known robots and the curl health checks deploy.sh
  # runs are left out of those.
  def robot:
    (.user_agent // "")
    | test("bot|crawl|spider|slurp|curl|wget|python|httpclient|go-http|monitor|probe|^$"; "i");

  # Nearest rank, so a percentile is always a session that actually happened.
  def pct(p): sort | if length == 0 then null else .[(length * p | ceil) - 1] end;

  def two: tostring | if length < 2 then "0" + . else . end;
  def clock:
    if . == null then "-"
    else floor as $s
      | if $s < 60 then "\($s)s"
        elif $s < 3600 then "\($s / 60 | floor)m\($s % 60 | two)s"
        else "\($s / 3600 | floor)h\($s % 3600 / 60 | floor | two)m"
        end
    end;

  def stamp(fmt): .ts | localtime | strflocaltime(fmt);

  def table:
    map(map(tostring)) as $rows
    | [range(0; $rows[0] | length) as $i | $rows | map(.[$i] | length) | max] as $w
    | $rows[]
    | [range(0; length) as $i | .[$i] + " " * ($w[$i] - (.[$i] | length))]
    | join("  ") | sub(" +$"; "");

  [inputs | fromjson? | objects | select(.kind)] as $log
  | ($log | map(select(.kind == "session" and .status == 101))) as $sessions
  | ($log | map(select(.kind == "page" and (.status == 200 or .status == 304)
                       and (robot | not)))) as $pages
  | ([$sessions[], $pages[]] | map(.app) | unique) as $apps

  | if ($apps | length) == 0 then
      "No sessions or page loads in this window."
    else
      "Records from \($log | min_by(.ts) | stamp("%Y-%m-%d %H:%M")) to \($log | max_by(.ts) | stamp("%Y-%m-%d %H:%M")) (\(env.TZ))",
      "",
      ([["app", "sessions", "median", "p90", "longest", "page loads", "networks", "5xx"]]
       + [$apps[] as $app
          | ($sessions | map(select(.app == $app))) as $s
          | ($s | map(.seconds)) as $len
          | [$app, ($s | length), ($len | pct(0.5) | clock), ($len | pct(0.9) | clock),
             ($len | max | clock),
             ($pages | map(select(.app == $app)) | length),
             ($s | map(.client) | unique | length),
             ($log | map(select(.app == $app and .status >= 500)) | length)]]
       | table),
      "",
      "Sessions by day",
      ([["date"] + $apps]
       + ($sessions | group_by(stamp("%Y-%m-%d"))
          | map((.[0] | stamp("%Y-%m-%d")) as $day
                | group_by(.app) | map({key: .[0].app, value: length}) | from_entries
                | [$day] + [$apps[] as $app | .[$app] // 0]))
       | table)
    end
'
