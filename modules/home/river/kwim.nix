# kwim configuration (kwm's input manager).
#
# kwm spawns `kwim` (must be on PATH) on startup/input-hotplug; kwim reads
# ~/.config/kwim/config.zon and applies libinput + keyboard repeat rules.
# Keyboard layout itself stays on XKB_DEFAULT_* env (variables.nix) —
# river/xkbcommon read those, kwm matches bindings against river's keymap.
{...}: {
  xdg.configFile."kwim/config.zon".text = ''
    // mugdad's kwim configuration (input rules for the river session)
    // generated from modules/home/river/kwim.nix
    .{
        .input_device_rules = .{
            .{ .repeat_info = .{ .rate = 50, .delay = 300 } },
        },
        .libinput_device_rules = .{
            .{ .name = .{ .str = ".*[tT]ouchpad", .regex = true }, .tap = .enabled, .drag = .enabled, .natural_scroll = .enabled },
            .{ .tap = .enabled, .drag = .enabled },
        },
        .xkb_keyboard_rules = .{
        },
    }
  '';
}
