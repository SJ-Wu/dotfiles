// A Kanban board of every agent: one column per status, filterable by space.
// Opened as a popup by `mod.open:kanban` (keys.json: cmd-shift-k, or the
// Kanban button in my-tabs); the same key or Esc closes it.
//
// Each card shows what the agent is saying (picked out of its screen with
// `hc read`), how long it has been in this state (colored when that is too
// long), and its sub-agents. Select a card to act on it: jump to it, pin it,
// put its tab away (settle), end it, or reply to it from the box at the bottom.
//
// Keys: h/l column, j/k card, Enter jump, r reply, p pin, s settle,
// x end (press twice), 0 every space, 1-9 one space. Esc closes the board
// (or, in the reply box, goes back to the cards).
import { View, div, image, svg } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { agents, terminals, spaces, run, hc, theme, props, closeOverlay, notify } from "herdr";

const COLUMNS = [
  { status: "blocked", label: "Needs you" },
  { status: "working", label: "Working" },
  { status: "done", label: "Done" },
  { status: "idle", label: "Idle" },
];
const RANK = { blocked: 4, done: 3, working: 2, idle: 1 };
// Minutes in a state before its time turns yellow, then red.
const SLOW = { blocked: [5, 15], working: [30, 90] };

const clean = (s) => (s ?? "").replace(/^[^\p{L}\p{N}]+/u, "").trim();

function duration(ms) {
  const m = Math.floor(ms / 60000);
  if (m < 1) return "<1m";
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  return h < 24 ? `${h}h` : `${Math.floor(h / 24)}d`;
}

function icon(p, size, color) {
  if (!p?.icon) return null;
  return p.tint ? svg(p.icon).size(size).flex_none().text_color(color) : image(p.icon).w(size).h(size).flex_none();
}

function cardTitle(a, tab) {
  if (tab?.named) return tab.name;
  const live = clean(a.title);
  if (live && live !== a.program?.name && !/^[~/]/.test(live)) return live;
  return a.program?.name ?? tab?.name ?? a.address;
}

// A sub-agent's status as a plain word; error counts as needing you.
const kidStatus = (k) => {
  const s = typeof k.status === "string" ? k.status : k.status?.state;
  return s === "error" ? "blocked" : s ?? "idle";
};

// --- reading what an agent is saying off its screen -------------------------
// Claude Code and Codex both end the screen with an input line (❯ / ›) and a
// status bar, so the news is the few lines just above the input. A question
// (a permission dialog) is shown with the options under it.
const RULE = /^[\s─━═\-—_│┃╭╮╰╯┌┐└┘├┤┬┴┼·•]*$/;
const PROMPT = /^\s*[❯›>](\s|$)/;
const QUESTION = /\?|？|proceed|allow|approve|permission|允許|是否|要不要/i;
const OPTION = /^\s*(❯\s*)?\d+[.)]/;
// Timing lines and tips the agents print under their answer: not news.
const NOISE = /^\s*[✻✶✳✢✽*]\s+\S+ for |new task\?|\/clear to save|Worked for |esc to interrupt|Auto-update|Tip: /i;

function preview(text, status) {
  const lines = (text ?? "").split("\n").map((l) => l.replace(/\s+$/, ""));
  const keep = (l) => !RULE.test(l) && !NOISE.test(l);
  if (status === "blocked") {
    for (let i = lines.length - 1; i >= 0; i--) {
      if (!QUESTION.test(lines[i]) || OPTION.test(lines[i])) continue;
      const out = lines.slice(Math.max(0, i - 4), i + 1).filter(keep).slice(-3);
      for (let j = i + 1; j < lines.length && out.length < 8; j++) {
        if (OPTION.test(lines[j])) out.push(lines[j]);
        else if (keep(lines[j]) && out.length > 3) break;
      }
      return out.slice(-8);
    }
  }
  let end = lines.length;
  for (let i = lines.length - 1; i >= 0; i--) if (PROMPT.test(lines[i])) { end = i; break; }
  return lines.slice(0, end).filter(keep).slice(-3);
}

export default class Kanban extends View {
  init(_props, cx) {
    this.space = null; // null: every space
    this.sel = null; // selected agent address
    this.screens = {}; // address -> preview lines
    this.armed = null; // address armed for "end" (second x kills)
    this.grid = []; // columns of addresses as last rendered, for the keys
    this.handle = cx.focus_handle();
    this.handle.focus();
    this.input = InputState.new({ placeholder: "選一張卡片，按 r 回覆…" });
    this.input.on("submit", (_e, cx) => this.reply(cx));
    this.input.on("focus", (_e, cx) => { this.typing = true; cx.notify(); });
    this.input.on("blur", (_e, cx) => { this.typing = false; cx.notify(); });
    this.refresh(cx);
    // Screens change while it's open; durations tick.
    cx.timer.every(4000, (cx) => this.refresh(cx));
  }

