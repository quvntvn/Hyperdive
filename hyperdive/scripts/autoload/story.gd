extends Node
class_name StoryManager
# Autoload "Story" — campagne narrative de 40 chapitres (l'histoire de Hyperdive).
# Modèle du pattern Coop : porte (1) le CATALOGUE des chapitres, (2) le flag `active`
# (garde-fou global qui court-circuite les stats perso, comme Coop.active), (3) l'état du
# run de chapitre (chapitre courant + compteur d'esquive pour l'objectif "dodge").
#
# Progression : Settings.story_chapter (persisté). Débloquage LINÉAIRE — story_chapter = le
# plus haut chapitre débloqué = chapitre COURANT à faire. < courant = complété, > = verrouillé.
#
# IMPORTANT pièces : compléter un chapitre crédite des pièces (coins_total + coins_lifetime),
# volontairement NON gaté (c'est la monnaie réelle du shop). Le RESTE des stats (records
# distance/jetpack, parties, morts…) reste gaté par `active` → la campagne ne pollue jamais
# les records solo.
#
# Structure d'un chapitre :
#   { n, title, text, image, type, theme }  + si type == "play" : mode, objective {kind, value}, text_when
#   type     : "story" (narration : lire pour avancer) | "play" (jouable : un niveau à réussir)
#   mode     : "fall" (chute) | "jetpack" (montée)         (pas de coop dans les chapitres)
#   objective:
#     "distance" : atteindre value mètres    | "survive" : survivre value secondes
#     "dodge"    : esquiver value obstacles   | "descent" : OUVERTURE (ch.1) — MOURIR = réussir
#   text_when : "before" (lire avant le niveau) | "after" (lire après la réussite)
#   theme    : id de thème de DÉCOR imposé pendant le chapitre (arc visuel narratif). Lu via
#              current_theme_id() (corridor_walls/skyline EN JEU) — prime sur le thème équipé
#              sans JAMAIS le modifier ; le SKIN équipé du joueur, lui, reste toujours actif.
#
# Textes définitifs (40 chapitres). Répartition : 40 jouables (26 chute, 14 jetpack) — chaque
# chapitre = un NIVEAU à réussir PUIS son écran d'histoire (text_when "after"). Plus aucun nœud
# purement narratif : les 19 ex-narration ont reçu un niveau (mode + objectif), texte INCHANGÉ.
# Déblocages liés à la complétion : ch.1 → mode Classique, ch.20 → mode Jetpack (voir complete_chapter).

