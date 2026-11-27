class_name UIKit
extends RefCounted
## Shared look for all UI (LOOPR excluded): dark purple panels, neon accents.

const BG := Color("0e0b18")
const PANEL := Color("1c1730")
const PANEL_LIGHT := Color("2a2347")
const ACCENT := Color("b05cff")
const CYAN := Color("25d9f5")
const POP := Color("ff3d7f")
const GOLD := Color("f2c14e")
const TEXT := Color("f4efff")
const DIM := Color("9a91c0")


static func box(color: Color, radius := 12, border := Color(0, 0, 0, 0), border_w := 0, pad := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	return sb


static func label(text: String, size := 16, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func wrap_label(text: String, size := 15, color := DIM, min_w := 200.0) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = min_w
	return l


static func button(text: String, color := ACCENT, size := 16) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.add_theme_stylebox_override("normal", box(color, 10, Color(), 0, 14))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.15), 10, Color(), 0, 14))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.2), 10, Color(), 0, 14))
	b.add_theme_stylebox_override("disabled", box(color.darkened(0.55), 10, Color(), 0, 14))
	return b


static func stars(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(5 - n)
