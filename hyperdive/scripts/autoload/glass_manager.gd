extends Node
# Autoload "Glass" : applique automatiquement le backdrop-blur derrière CHAQUE
# bouton du jeu (menu, shop, pause, etc.) sans toucher aux scènes une par une.
# Écoute node_added → un seul mécanisme, mutualisé.
#
# === TOGGLE PERF ===
# USE_REAL_BLUR = true  → vrai flou (BackBufferCopy via hint_screen_texture).
# USE_REAL_BLUR = false → aucun flou ; les boutons gardent le verre du thème
#                         (arête claire + ombre + fond translucide) = repli zéro coût.
const USE_REAL_BLUR := true

func _ready() -> void:
	if not USE_REAL_BLUR:
		return
	get_tree().node_added.connect(_on_node_added)
	# Boutons déjà présents au lancement (scène de départ).
	_scan(get_tree().root)

func _scan(node: Node) -> void:
	if _is_glass_target(node):
		_attach(node)
	for child in node.get_children():
		_scan(child)

func _on_node_added(node: Node) -> void:
	if _is_glass_target(node):
		# Différé : le parent est en cours de configuration au moment du signal.
		_attach.call_deferred(node)

func _is_glass_target(node: Node) -> bool:
	# Boutons texte uniquement. On exclut TextureButton (engrenage) car il n'hérite
	# pas de Button, et OptionButton/MenuButton qui ouvrent des popups (rendu à part).
	return (node is Button) and not (node is OptionButton) and not (node is MenuButton)

func _attach(btn: Node) -> void:
	if not is_instance_valid(btn):
		return
	if btn.has_node("GlassBlur"):
		return
	# Le masque du verre suit l'arrondi RÉEL du bouton (px GUI converti en px écran côté GlassBlur),
	# sinon ses coins dépassent de l'arrondi → liseré anguleux.
	var glass := GlassBlur.new(GlassBlur.corner_radius_of(btn as Control))
	glass.name = "GlassBlur"
	btn.add_child(glass)
	btn.move_child(glass, 0)
