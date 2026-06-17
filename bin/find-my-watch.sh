#!/bin/zsh
# find-my-watch — list Bluetooth devices that report a live RSSI so you can
# identify your Apple Watch's address for WATCH_ADDR in presence.conf.
#
# Wear the Watch and stay near the Mac while running this: the entry whose RSSI
# is closest to 0 (e.g. -40..-55) on your wrist is almost certainly your Watch.
set -u

print "Bluetooth devices reporting RSSI (name / address / rssi):\n"
system_profiler SPBluetoothDataType 2>/dev/null | grep -B5 "RSSI:" \
  | grep -E "^ +[^ ].*:$|Address:|RSSI:" \
  | grep -vE "^ +(Not )?Connected:$" \
  | sed -E 's/^ +//'
print "\nPick the device with the strongest (closest-to-0) RSSI while it's on your wrist,"
print "then set WATCH_ADDR to its Address in presence.conf."