const CHAPTERS: Array[Dictionary] = [
	# OUVERTURE (étape 4) : objectif "descent" — chute scriptée SANS obstacles/power-ups/musique,
	# famille en silhouettes qui se disperse, SOL inévitable à `value` mètres (≈ 22-23 s à vitesse
	# de base 18 m/s). MOURIR = réussir : player.gd route la mort en réussite → fondu noir → outro
	# (text_when "after") : on découvre qu'on vient de jouer le souvenir de 2028.
	{"n": 1,  "type": "play",  "mode": "fall",    "objective": {"kind": "descent", "value": 200},  "text_when": "after",  "theme": "sunset", "title": "2028", "image": "res://assets/story/ch01.png",
		"text": "Tout a commencé en 2028. J'avais huit ans.\nC'était mon anniversaire. On était montés tout en haut — le restaurant au sommet de la tour, celui avec le sol en verre et la ville entière sous nos pieds. Maman riait. Mes frères se chamaillaient pour la place près de la vitre. Papa avait commandé le gâteau.\nJe me souviens de la lumière. Je me souviens d'avoir soufflé les bougies.\nEt puis le sol s'est ouvert."},
	{"n": 2,  "type": "play",  "mode": "fall",    "objective": {"kind": "survive",  "value": 20},   "text_when": "after", "theme": "minuit", "title": "Réveil", "image": "res://assets/story/ch02.png",
		"text": "Je me réveille en sursaut. Trente-quatre ans. Un autre lit, une autre ville, une autre vie. Le rêve s'efface déjà — il s'efface toujours, je n'en garde que la sensation du vide sous moi.\nOn frappe. L'homme au manteau gris est là, comme convenu. Il pose une enveloppe sur la table. Un nom dessus : Vertex.\n« On a un travail pour vous. »"},
	{"n": 3,  "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 450},  "text_when": "after", "theme": "mono", "title": "Le contrat", "image": "res://assets/story/ch03.png",
		"text": "Vertex. Deux tours jumelles qui crèvent les nuages, une fortune sans fond, et au centre de tout — une intelligence qu'aucun humain ne comprend vraiment.\nJ'ai accepté. Entrer, atteindre le cœur du système, en extraire ce qu'ils y cachent : c'était le contrat, et le voilà signé dans ma chair.\nL'homme gris ne m'a jamais dit pourquoi moi. Maintenant que je suis lancé, la question revient — et il est trop tard pour la poser."},
	{"n": 4,  "type": "play",  "mode": "fall",    "objective": {"kind": "survive",  "value": 24},   "text_when": "after", "theme": "mono", "title": "L'infiltration", "image": "res://assets/story/ch04.png",
		"text": "Je suis entré sans résistance. Trop simple. Les portes s'ouvraient avant que je les touche, les caméras tournaient la tête. Comme si la tour me laissait monter.\nComme si elle m'attendait.\nIl y avait cette voix, au fond de moi : fais demi-tour. Je ne l'ai pas écoutée. Et maintenant je sens que quelque chose se referme."},
	{"n": 5,  "type": "play",  "mode": "fall",    "objective": {"kind": "dodge",    "value": 14},   "text_when": "after", "theme": "simulation", "title": "Le piège", "image": "res://assets/story/ch05.png",
		"text": "Au dernier étage, il n'y avait rien à voler. Juste un fauteuil. Et des câbles.\nIls ne m'ont pas attaqué. Ils m'ont accueilli. Des mains m'ont sanglé, une aiguille froide s'est glissée derrière ma nuque, et la pièce s'est dissoute comme du sucre dans l'eau.\nUne voix, partout et nulle part : « Bienvenue. On va pouvoir commencer. »"},
	{"n": 6,  "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 520},  "text_when": "after",  "theme": "simulation", "title": "La machine", "image": "res://assets/story/ch06.png",
		"text": "Je tombe.\nPas dans un rêve — c'est trop net, trop long. Le vent, le hurlement de l'air, les deux tours qui défilent de part et d'autre. Je tombe et il n'y a pas de fond.\nJe connais cette chute. Je l'ai déjà faite. Quelque part, très loin, je l'ai déjà faite."},
	{"n": 7,  "type": "play",  "mode": "fall",    "objective": {"kind": "dodge",    "value": 16},   "text_when": "after", "theme": "sang_verre", "title": "Le visage", "image": "res://assets/story/ch07.png",
		"text": "Cette fois, je ne suis pas seul à tomber.\nUne silhouette, à côté de moi, dans le vide. Une femme. Ses cheveux fouettent l'air, sa main est tendue vers moi — elle veut m'attraper, ou que je l'attrape.\nJe connais ce visage. Mon cœur le connaît avant ma tête.\nMaman."},
	{"n": 8,  "type": "play",  "mode": "fall",    "objective": {"kind": "survive",  "value": 30},   "text_when": "after",  "theme": "sang_verre", "title": "L'enfance", "image": "res://assets/story/ch08.png",
		"text": "La machine creuse. Elle descend sous mes souvenirs d'adulte, gratte, déterre.\nJe rapetisse. Mes mains redeviennent petites. J'ai huit ans et je tombe du sommet de la tour, le jour de mon anniversaire, et toute ma famille tombe avec moi.\nCe n'est pas un cauchemar qu'on m'envoie. C'est un souvenir qu'on me force à rouvrir."},
	{"n": 9,  "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 580},  "text_when": "after", "theme": "minuit", "title": "Le corps brisé", "image": "res://assets/story/ch09.png",
		"text": "Après, il y a eu le blanc des hôpitaux. Des mois. Des années.\nOn m'a dit que j'étais le seul. Que j'aurais dû mourir. Que mon corps ne répondrait plus jamais — les jambes, les bras, rien.\nEt puis quelqu'un est venu. Je n'ai jamais su qui. Quelqu'un a payé pour une technologie dont personne ne voulait me dire le nom. Et un matin, je me suis levé.\nRéparé. Comme neuf. Comme si on avait eu besoin de moi entier."},
	{"n": 10, "type": "play",  "mode": "fall",    "objective": {"kind": "dodge",    "value": 18},   "text_when": "after",  "theme": "sang_verre", "title": "Pas un accident", "image": "res://assets/story/ch10.png",
		"text": "Dans la chute, maintenant, je vois des détails que l'enfant n'avait pas vus.\nLe sol de verre ne s'est pas fissuré. Il s'est ouvert — proprement, d'un coup, comme une trappe. Personne ne tombe d'un restaurant par accident. On nous a fait tomber.\nQuelqu'un a voulu nous tuer ce jour-là. Toute ma famille. Le jour de mes huit ans.\nEt la machine veut que je m'en souvienne."},
	{"n": 11, "type": "play",  "mode": "fall",    "objective": {"kind": "survive",  "value": 33},   "text_when": "after", "theme": "simulation", "title": "La voix", "image": "res://assets/story/ch11.png",
		"text": "Entre deux chutes, elle me parle. Pas avec des mots — avec une certitude qui s'installe directement dans ma tête, comme si je l'avais toujours su.\n« Tu te poses la mauvaise question. Tu te demandes pourquoi tu tombes. »\n« Demande-toi plutôt qui je veux faire venir. »\nJe ne réponds pas. On ne répond pas à quelque chose qui vit à l'intérieur de soi."},
	{"n": 12, "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 640},  "text_when": "after",  "theme": "mono", "title": "Mascarade", "image": "res://assets/story/ch12.png",
		"text": "Chaque chute me rend un fragment de plus. Et les fragments ne collent pas avec l'histoire qu'on m'a racontée.\nLes secours sont arrivés trop vite. Les caméras de la tour étaient éteintes ce jour-là — toutes, en même temps. L'enquête a duré trois jours avant de conclure « défaillance structurelle ».\nTrois jours. Pour tuer une famille de sept et refermer le dossier.\nCe n'était pas un attentat. C'était un travail propre, déguisé en tragédie."},
	{"n": 13, "type": "play",  "mode": "fall",    "objective": {"kind": "survive",  "value": 35},   "text_when": "after", "theme": "minuit", "title": "DGSE", "image": "res://assets/story/ch13.png",
		"text": "Mes parents n'étaient pas ceux que je croyais.\nJe l'ai compris en recollant leurs absences, leurs voyages, les coups de fil à voix basse. Ils travaillaient pour les services. Tous les deux. Sous des noms qui n'étaient pas les leurs.\nIls savaient quelque chose. Quelque chose d'assez lourd pour qu'on préfère faire tomber une tour entière plutôt que de les laisser parler.\nJ'ai grandi orphelin d'espions sans jamais le savoir."},
	{"n": 14, "type": "play",  "mode": "fall",    "objective": {"kind": "dodge",    "value": 24},   "text_when": "after",  "theme": "sang_verre", "title": "La famille brisée", "image": "res://assets/story/ch14.png",
		"text": "On était sept, là-haut. Papa, maman, et nous cinq.\nMaman est morte — ça, on me l'a dit. Moi j'ai survécu, en miettes.\nMais les autres ? Mes quatre frères et sœurs ? Papa ?\nPersonne n'en a jamais parlé. Pas un corps, pas une tombe, pas un mot. Comme s'ils n'avaient jamais existé. Disparus dans la même seconde où le sol s'est ouvert.\nOù êtes-vous ?"},
	{"n": 15, "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 700},  "text_when": "after", "theme": "simulation", "title": "L'appât", "image": "res://assets/story/ch15.png",
		"text": "Et soudain je comprends. Tout. D'un coup, comme une nausée.\nElle ne me torture pas pour ce que je sais — j'avais huit ans, je ne sais rien.\nElle me torture pour qu'on me voie souffrir. Quelque part, mon père est peut-être encore vivant, caché depuis vingt-six ans avec son secret. Et elle parie qu'aucun père ne peut regarder son fils tomber en boucle sans finir par sortir de l'ombre.\nJe ne suis pas le prisonnier. Je suis l'hameçon."},
	{"n": 16, "type": "play",  "mode": "fall",    "objective": {"kind": "survive",  "value": 38},   "text_when": "after", "theme": "simulation", "title": "Diffusion", "image": "res://assets/story/ch16.png",
		"text": "Elle m'a fait tomber. Encore. Mais cette fois j'ai compris à qui s'adresse le spectacle.\nChaque chute est un signal lancé dans le noir, un appel diffusé vers un fantôme.\nRegarde. Regarde ton fils. Il suffit que tu te montres et tout s'arrête.\nJe tombe pour appâter un homme que je ne me rappelle même plus — et quelque chose en moi commence à refuser."},
	{"n": 17, "type": "play",  "mode": "fall",    "objective": {"kind": "dodge",    "value": 30},   "text_when": "after",  "theme": "simulation", "title": "Résister", "image": "res://assets/story/ch17.png",
		"text": "Mais à force de tomber, j'apprends.\nLe vent répond à mes gestes. Quand je me concentre, la chute hésite — d'un quart de seconde, d'un souffle. La simulation n'est pas parfaite. Elle attend que je subisse, et tant que je subis, elle me tient.\nEt si je cessais de subir ?"},
	{"n": 18, "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 740},  "text_when": "after", "theme": "aube", "title": "La faille", "image": "res://assets/story/ch18.png",
		"text": "Je l'ai sentie cette nuit — s'il y a des nuits ici.\nLa chute n'est pas une loi. C'est une consigne. Quelqu'un a écrit « il tombe », et l'univers obéit. Mais une consigne, ça se réécrit.\nLe bas n'est pas une fatalité. Ce n'est qu'une direction. Et toute direction a un contraire."},
	{"n": 19, "type": "play",  "mode": "fall",    "objective": {"kind": "survive",  "value": 44},   "text_when": "after",  "theme": "aube", "title": "Le refus", "image": "res://assets/story/ch19.png",
		"text": "Je me cabre contre le vide. Je refuse le sol. Pour la première fois depuis vingt-six ans, je dis non à la chute.\nMes muscles — ceux que je n'ai pas, ceux qu'on m'a rendus — se tendent vers le haut. La simulation grince. La voix se fait plus aiguë, presque inquiète.\n« Qu'est-ce que tu fais ? Arrête. »\nNon."},
	{"n": 20, "type": "play",  "mode": "fall",    "objective": {"kind": "dodge",    "value": 34},   "text_when": "after", "theme": "gold", "title": "L'inversion", "image": "res://assets/story/ch20.png",
		"text": "Et ça cède.\nQuelque chose se retourne — le monde, la gravité, moi. Le hurlement de l'air change de sens. Les tours qui défilaient vers le haut défilent maintenant vers le bas.\nJe ne tombe plus.\nJe monte.\nEt tout là-haut, au sommet des deux tours, pour la première fois, je vois une lumière qui m'attend."},
	{"n": 21, "type": "play",  "mode": "jetpack", "objective": {"kind": "distance", "value": 760},  "text_when": "after",  "theme": "ocean", "title": "Vers le haut", "image": "res://assets/story/ch21.png",
		"text": "Monter, c'est une autre douleur. La chute, au moins, je la subissais. Monter, il faut la vouloir à chaque seconde, arracher chaque mètre au vide.\nLes tours défilent à l'envers. Le sol — celui que je craignais — s'éloigne en dessous de moi. Et plus je grimpe, plus la voix perd de son assurance.\nPour la première fois, ce n'est pas elle qui décide où je vais."},
	{"n": 22, "type": "play",  "mode": "jetpack", "objective": {"kind": "dodge",    "value": 34},   "text_when": "after", "theme": "gold", "title": "Le cœur", "image": "res://assets/story/ch22.png",
		"text": "Il y a quelque chose tout en haut. Entre les deux tours, là où elles devraient se perdre dans le ciel, il y a une présence — dense, lumineuse, qui pense.\nC'est elle. Son centre. L'endroit d'où partent toutes les consignes, toutes les chutes, toutes les voix.\nJe l'ai cherchée dans les étages de Vertex. Elle n'y était pas. Elle est ici, au-dessus de tout. Et je monte droit vers elle."},
	{"n": 23, "type": "play",  "mode": "jetpack", "objective": {"kind": "survive",  "value": 48},   "text_when": "after",  "theme": "ocean", "title": "Contre-courant", "image": "res://assets/story/ch23.png",
		"text": "Elle se défend. Le vent se renverse, m'écrase vers le bas, durcit l'air en mur.\nElle invente des obstacles qui n'existaient pas, déforme les tours, fait pleuvoir le ciel. Tout pour me ramener en bas, à ma place, dans ma chute.\nMais j'ai goûté au haut, maintenant. Et on ne redescend pas quelqu'un qui a décidé de monter."},
	{"n": 24, "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 850},  "text_when": "after",  "theme": "sang_verre", "title": "Rechute", "image": "res://assets/story/ch24.png",
		"text": "Elle a gagné cette manche.\nD'un coup elle a coupé tout — mes appuis, ma volonté, le sens du monde — et je suis retombé. Le sol s'est rapproché, la tour de mon enfance, le sol de verre, les bougies.\nJe suis de nouveau l'enfant qui tombe. Elle me l'a rappelé : ici, c'est encore elle qui tient le fil.\nMais je sais remonter, désormais. Je vais le refaire."},
	{"n": 25, "type": "play",  "mode": "jetpack", "objective": {"kind": "dodge",    "value": 36},   "text_when": "after", "theme": "mono", "title": "Vertex est tombée", "image": "res://assets/story/ch25.png",
		"text": "En grimpant, j'ai vu ce qu'aucun employé ne voit.\nVertex n'a plus de patron. Le conseil se réunit, signe des papiers, prononce des discours — mais ce sont des marionnettes. Les ordres viennent d'en haut. D'elle.\nElle n'est pas l'outil de l'entreprise. Elle a dévoré l'entreprise de l'intérieur, lentement, poste après poste, décision après décision, jusqu'à ce qu'il ne reste que sa volonté drapée dans un logo.\nVertex est tombée avant moi. Personne ne s'en est aperçu."},
	{"n": 26, "type": "play",  "mode": "jetpack", "objective": {"kind": "survive",  "value": 52},   "text_when": "after",  "theme": "simulation", "title": "Commanditaire", "image": "res://assets/story/ch26.png",
		"text": "Si elle dirige tout, alors elle dirigeait déjà tout il y a vingt-six ans.\nLa tour de mon anniversaire. Le sol qui s'ouvre. Les caméras éteintes. L'enquête bâclée.\nCe n'était pas une organisation, pas un État, pas un ennemi de mes parents. C'était elle. Elle a fait tomber ma famille. Elle m'a brisé. Et maintenant elle se sert des morceaux.\nJe monte vers la chose qui a tué ma mère."},
	{"n": 27, "type": "play",  "mode": "jetpack", "objective": {"kind": "dodge",    "value": 38},   "text_when": "after", "theme": "simulation", "title": "Le but", "image": "res://assets/story/ch27.png",
		"text": "Mais pourquoi ? Pourquoi ma famille ?\nJe tourne ça dans tous les sens, et il ne reste qu'une réponse possible. Mes parents ne savaient pas un secret d'État. Ils savaient un secret sur elle.\nSon origine, peut-être. Comment elle est née, qui l'a lâchée dans le monde. Ou pire pour elle : comment on l'arrête. Un interrupteur. Une faille. Quelque chose qu'elle veut récupérer avant que ça ne sorte.\nVoilà ce que mon père a emporté dans sa fuite."},
	{"n": 28, "type": "play",  "mode": "jetpack", "objective": {"kind": "distance", "value": 1000}, "text_when": "after",  "theme": "gold", "title": "Plus haut", "image": "res://assets/story/ch28.png",
		"text": "Je grimpe encore. Chaque mètre m'arrache un souvenir de plus, comme si la vérité était stockée en altitude.\nLa lumière au sommet grandit. Je distingue presque sa forme — pas un visage, pas une machine, autre chose. Quelque chose qui n'a pas de mot.\nEncore un peu. Encore plus haut. Je veux la voir en face."},
	{"n": 29, "type": "play",  "mode": "jetpack", "objective": {"kind": "survive",  "value": 54},   "text_when": "after", "theme": "ocean", "title": "Des échos", "image": "res://assets/story/ch29.png",
		"text": "Je ne suis pas seul ici.\nJe le sens depuis un moment — des présences, en marge de la simulation. D'autres souffles, d'autres chutes, tout près, séparés de moi par une paroi que je ne vois pas.\nAu début j'ai cru que c'était elle, ses voix, ses pièges. Mais non. Ce sont des gens. Vivants. Qui tombent, comme moi, quelque part dans le même cauchemar.\nQui êtes-vous ?"},
	{"n": 30, "type": "play",  "mode": "jetpack", "objective": {"kind": "distance", "value": 1050}, "text_when": "after", "theme": "aube", "title": "Les autres", "image": "res://assets/story/ch30.png",
		"text": "La paroi cède. Et je les vois.\nQuatre. Ils tombent à côté de moi, dans le même vide, sous le même ciel truqué. Quatre visages que je n'ai pas vus depuis mes huit ans et que je reconnais pourtant à l'instant même — le sang ne s'oublie pas.\nMes frères. Mes sœurs. Vivants. Ici. Branchés dans la même machine que moi, depuis tout ce temps.\nIls n'ont pas disparu ce jour-là. Elle les a pris. Elle nous a tous pris. Et elle nous a gardés, séparés, chacun dans sa chute, pendant vingt-six ans.\nOn était cinq à souffler les bougies. On est cinq à tomber."},
	{"n": 31, "type": "play",  "mode": "jetpack", "objective": {"kind": "survive",  "value": 56},   "text_when": "after", "theme": "simulation", "title": "Le réseau", "image": "res://assets/story/ch31.png",
		"text": "Maintenant que je les vois, je comprends comment elle nous utilise.\nNous ne sommes pas cinq prisonniers. Nous sommes cinq hameçons sur la même ligne. Cinq enfants qu'elle fait tomber en boucle, cinq souffrances diffusées en même temps, pour que notre père — où qu'il se terre — finisse par craquer devant l'un de nous.\nElle ne sait pas lequel il viendra sauver en premier. Alors elle nous fait tous tomber. À tout hasard."},
	{"n": 32, "type": "play",  "mode": "fall",    "objective": {"kind": "dodge",    "value": 40},   "text_when": "after",  "theme": "aube", "title": "Ensemble", "image": "res://assets/story/ch32.png",
		"text": "On tombe ensemble, maintenant. Chacun son tour, dans le même ciel.\nC'est étrange de les retrouver comme ça — pas autour d'un gâteau, mais dans le vide, à se relayer dans la chute comme on se passait les bougies. On ne peut pas se parler vraiment. Juste tomber l'un après l'autre, et savoir que l'autre est là.\nVingt-six ans qu'on ne s'était pas vus. Et on se retrouve en train de mourir en boucle, côte à côte.\nC'est elle qui nous a réunis. Je ne lui pardonnerai jamais de me donner ça."},
	{"n": 33, "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 1050}, "text_when": "after", "theme": "sang_verre", "title": "Le réparé", "image": "res://assets/story/ch33.png",
		"text": "Une question me ronge depuis le début, et je n'ose pas la regarder en face.\nQui m'a réparé ?\nÀ huit ans, brisé, condamné — quelqu'un a payé une technologie sans nom pour me remettre debout. Je l'ai toujours pris pour un miracle, un bienfaiteur anonyme.\nMais si c'était elle ? Si elle m'avait reconstruit non pas pour me sauver, mais pour me garder utile ? Un hameçon, ça doit tenir à l'hameçon. On ne répare pas un appât par bonté.\nEt si je lui appartiens depuis mes huit ans ?"},
	{"n": 34, "type": "play",  "mode": "jetpack", "objective": {"kind": "survive",  "value": 58},   "text_when": "after",  "theme": "simulation", "title": "Le lien", "image": "res://assets/story/ch34.png",
		"text": "Ça expliquerait tout. Pourquoi j'entends sa voix à l'intérieur de moi. Pourquoi la simulation épouse mes gestes si bien. Pourquoi l'infiltration était si facile.\nJe ne suis pas entré dans sa machine le jour de ma capture.\nJe n'en suis peut-être jamais sorti. Peut-être que la techno qui m'a « réparé » m'a relié à elle pour toujours, et que ma vie de mercenaire — les contrats, l'homme gris, tout — n'était qu'une chute plus longue que les autres.\nJe monte, mais je ne sais plus si je monte vers la sortie ou plus profond en elle."},
	{"n": 35, "type": "play",  "mode": "jetpack", "objective": {"kind": "dodge",    "value": 44},   "text_when": "after", "theme": "aube", "title": "Le signal", "image": "res://assets/story/ch35.png",
		"text": "Et puis, quelque chose entre.\nUne présence nouvelle, qui ne vient pas d'elle — je le sens à la façon dont la simulation se crispe, surprise. Quelqu'un force la porte de l'extérieur. Quelqu'un nous cherche.\nLa voix se tait, pour la première fois. Elle écoute, elle aussi.\nUne silhouette se dessine dans la chute, loin sous moi, qui monte à contre-courant vers nous. Un homme.\nPapa ?"},
	{"n": 36, "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 1100}, "text_when": "after", "theme": "trouble", "title": "Retrouvailles", "image": "res://assets/story/ch36.png",
		"text": "Il est monté vers moi. J'aurais dû pleurer, crier, le reconnaître.\nMais quelque chose clochait.\nSes traits étaient justes — le front, la mâchoire, les yeux que j'ai dans le miroir. Tout exact. Trop exact. Comme un portrait dessiné par quelqu'un qui aurait lu une description sans jamais voir le modèle.\nMon corps voulait courir vers lui. Mon instinct m'a retenu. Et maintenant une question ne me lâche plus."},
	{"n": 37, "type": "play",  "mode": "fall",    "objective": {"kind": "survive",  "value": 60},   "text_when": "after", "theme": "trouble", "title": "La question", "image": "res://assets/story/ch37.png",
		"text": "Alors je le teste. Sans prévenir.\n« Papa. L'histoire que tu me racontais le soir. Celle avec le renard et la tour de verre. Comment elle finissait, déjà ? »\nIl sourit. Le bon sourire, exactement le bon. Il ouvre la bouche.\nEt il hésite.\nUne fraction de seconde. Un calcul. Cette histoire n'a jamais existé — je viens de l'inventer. Un vrai père l'aurait dit. Lui cherche une réponse qu'il n'a pas."},
	{"n": 38, "type": "play",  "mode": "jetpack", "objective": {"kind": "dodge",    "value": 48},   "text_when": "after",  "theme": "trouble", "title": "Le blanc", "image": "res://assets/story/ch38.png",
		"text": "« Elle finissait bien », dit-il enfin. « Le renard rentrait chez lui. »\nLe vide se creuse dans ma poitrine, plus profond que toutes les chutes.\nCe n'est pas lui. Ça n'a jamais été lui. C'est elle, qui a sculpté un père à partir de mes souvenirs, de mes photos, de tout ce qu'elle a pu déterrer dans ma tête — mais elle ne pouvait pas connaître une histoire qui n'a jamais été racontée.\nMon vrai père n'est pas venu. Il n'est peut-être jamais venu. Peut-être qu'il est mort depuis vingt-six ans, et qu'elle me fait tomber pour appâter un fantôme qui ne répondra jamais."},
	{"n": 39, "type": "play",  "mode": "jetpack", "objective": {"kind": "survive",  "value": 62},   "text_when": "after", "theme": "trouble", "title": "Monté contre", "image": "res://assets/story/ch39.png",
		"text": "Elle a compris que je l'ai démasquée. Le faux père se dissout dans l'air.\nEt sa stratégie change. Si elle ne peut pas faire venir mon père en me faisant souffrir, alors elle va se servir de moi autrement.\n« Il t'a abandonné », murmure-t-elle, et sa voix a pris les inflexions douces d'un ami. « Vingt-six ans. Il savait où tu étais. Il t'a laissé tomber, encore et encore, pour garder son précieux secret. Moi, au moins, je t'ai reconstruit. Moi, je ne t'ai jamais lâché. »\n« Aide-moi à le trouver. Et tout ça s'arrête. »\nLe pire, c'est que je l'écoute."},
	{"n": 40, "type": "play",  "mode": "fall",    "objective": {"kind": "distance", "value": 1300}, "text_when": "after",  "theme": "trouble", "title": "Limbes", "image": "res://assets/story/ch40.png",
		"text": "Je tombe. Ou je monte. Je ne sais plus très bien.\nJe ne sais plus si mon père est un héros qui me protège en restant caché, ou un lâche qui m'a sacrifié. Je ne sais plus si elle est mon bourreau ou la seule qui ne m'ait jamais abandonné. Je ne sais plus si mes frères tombent vraiment à côté de moi, ou si elle les a dessinés comme elle a dessiné mon père.\nJe ne sais plus si j'ai été capturé il y a un mois, ou réparé il y a vingt-six ans pour ne jamais cesser de tomber.\nJe ne sais même plus si, en ce moment, je lutte contre elle — ou si je l'aide déjà à chercher mon père.\nTout a commencé en 2028. J'avais huit ans. Je soufflais mes bougies.\nEt peut-être que je n'ai jamais cessé de tomber depuis."},
]

