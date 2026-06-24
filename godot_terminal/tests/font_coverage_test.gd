extends SceneTree

const UiText = preload("res://scripts/ui_text.gd")


func _init() -> void:
	var font = ResourceLoader.load("res://fonts/AGV_CJK.ttf") as Font
	assert(font != null)

	var missing: Array[String] = []
	var texts_to_check: Array[String] = []
	for language in UiText.DATA.values():
		for value in language.values():
			texts_to_check.append(str(value))

	for source_path in [
		"res://scripts/screens/mode_select_screen.gd",
	]:
		texts_to_check.append(FileAccess.get_file_as_string(source_path))

	for text in texts_to_check:
		for character in text:
			if character == "\n" or character == "\r" or character == "\t":
				continue
			if not font.has_char(character.unicode_at(0)):
				missing.append(character)

	assert(missing.is_empty(), "UI 字体缺少字符：%s" % "".join(missing))
	print("font_coverage_test: PASS")
	quit()
