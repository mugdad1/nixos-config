# TODO

## ROG Battery Threshold

`charge_control_end_threshold` in asusd config not working — battery charges to 100% instead of stopping at 80%.

### Debug steps
```bash
# Check current threshold
cat /sys/class/power_supply/BAT0/charge_control_end_threshold

# Check asusd status
systemctl status asusd

# Test manually
echo 80 | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold
```

### Fix options
1. `boot.postBootCommands` — write to sysfs at boot, no asusd/TLP dependency
2. udev rule on `asus-nb-wmi` module load
3. Possible asus-wmi kernel regression (LKML June 2026)
