class_name VisualAsimov
extends RefCounted

const FUNDO := Color("101923")
const PAINEL := Color("1c2b39")
const BORDA := Color("425868")
const TEXTO := Color("d7e5df")
const SUAVE := Color("8caaa9")
const CIANO := Color("66c6d5")
const VERDE := Color("8dcb9b")
const AMARELO := Color("d8b86d")
const VERMELHO := Color("d97471")
const FONTE := preload("res://Minigames/Arte/PixelifySans-Regular.ttf")
const ATLAS := preload("res://Minigames/Arte/sprites_192.png")

static func quadro(linha: int, coluna: int) -> AtlasTexture:
	var textura := AtlasTexture.new()
	textura.atlas = ATLAS
	textura.region = Rect2(coluna * 48, linha * 48, 48, 48)
	return textura

static func caixa(cor: Color = PAINEL, borda: Color = BORDA) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.border_color = borda
	estilo.set_border_width_all(1)
	estilo.content_margin_left = 8
	estilo.content_margin_right = 8
	return estilo

static func tema() -> Theme:
	var t := Theme.new()
	t.default_font = FONTE
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXTO)
	t.set_color("font_color", "Button", TEXTO)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", SUAVE)
	t.set_stylebox("normal", "Button", caixa(PAINEL, BORDA))
	t.set_stylebox("hover", "Button", caixa(Color("2b4350"), CIANO))
	t.set_stylebox("pressed", "Button", caixa(Color("101f2b"), VERDE))
	t.set_stylebox("focus", "Button", caixa(Color(0, 0, 0, 0), AMARELO))
	t.set_stylebox("disabled", "Button", caixa(FUNDO, BORDA))
	return t

static func painel(pai: Node, ret: Rect2, cor: Color = PAINEL, borda: Color = BORDA) -> Panel:
	var p := Panel.new()
	p.position = ret.position
	p.size = ret.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", caixa(cor, borda))
	pai.add_child(p)
	return p

static func texto(pai: Node, conteudo: String, ret: Rect2, tamanho: int = 16, cor: Color = TEXTO) -> Label:
	var l := Label.new()
	l.text = conteudo
	l.position = ret.position
	l.size = ret.size
	l.add_theme_font_override("font", FONTE)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(l)
	return l

static func botao(pai: Node, conteudo: String, ret: Rect2, acao: Callable) -> Button:
	var b := Button.new()
	b.text = conteudo
	b.position = ret.position
	b.size = ret.size
	b.theme = tema()
	b.pressed.connect(acao)
	pai.add_child(b)
	return b

static func icone(pai: Node, linha: int, coluna: int, ret: Rect2) -> TextureRect:
	var i := TextureRect.new()
	i.texture = quadro(linha, coluna)
	i.position = ret.position
	i.size = ret.size
	i.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	i.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	i.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(i)
	return i
