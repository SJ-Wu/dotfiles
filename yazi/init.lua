-- Plugin setup. Installed plugins themselves live under plugins/ (tracked
-- via `ya pkg add`, see package.toml) — this just wires them up.

require("full-border"):setup {
	type = ui.Border.ROUNDED,
}

require("git"):setup {
	order = 1500,
}