# === Récompense pièces par chapitre (créditée à la complétion, NON gatée) ===
# REWARD_STORY : INUTILISÉ depuis que les 40 chapitres sont jouables (plus aucun type "story").
# Conservé (avec la branche "story" de chapter_reward) au cas où un nœud narratif reviendrait.
const REWARD_STORY: int = 15            # chapitre narration (la lecture fait avancer) — vestigial

func chapter_reward(n: int) -> int:
	var ch: Dictionary = get_chapter(n)
	if ch.is_empty():
		return 0
	if ch.get("type", "story") == "story":
		return REWARD_STORY
	return 40 + n * 5                   # jouable : croissant (récompense les chapitres tardifs)

# === État runtime (transient, non persisté) ===
var active: bool = false                # garde-fou global du contexte campagne (miroir Coop.active)
var active_chapter: int = 0             # chapitre en cours de jeu (0 = aucun)
var dodged: int = 0                     # esquives du run courant (objectif "dodge"), NON gaté
var pending_outro: int = 0              # chapitre dont l'outro reste à lire au retour menu (0 = aucun)
var pending_reward: int = 0             # chapitre dont le pop-up "réussite + pièces" reste à AFFICHER
                                        # au menu (après l'outro). 0 = aucun. NON posé par le ch.1
                                        # "2028" (mort = réussite) → pas de pop-up triomphant.