  refresh(cx) {
    cx.spawn(async (cx) => {
      const list = agents();
      const reads = await Promise.all(
        list.map((a) => hc(["read", a.address]).then((r) => [a, r.stdout], () => [a, null]))
      );
      for (const [a, text] of reads) if (text != null) this.screens[a.address] = preview(text, a.status);
      cx.notify();
    });
  }

  close() {
    const id = props()?.overlay;
    if (id) closeOverlay(id);
  }

  selected() {
    return agents().find((a) => a.address === this.sel) ?? null;
  }

  jump(a) {
    if (!a) return;
    run("pane.focus", { pane: a.pane });
    this.close();
  }

  // A permission question only takes typing with --force, which may answer it:
  // that is the point of replying to a blocked agent.
  reply(cx) {
    const a = this.selected();
    const text = this.input.value().trim();
    if (!a || !text) return;
    const args = ["send", ...(a.status === "blocked" ? ["--force"] : []), a.address, text];
    this.input.set_value("");
    cx.spawn(async (cx) => {
      const r = await hc(args).catch((e) => ({ code: 1, stderr: String(e) }));
      if (r.code !== 0) notify({ title: "送不出去", body: (r.stderr || r.stdout || "").trim().slice(0, 200), level: "error" });
      this.refresh(cx);
      cx.notify();
    });
  }

  pin(a) {
    if (a) run("terminal.pin", { terminal: a.address, pinned: !a.pinned });
  }

  settle(a) {
    if (a) run("tab.settle", { id: a.tab });
  }

  // First press arms it, the second ends the agent.
  end(a, cx) {
    if (!a) return;
    if (this.armed === a.address) {
      run("terminal.kill", { terminal: a.address });
      this.armed = null;
    } else {
      this.armed = a.address;
      cx.timer.after(3000, (cx) => { if (this.armed === a.address) { this.armed = null; cx.notify(); } });
    }
    cx.notify();
  }

  // Moves the selection: dc columns, dr rows, as the board was last drawn.
  move(dc, dr) {
    const cols = this.grid;
    let c = cols.findIndex((col) => col.includes(this.sel));
    let r = c < 0 ? -1 : cols[c].indexOf(this.sel);
    if (c < 0) {
      c = cols.findIndex((col) => col.length > 0);
      if (c < 0) return;
      this.sel = cols[c][0];
      return;
    }
    if (dc) {
      for (let n = c + dc; n >= 0 && n < cols.length; n += dc) {
        if (cols[n].length) { this.sel = cols[n][Math.min(r, cols[n].length - 1)]; return; }
      }
      return;
    }
    r = Math.max(0, Math.min(cols[c].length - 1, r + dr));
    this.sel = cols[c][r];
  }

  key(e, cx) {
    if (this.typing) {
      if (e.key === "escape") { this.handle.focus(); cx.stop_propagation(); }
      return;
    }
    const a = this.selected();
    const k = e.key;
    if (k === "h" || k === "left") this.move(-1, 0);
    else if (k === "l" || k === "right") this.move(1, 0);
    else if (k === "j" || k === "down") this.move(0, 1);
    else if (k === "k" || k === "up") this.move(0, -1);
    else if (k === "enter") this.jump(a);
    else if (k === "r" || k === "i") { if (a) this.input.focus(); }
    else if (k === "p") this.pin(a);
    else if (k === "s") this.settle(a);
    else if (k === "x") this.end(a, cx);
    else if (k === "0") this.space = null;
    else if (/^[1-9]$/.test(k)) this.space = spaces()[Number(k) - 1]?.id ?? this.space;
    else return;
    cx.stop_propagation();
    cx.notify();
  }

  chip(t, id, label, count, color, n) {
    const on = this.space === id;
    return h_flex()
      .id(`sp-${id ?? "all"}`)
      .flex_none()
      .h(26)
      .px(10)
      .gap(6)
      .items_center()
      .rounded(13)
      .border(1)
      .border_color(on ? t.accent : t.border)
      .when(on, (el) => el.bg(t.selected))
      .cursor_pointer()
      .hover((s) => s.bg(t.hover))
      .on_click((_e, cx) => { this.space = id; cx.notify(); })
      .child(div().text_size(10).text_color(t.dim).child(String(n)))
      .when(Boolean(color), (el) => el.child(div().size(7).rounded_full().bg(color)))
      .child(div().text_size(12).text_color(on ? t.foreground : t.muted).child(label))
      .child(div().text_size(11).text_color(t.dim).child(String(count)));
  }

