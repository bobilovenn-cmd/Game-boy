extends SceneTree

const UiText = preload("res://scripts/ui_text.gd")


func _init() -> void:
	var font = ResourceLoader.load("res://fonts/AGV_CJK.ttf") as Font
	assert(font != null)

	var missing: Array[String] = []
	for language in UiText.DATA.values():
		for value in language.values():
			for character in str(value):
				if character == "\n" or character == "\r" or character == "\t":
					continue
				if not font.has_char(character.unicode_at(0)):
					missing.append(character)

	assert(missing.is_empty(), "UI 字体缺少字符：%s" % "".join(missing))
	print("font_coverage_test: PASS")
	quit()