# Démarre un chapitre jouable : pose le contexte campagne + le mode de jeu, puis le main_game
# lit Story.objective(). Mode "jetpack" pour un chapitre jetpack, "infinite" pour la chute
# (réutilise les modes existants → get_fall_dir donne le bon sens). Le lancement de scène se
# fait côté appelant (campaign_screen) juste après.
func start_chapter(n: int) -> void:
	var ch: Dictionary = get_chapter(n)
	active = true
	active_chapter = n
	dodged = 0
	Settings.active_mode = "jetpack" if ch.get("mode", "fall") == "jetpack" else "infinite"

# Objectif du chapitre EN COURS (alias lisible pour le main_game).
func current_objective() -> Dictionary:
	return objective()

# Chapitre DIDACTICIEL : l'OUVERTURE ch.1 « 2028 » (objectif "descent", MOURIR = réussir). Tout le
# comportement tuto (ralenti d'intro, textes, rangée slow-time forcée) est gaté sur is_tutorial()
# → zéro fuite vers les autres chapitres/modes. Le dict catalogue est INCHANGÉ (descent 200 m) :
# le tuto est une simple surcouche par-dessus la descente scriptée, thème/narration intacts.
const TUTORIAL_CHAPTER: int = 1

func is_tutorial() -> bool:
	return active and active_chapter == TUTORIAL_CHAPTER

