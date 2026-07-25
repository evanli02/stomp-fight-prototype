class_name Portal extends TerrainElement
## Paired teleport. Velocity vector is PRESERVED and rotated to the exit's
## orientation (DESIGN 6.2). Brief re-entry lockout to prevent ping-ponging.
@export var linked_portal: NodePath
# TODO(M5)
