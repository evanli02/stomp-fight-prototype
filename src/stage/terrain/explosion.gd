class_name ExplosionHazard extends TerrainElement
## Telegraphed periodic blast: 2 s warning glow, then knockback + stun
## (combat.stun_explosion). Never removes a life (DESIGN 6.2).
@export var period: float = 6.0
@export var warning_time: float = 2.0
@export var knockback: float = 420.0
# TODO(M5)
