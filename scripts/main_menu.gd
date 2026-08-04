extends Control

@onready var title_label: Label = $Background/Content/Title
@onready var subtitle_label: Label = $Background/Content/Subtitle
@onready var new_game_button: Button = $Background/Content/Buttons/NewGame
@onready var continue_button: Button = $Background/Content/Buttons/Continue
@onready var options_button: Button = $Background/Content/Buttons/Options
@onready var credits_button: Button = $Background/Content/Buttons/Credits
@onready var quit_button: Button = $Background/Content/Buttons/Quit
@onready var modal: PanelContainer = $Modal
@onready var modal_title: Label = $Modal/Margin/VBox/ModalTitle
@onready var modal_body: Label = $Modal/Margin/VBox/ModalBody
@onready var close_button: Button = $Modal/Margin/VBox/Close

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	new_game_button.pressed.connect(_start_game)
	continue_button.pressed.connect(_continue_game)
	options_button.pressed.connect(_show_options)
	credits_button.pressed.connect(_show_credits)
	quit_button.pressed.connect(_quit_game)
	close_button.pressed.connect(_close_modal)
	modal.visible = false
	continue_button.disabled = true
	_apply_focus_style()
	new_game_button.grab_focus()

func _start_game() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

func _continue_game() -> void:
	# Kayıt sistemi eklendiğinde burası save dosyasını yükleyecek.
	_start_game()

func _show_options() -> void:
	modal_title.text = "AYARLAR"
	modal_body.text = "Ses, görüntü ve kontrol ayarları sonraki güncellemede bu panele bağlanacak.\n\nŞimdilik kontroller:\nWASD / Yön Tuşları: Hareket\nE veya F: Etkileşim\nJ / K: Saldırı\nQ / TAB: Dövüş stili\nESC: Duraklat"
	modal.visible = true
	close_button.grab_focus()

func _show_credits() -> void:
	modal_title.text = "HAKKINDA"
	modal_body.text = "SHADOW HUSTLE 3D\n\nTasarım ve geliştirme: Mehmet\nGodot entegrasyonu ve teknik geliştirme: OpenAI\n\nMenü yapısı Maaack's Game Template yaklaşımından uyarlanmıştır. Lisans bilgisi THIRD_PARTY_LICENSES.md dosyasındadır."
	modal.visible = true
	close_button.grab_focus()

func _close_modal() -> void:
	modal.visible = false
	new_game_button.grab_focus()

func _quit_game() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and modal.visible:
		_close_modal()

func _apply_focus_style() -> void:
	for button in [new_game_button, continue_button, options_button, credits_button, quit_button, close_button]:
		button.focus_mode = Control.FOCUS_ALL
