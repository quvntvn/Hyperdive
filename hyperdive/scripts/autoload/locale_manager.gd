extends Node
class_name LocaleManager
# Autoload "Locale" — état de langue du jeu (FR/EN) + bascule live.
#
# Rôle : seul point qui parle à TranslationServer. Tient la langue courante (`current`),
# l'applique au démarrage, l'expose en lecture (le helper chapitres du lot 3 lira `Locale.current`),
# et la change à chaud via set_language() — qui émet `language_changed` pour que les écrans déjà
# ouverts rafraîchissent les libellés assignés EN CODE (les Control à clé .tscn se rafraîchissent
# tout seuls via NOTIFICATION_TRANSLATION_CHANGED).
#
# Persistance : DÉLÉGUÉE à Settings (Settings.language + settings.cfg). On ne crée pas un 2e fichier
# de save — Settings reste l'unique source de vérité disque. Cet autoload est chargé APRÈS Settings
# (cf. project.godot) → Settings.language est déjà lu quand on démarre ici.

signal language_changed(code: String)

const SUPPORTED: Array[String] = ["fr", "en"]
const FALLBACK: String = "en"     # tout ce qui n'est pas français part en anglais

var current: String = "en"

func _ready() -> void:
	var lang: String = Settings.language
	# 1er lancement (aucun choix persisté / valeur invalide) → langue de l'APPAREIL : "fr" si l'OS
	# est en français, sinon anglais. On persiste ce défaut tout de suite (décision actée : défaut =
	# langue détectée, persisté). Ensuite seul un choix explicite via set_language le remplace.
	if not SUPPORTED.has(lang):
		lang = "fr" if OS.get_locale_language() == "fr" else FALLBACK
		Settings.language = lang
		Settings.save_settings()
	current = lang
	TranslationServer.set_locale(current)

# Change la langue à chaud : applique au TranslationServer (les Control auto-traduits basculent
# seuls), persiste le choix, et signale aux écrans de réassigner leurs libellés posés en code.
func set_language(code: String) -> void:
	if not SUPPORTED.has(code):
		return
	current = code
	TranslationServer.set_locale(code)
	Settings.language = code
	Settings.save_settings()
	language_changed.emit(code)