  action(t, id, iconPath, tip, color, onClick) {
    return div()
      .id(id)
      .flex_none()
      .p(3)
      .rounded(5)
      .text_color(color ?? t.dim)
      .cursor_pointer()
      .hover((s) => s.bg(t.hover).text_color(t.foreground))
      .tooltip(tip)
      .on_click((_e, cx) => { cx.stop_propagation(); onClick(cx); cx.notify(); })
      .child(svg(iconPath).size(13));
  }

  timeColor(t, status, ms) {
    const [warn, bad] = SLOW[status] ?? [];
    const m = ms / 60000;
    if (bad != null && m >= bad) return t.blocked;
    if (warn != null && m >= warn) return t.working;
    return t.dim;
  }

  card(t, now, a, ctx) {
    const { tabs, spaceById, kidsOf } = ctx;
    const tab = tabs.get(a.tab);
    const sp = spaceById.get(a.space);
    const since = a.status === "working" ? tab?.working_since : tab?.changed_at;
    const machine = a.address.includes("/") ? a.address.split("/")[0] : null;
    const meta = [a.space_name, sp?.branch, machine].filter(Boolean).join(" · ");
    const pic = icon(a.program, 16, t.foreground);
    const on = this.sel === a.address;
    const lines = this.screens[a.address] ?? [];
    const kids = kidsOf(a.address);
    const top = kids.reduce((m, k) => ((RANK[kidStatus(k)] ?? 0) > (RANK[m] ?? 0) ? kidStatus(k) : m), null);
    const armed = this.armed === a.address;

    const actions = h_flex()
      .gap(2)
      .flex_none()
      .child(this.action(t, `go-${a.address}`, "mods/kanban/jump.svg", "跳過去 (Enter)", null, () => this.jump(a)))
      .child(this.action(t, `pin-${a.address}`, `mods/workspace-chrome/${a.pinned ? "pin-off" : "pin"}.svg`, a.pinned ? "取消釘選 (p)" : "釘選 (p)", null, () => this.pin(a)))
      .child(this.action(t, `settle-${a.address}`, "mods/workspace-chrome/archive.svg", "收起這個 tab (s)", null, () => this.settle(a)))
      .child(this.action(t, `end-${a.address}`, "mods/workspace-chrome/x.svg", armed ? "再按一次結束" : "結束 agent (x 兩次)", armed ? t.blocked : null, (cx) => this.end(a, cx)));

    return v_flex()
      .id(`card-${a.address}`)
      .flex_none()
      .p(10)
      .gap(6)
      .rounded(8)
      .bg(on ? t.selected : t.surface)
      .border(1)
      .border_color(armed ? t.blocked : on ? t.accent : t.border)
      .cursor_pointer()
      .hover((s) => s.bg(on ? t.selected : t.hover))
      .on_click((_e, cx) => { this.sel = a.address; this.handle.focus(); cx.notify(); })
      .child(
        h_flex()
          .gap(8)
          .items_center()
          .when(Boolean(pic), (el) => el.child(pic))
          .child(div().flex_1().min_w(0).truncate().text_size(13).text_color(t.foreground).child(cardTitle(a, tab)))
          .when(a.pinned && !on, (el) => el.child(svg("mods/workspace-chrome/pin.svg").size(12).text_color(t.dim)))
          .when(on, (el) => el.child(actions))
      )
      .when(lines.length > 0, (el) =>
        el.child(
          v_flex()
            .px(8)
            .py(6)
            .gap(1)
            .rounded(6)
            .bg(t.background)
            .children(lines.map((l, i) =>
              div().id(`ln-${a.address}-${i}`).truncate().text_size(11).text_color(a.status === "blocked" ? t.foreground : t.muted).child(l.trim() || " ")
            ))
        )
      )
      .when(kids.length > 0, (el) =>
        el.child(
          h_flex()
            .gap(6)
            .items_center()
            .child(div().size(6).rounded_full().bg(t[top] ?? t.dim))
            .child(div().text_size(11).text_color(t.muted).child(`子 agent ×${kids.length}`))
            .when(top === "blocked", (el) => el.child(div().text_size(11).text_color(t.blocked).child("有一個需要你")))
        )
      )
      .child(
        h_flex()
          .gap(8)
          .items_center()
          .justify_between()
          .child(div().flex_1().min_w(0).truncate().text_size(11).text_color(t.dim).child(meta))
          .when(Boolean(since), (el) =>
            el.child(div().flex_none().text_size(11).text_color(this.timeColor(t, a.status, now - since)).child(duration(now - since)))
          )
      );
  }

