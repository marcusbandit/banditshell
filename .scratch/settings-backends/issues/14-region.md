# Region: 24-hour clock, date format, time zone, language, formats

Status: needs-triage

Rows: System › Language › 24-hour clock `clock24`, Dates `dateFormat`, Zone
from network `autoZone`, Zone `zone`, Language `lang`, Formats `region`.

## What to build

- 24-hour clock and date format: keys `region.clock24`, `region.dateFormat`,
  read by every place the shell formats a time (sidebar clock, calendar, clock
  menu, lock screen, notifications).
- Time zone: `timedatectl set-timezone` and `set-ntp`, or
  geoclue-backed automatic zone; needs polkit, so it may ask for a password.
- Language and formats: `localectl set-locale`; the shell itself is English, so
  this is the system's.

## To decide

Whether the shell should change the system locale and zone at all, or only how
it shows times.