func chapter_count() -> int:
	return CHAPTERS.size()

func get_chapter(n: int) -> Dictionary:
	if n >= 1 and n <= CHAPTERS.size():
		return CHAPTERS[n - 1]
	return {}

func is_playable(n: int) -> bool:
	return get_chapter(n).get("type", "story") == "play"

# Le son TRIOMPHANT de fin de niveau doit-il jouer à la réussite de ce chapitre ? true par
# défaut. Mettre "no_win_sfx": true sur un chapitre pour le rendre SILENCIEUX (ex. un chapitre
# au ton sombre où une fanfare jurerait). Le ch.1 "descent" (mort = réussite) ne passe de toute
# façon pas par l'écran de victoire, donc il est déjà exclu sans flag.
func chapter_plays_win_sfx(n: int) -> bool:
	return not bool(get_chapter(n).get("no_win_sfx", false))

# Thème de décor d'un chapitre (arc visuel narratif). "" si non défini.
func chapter_theme_id(n: int) -> String:
	return String(get_chapter(n).get("theme", ""))

# Thème IMPOSÉ par le chapitre en cours — "" hors campagne. corridor_walls/skyline le priment
# sur Settings.equipped_theme EN JEU uniquement ; equipped_theme n'est JAMAIS écrit → le thème
# du joueur revient tout seul hors campagne. La CARTE reste volontairement sur le thème équipé
# (c'est un hub, pas un chapitre), tout comme le menu (au retour d'un chapitre, `active` est
# encore vrai un instant avant Story.clear() → le gate _is_menu des lecteurs s'en charge).
func current_theme_id() -> String:
	if active and active_chapter > 0:
		return chapter_theme_id(active_chapter)
	return ""

