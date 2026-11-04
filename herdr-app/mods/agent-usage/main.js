// Agent quota in the sidebar: Claude Code (5h + 7d) and Codex.
// Claude: ~/.cache/claude-usage/usage.json, written by claude/statusline.sh
//   in the dotfiles repo every time a Claude Code status line renders.
// Codex: the last `rate_limits` in its newest session logs
//   (~/.codex/sessions/YYYY/MM/DD/*.jsonl); Codex writes one per turn.
import { View, div, PathBuilder } from "gpui-kit";
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

function resetLabel(epoch, now, withDate) {
  if (!epoch) return "";
  if (epoch <= now) return "已重置";
  const d = new Date(epoch * 1000);
  const hm = `${pad(d.getHours())}:${pad(d.getMinutes())}`;
  return withDate
    ? `${d.getMonth() + 1}/${d.getDate()} 週${WEEKDAYS[d.getDay()]}`
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

  // A progress ring: a full track, then the remaining share drawn clockwise
  // from 12 o'clock. Paths are in px relative to the ring's own box.
  ring(t, frac, color, label) {
    const S = 58, W = 5, c = S / 2, r = (S - W) / 2;
    const layer = (path, col) => window.paint_path(path, col).absolute().top(0).left(0).size_full();
    const circle = () =>
      PathBuilder.stroke(W).move_to(c, c - r).arc_to(r, r, 0, false, true, c, c + r).arc_to(r, r, 0, false, true, c, c - r).build();
    const arc = () => {
      if (frac >= 0.999) return circle();
      const a = frac * 2 * Math.PI;
      return PathBuilder.stroke(W)
        .move_to(c, c - r)
        .arc_to(r, r, 0, frac > 0.5, true, c + r * Math.sin(a), c - r * Math.cos(a))
        .build();
    };
    return div()
      .relative()
      .size(S)
      .flex_none()
      .child(layer(circle(), t.border))
      .when(frac > 0.005, (el) => el.child(layer(arc(), color)))
      .child(
        div()
          .absolute()
          .top(0)
          .left(0)
          .size_full()
          .flex()
          .items_center()
          .justify_center()
          .text_size(12.5)
          .font_semibold()
          .text_color(color)
          .child(label)
      );
  }

  gauge(t, now, key, title, w) {
    const known = typeof w?.used === "number";
    // A window whose reset time has passed is fresh again, even if nothing
    // has refreshed the data since.
    const left = !known ? null : w.resets && w.resets <= now ? 100 : Math.max(0, Math.min(100, 100 - w.used));
    const color = left == null ? t.dim : left >= 50 ? t.ansi2 : left >= 20 ? t.ansi3 : t.ansi1;
    return v_flex()
      .id(key)
      .flex_1()
      .min_w(0)
      .items_center()
      .gap(4)
      .child(this.ring(t, (left ?? 0) / 100, color, left == null ? "—" : `${Math.round(left)}%`))
      .child(div().text_size(11.5).text_color(t.foreground).whitespace_nowrap().child(title))
      .child(div().text_size(10).text_color(t.dim).whitespace_nowrap().child(w ? resetLabel(w.resets, now, w.long) : "沒有資料"));
  }

  render(_cx) {
    const t = theme();
    const now = Math.floor(Date.now() / 1000);
    const cl = this.claude?.windows ?? [];
    const cx5 = cl.find((w) => !w.long);
    const cxw = cl.find((w) => w.long);
    // Codex: its longest window (the weekly one on every plan seen so far).
    const co = (this.codex?.windows ?? []).slice(-1)[0];

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
        h_flex()
          .px(10)
          .pt(4)
          .items_start()
          .child(this.gauge(t, now, "g-c5", "Claude 5h", cx5))
          .child(this.gauge(t, now, "g-cw", "Claude 週", cxw))
          .child(this.gauge(t, now, "g-xw", co && !co.long ? `Codex ${co.label}` : "Codex 週", co))
      );
  }
}