  column(t, now, col, cards, ctx) {
    const color = t[col.status] ?? t.dim;
    return v_flex()
      .flex_1()
      .min_w(0)
      .min_h(0)
      .rounded(10)
      .bg(t.chrome)
      .border(1)
      .border_color(t.border)
      .child(
        h_flex()
          .flex_none()
          .h(40)
          .px(12)
          .gap(8)
          .items_center()
          .border_b(1)
          .border_color(t.border)
          .child(div().size(8).rounded_full().bg(color))
          .child(div().text_size(12.5).font_semibold().text_color(t.foreground).child(col.label))
          .child(div().text_size(12).text_color(t.dim).child(String(cards.length)))
      )
      .child(
        v_flex()
          .id(`col-${col.status}`)
          .flex_1()
          .min_h(0)
          .p(8)
          .gap(8)
          .overflow_y_scrollbar()
          .when(cards.length === 0, (el) => el.child(div().p(8).text_size(12).text_color(t.dim).child("—")))
          .children(cards.map((a) => this.card(t, now, a, ctx)))
      );
  }

  replyBar(t) {
    const a = this.selected();
    const who = a ? `回覆 ${a.space_name} · ${cardTitle(a, null)}` : "沒有選取卡片";
    return h_flex()
      .flex_none()
      .gap(10)
      .items_center()
      .child(div().flex_none().max_w(260).truncate().text_size(12).text_color(a ? t.muted : t.dim).child(who))
      .child(
        Input.new(this.input)
          .flex_1()
          .h(34)
          .px(10)
          .rounded(8)
          .border_1()
          .border_color(this.typing ? t.accent : t.input)
          .bg(t.surface)
          .text_size(12.5)
          .text_color(t.foreground)
      )
      .child(div().flex_none().text_size(11).text_color(t.dim).child(this.typing ? "Enter 送出 · Esc 回卡片" : ""));
  }

  render(_cx) {
    const t = theme();
    const now = Date.now();
    const all = agents();
    const sps = spaces();
    const terms = terminals();
    const tabs = new Map(sps.flatMap((s) => s.tabs).map((tab) => [tab.id, tab]));
    const spaceById = new Map(sps.map((s) => [s.id, s]));
    const kidsOf = (addr) => {
      const direct = terms.filter((k) => k.parent === addr && k.state === "live");
      return direct.flatMap((k) => [k, ...kidsOf(k.address)]);
    };
    if (this.space && !spaceById.has(this.space)) this.space = null;

    const shown = all.filter((a) => !this.space || a.space === this.space);
    const byStatus = (status) =>
      shown
        .filter((a) => (RANK[a.status] ? a.status : "idle") === status)
        .sort((x, y) => Number(y.pinned) - Number(x.pinned) || y.seq - x.seq);
    const cols = COLUMNS.map((c) => byStatus(c.status));
    this.grid = cols.map((list) => list.map((a) => a.address));
    // Keep a selection whenever there is something to select.
    if (!shown.some((a) => a.address === this.sel)) this.sel = this.grid.flat()[0] ?? null;
    const ctx = { tabs, spaceById, kidsOf };

    return v_flex()
      .id("kanban")
      .track_focus(this.handle)
      .on_key_down((e, cx) => this.key(e, cx))
      .size_full()
      .bg(t.background)
      .p(16)
      .gap(12)
      .child(
        h_flex()
          .flex_none()
          .items_center()
          .justify_between()
          .child(div().text_size(15).font_semibold().text_color(t.foreground).child("Agents"))
          .child(div().text_size(11).text_color(t.dim).child("h/j/k/l 移動 · Enter 跳過去 · r 回覆 · p 釘選 · s 收起 · x×2 結束 · 0-9 space · Esc 關閉"))
      )
      .child(
        h_flex()
          .id("spaces")
          .flex_none()
          .gap(8)
          .overflow_x_scroll()
          .child(this.chip(t, null, "全部", all.length, null, 0))
          .children(sps.map((s, i) =>
            this.chip(t, s.id, s.name, all.filter((a) => a.space === s.id).length, s.status ? t[s.status] : null, i + 1)
          ))
      )
      .child(
        h_flex()
          .flex_1()
          .min_h(0)
          .gap(12)
          .items_stretch()
          .children(COLUMNS.map((c, i) => this.column(t, now, c, cols[i], ctx)))
      )
      .child(this.replyBar(t));
  }
}