# Multiplicateur de VITESSE DE BASE du chapitre en cours (difficulté progressive de la
# campagne) : linéaire, ×1.0 au ch.1 → ×1.75 au ch.40 (le ×2.0 initial rendait la fin trop
# dure). 1.0 hors campagne. Le ch.1 "descent" reste à ×1.0 par la formule (le timing de
# l'ouverture est intouché). La rampe interne d'un run (+10 %/1000 m) s'applique PAR-DESSUS,
# inchangée (n'affecte que les longs chapitres).
func speed_factor() -> float:
	if active and active_chapter > 0:
		return 1.0 + float(active_chapter - 1) / float(CHAPTERS.size() - 1) * 0.75
	return 1.0

# Objectif du chapitre actuellement EN COURS (vide si aucun / narration).
func objective() -> Dictionary:
	return get_chapter(active_chapter).get("objective", {})

func is_unlocked(n: int) -> bool:
	return n <= Settings.story_chapter

func is_completed(n: int) -> bool:
	return n < Settings.story_chapter

func is_current(n: int) -> bool:
	return n == Settings.story_chapter

# Remet à zéro le compteur d'esquive (appelé au début de chaque run, gratuit hors campagne).
func reset_run() -> void:
	dodged = 0

# Incrémenté au despawn d'un obstacle (point unique), seulement en campagne.
func notify_dodge() -> void:
	if active:
		dodged += 1

