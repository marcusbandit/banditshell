#!/bin/sh
for h in /sys/class/hwmon/hwmon*; do
    case "$(cat "$h/name" 2>/dev/null)" in
    coretemp | k10temp | zenpower | cpu_thermal | soc_thermal)
        for label in "$h"/temp*_label; do
            case "$(cat "$label" 2>/dev/null)" in
            "Package id 0" | Tctl | Tdie)
                echo "${label%_label}_input"
                exit 0
                ;;
            esac
        done
        [ -e "$h/temp1_input" ] && echo "$h/temp1_input" && exit 0
        ;;
    esac
done
for z in /sys/class/thermal/thermal_zone*; do
    case "$(cat "$z/type" 2>/dev/null)" in
    x86_pkg_temp | k10temp | cpu* | soc*)
        echo "$z/temp"
        exit 0
        ;;
    esac
done
for z in /sys/class/thermal/thermal_zone*; do
    [ "$(cat "$z/type" 2>/dev/null)" = acpitz ] && echo "$z/temp" && exit 0
done
[ -e /sys/class/thermal/thermal_zone0/temp ] && echo /sys/class/thermal/thermal_zone0/temp
exit 0
