class_name HeroData extends Resource
## Static definition of a hero. Heroes differ ONLY by ability + ultimate +
## cosmetics (CLAUDE.md rule 3). No movement stats live here — ever.

@export var hero_name: String = ""
@export var accent_color: Color = Color.WHITE   ## signature neon (STYLE_GUIDE)
@export var portrait: Texture2D
@export var sprite_frames: SpriteFrames
@export var ability_scene: PackedScene          ## Ability subclass scene
@export var ultimate_scene: PackedScene         ## Ability subclass scene (is_ultimate)
@export var ability_cooldown: float = 8.0
@export_multiline var ability_text: String = ""
@export_multiline var ultimate_text: String = ""