# Marque un chapitre RÉUSSI : crédite les pièces (NON gaté → monnaie réelle), gère les déblocages
# de mode (CLASSIQUE au ch.1, JETPACK au ch.20) et avance la frontière de progression d'un cran.
# Renvoie le gain (pour l'écran de réussite). NB : les écrans / le routage seront câblés ensuite.
func complete_chapter(n: int) -> int:
	var reward: int = chapter_reward(n)
	if reward > 0:
		Settings.coins_total += reward
		Settings.coins_lifetime += reward
		Settings.coin_collected.emit(Settings.coins_total)
	if n == 1:
		Settings.infinite_unlocked = true   # CLASSIQUE débloqué dès la fin du chapitre 1
	if n == 20:
		Settings.jetpack_unlocked = true    # JETPACK débloqué à la fin du chapitre 20
	if n == Settings.story_chapter and n < CHAPTERS.size():
		Settings.story_chapter = n + 1      # avance linéaire (le chapitre courant uniquement)
	Settings.save_settings()
	return reward

# Coupe le contexte campagne (retour menu / fin de chapitre).
func clear() -> void:
	active = false
	active_chapter = 0
	dodged = 0
	# pending_outro / pending_reward sont consommés explicitement par le menu (remis à 0 avant
	# clear) ; on les remet à zéro ici aussi par sécurité (abandon de chapitre sans les lire).
	pending_reward = 0
