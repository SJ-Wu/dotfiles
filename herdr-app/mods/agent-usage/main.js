// Agent quota in the sidebar: Claude Code (5h + 7d) and Codex.
// Claude: ~/.cache/claude-usage/usage.json, written by claude/statusline.sh
//   in the dotfiles repo every time a Claude Code status line renders.
// Codex: the last `rate_limits` in its newest session logs
//   (~/.codex/sessions/YYYY/MM/DD/*.jsonl); Codex writes one per turn.
import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { exec, home, readTextFile, watchFolder, theme } from "herdr";

const CLAUDE_DIR = `${home()}/.cache/claude-usage`;
const CLAUDE_FILE = `${CLAUDE_DIR}/usage.json`;
// Newest few logs, first one that has a rate_limits object (a session that
// has not finished a turn yet has none).
const CODEX_SCRIPT = `
for f in $(ls -t "$HOME"/.codex/sessions/*/*/*/*.jsonl 2>/dev/null | head -5); do
  l=$(grep '"rate_limits":{' "$f" | tail -1)
  if [ -n "$l" ]; then printf '%s\\n' "$l"; exit 0; fi
done`;
const WEEKDAYS = ["日", "一", "二", "三", "四", "五", "六"];

const pad = (n) => String(n).padStart(2, "0");

function ago(sec) {
  if (sec < 60) return "剛剛";
  if (sec < 3600) return `${Math.floor(sec / 60)} 分鐘前`;
  if (sec < 86400) return `${Math.floor(sec / 3600)} 小時前`;
  return `${Math.floor(sec / 86400)} 天前`;
}

function resetLabel(epoch, now, withDate) {
  if (!epoch) return "";
  if (epoch <= now) return "已重置";
  const d = new Date(epoch * 1000);
  const hm = `${pad(d.getHours())}:${pad(d.getMinutes())}`;
  return withDate
    ? `${d.getMonth() + 1}/${d.getDate()} 週${WEEKDAYS[d.getDay()]} ${hm} 重置`
    : `${hm} 重置`;
}

function windowLabel(minutes) {
  if (minutes === 300) return "5 小時";
  if (minutes === 10080) return "本週";
  if (minutes % 1440 === 0) return `${minutes / 1440} 天`;
  return `${Math.round(minutes / 60)} 小時`;
}

// Both sources normalised to { windows: [{label, used, resets, long}], updated }.
function fromClaude(d) {
  if (!d) return null;
  return {
    windows: [
      { label: "5 小時", used: d.five_hour?.used_percentage, resets: d.five_hour?.resets_at, long: false },
      { label: "本週", used: d.seven_day?.used_percentage, resets: d.seven_day?.resets_at, long: true },
    ],
    updated: d.updated_at,
  };
}

function fromCodex(line) {
  if (!line) return null;
  const ev = JSON.parse(line);
  const rl = ev?.payload?.rate_limits;
  if (!rl) return null;
  const windows = [rl.primary, rl.secondary]
    .filter(Boolean)
    .sort((a, b) => (a.window_minutes ?? 0) - (b.window_minutes ?? 0))
    .map((w) => ({
      label: windowLabel(w.window_minutes ?? 0),
      used: w.used_percent,
      resets: w.resets_at,
      long: (w.window_minutes ?? 0) >= 1440,
    }));
  const ts = Date.parse(ev.timestamp ?? "");
  return { windows, updated: Number.isNaN(ts) ? null : Math.floor(ts / 1000) };
}

export default class AgentUsage extends View {
  init(_props, cx) {
    this.claude = null;
    this.codex = null;
    this.reload(cx);
    // Claude: live, whenever the statusline rewrites its file.
    cx.spawn(async (cx) => {
      for (;;) {
        try {
          await watchFolder(CLAUDE_DIR);
        } catch {
          return; // folder missing: the timer below still picks it up
        }
        await this.loadClaude();
        cx.notify();
      }
    });
    // Codex logs churn on every token, so poll them instead of watching;
    // this also ticks relative times ("3 分鐘前", "已重置").
    cx.timer.every(30000, (cx) => this.reload(cx));
  }

  reload(cx) {
    cx.spawn(async (cx) => {
      await Promise.all([this.loadClaude(), this.loadCodex()]);
      cx.notify();
    });
  }

  async loadClaude() {
    try {
      const text = await readTextFile(CLAUDE_FILE);
      this.claude = text ? fromClaude(JSON.parse(text)) : null;
    } catch {
      // keep the last good data
    }
  }

  async loadCodex() {
    try {
      const r = await exec("/bin/sh", ["-c", CODEX_SCRIPT]);
      this.codex = fromCodex(r.stdout.trim()) ?? this.codex;
    } catch {
      // keep the last good data
    }
  }

  row(t, now, w) {
    const known = typeof w.used === "number";
    // A window whose reset time has passed is fresh again, even if nothing
    // has refreshed the data since.
    const left = !known ? null : w.resets && w.resets <= now ? 100 : Math.max(0, Math.min(100, 100 - w.used));
    const color = left == null ? t.dim : left >= 50 ? t.ansi2 : left >= 20 ? t.ansi3 : t.ansi1;

    return v_flex()
      .gap(4)
      .child(
        h_flex()
          .justify_between()
          .items_center()
          .child(div().text_size(12.5).text_color(t.foreground).child(w.label))
          .child(
            div()
              .text_size(12.5)
              .font_semibold()
              .text_color(color)
              .child(left == null ? "—" : `剩 ${Math.round(left)}%`)
          )
      )
      .child(
        div()
          .h(4)
          .w_full()
          .rounded(2)
          .bg(t.border)
          .child(div().h(4).rounded(2).bg(color).w(`${left ?? 0}%`))
      )
      .child(div().text_size(11).text_color(t.dim).child(resetLabel(w.resets, now, w.long)));
  }

  section(t, now, title, data, empty) {
    const head = h_flex()
      .justify_between()
      .items_center()
      .child(div().text_size(11.5).font_medium().text_color(t.muted).child(title))
      .when(Boolean(data?.updated), (el) =>
        el.child(div().text_size(10.5).text_color(t.dim).child(ago(Math.max(0, now - data.updated))))
      );
    const body = !data || data.windows.length === 0
      ? div().text_size(11.5).text_color(t.dim).child(empty)
      : v_flex().gap(10).children(data.windows.map((w) => this.row(t, now, w)));
    return v_flex().gap(8).child(head).child(body);
  }

  render(_cx) {
    const t = theme();
    const now = Math.floor(Date.now() / 1000);

    return v_flex()
      .size_full()
      .min_h(0)
      .bg(t.chrome)
      .border_t(1)
      .border_color(t.border)
      .child(
        h_flex()
          .px(16)
          .h(41)
          .pt(14)
          .pb(5)
          .flex_none()
          .items_center()
          .child(div().text_size(11.5).font_medium().text_color(t.dim).child("用量"))
      )
      .child(
        v_flex()
          .id("usage-body")
          .flex_1()
          .min_h(0)
          .px(16)
          .pb(10)
          .gap(14)
          .overflow_y_scrollbar()
          .child(this.section(t, now, "Claude", this.claude, "開一個 Claude Code session 就會出現"))
          .child(this.section(t, now, "Codex", this.codex, "跑過一輪 Codex 就會出現"))
      );
  }
}
