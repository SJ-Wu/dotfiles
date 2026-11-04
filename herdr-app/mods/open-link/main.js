// Opens the URL on the clipboard in terminal-browser, in a split to the right
// of the focused pane. Bound in keys.json as `mod.open:open-link`: Herdr opens
// this as a 1x1 popup, it does its one job, then closes itself.
//
// Why a mod: a key in keys.json can only name a command plus one string value,
// and pane.split needs both `direction` and `argv`.
import { View, div } from "gpui-kit";
import { props, closeOverlay, run, notify } from "herdr";

const URL_RE = /https?:\/\/[^\s<>"'`]+/;

export default class OpenLink extends View {
  init(_props, cx) {
    // Only act when opened as a popup by the key. `herdr-app check` (and any
    // accidental docking into a layout) has no overlay, and must not split.
    const overlay = props()?.overlay;
    if (!overlay) return;
    const text = cx.read_from_clipboard() ?? "";
    const url = text.match(URL_RE)?.[0];
    closeOverlay(overlay);

    if (!url) {
      notify({
        title: "剪貼簿裡沒有網址",
        body: "先複製一個 http(s) 連結，再按一次快捷鍵。",
        level: "warning",
        timeout: 4000,
      });
      return;
    }
    run("pane.split", { direction: "right", argv: ["terminal-browser", "open", url] });
  }

  render(_cx) {
    return div();
  }
}
