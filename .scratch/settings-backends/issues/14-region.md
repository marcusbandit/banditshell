# Region: 24-hour clock, date format, time zone, language, formats

Status: done

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

## Built

How the shell shows time: keys `region.clock24` (true) and `region.dateFormat`
(`slashes` | `dotted` | `iso` | `words`, default `slashes` as the panel
planned). `services/TimeFormat.qml` (maths in `timeformat.js`) is the one
formatter. The sidebar clock hour, the calendar's month, the clock menu, the
lock face, the sidebar title, the stream panel, file dates and properties,
alarm titles and every world clock go through it. Names are English whatever
the system language is, so the shell never switches language under the person.
The sidebar clock's day and month atoms stay as they were (layout, not a
format); that file was being reshaped elsewhere.

The system: `services/Localisation.qml` (parsing in `localisation.js`) changes
the zone (`timedatectl set-timezone`), language and formats
(`localectl set-locale`, keeping the other variables because set-locale
replaces them all) only when the panel asks, never at load. Both need a
password (polkit `auth_admin_keep`; hyprpolkitagent is running here). Language
and formats are LANG and LC_NUMERIC, LC_MONETARY, LC_MEASUREMENT, LC_PAPER, and
say they take effect at next sign-in. Current values are read back from
`localectl status` and `timedatectl show`. Locales that `localectl
list-locales` does not show are listed as "not set up on this machine" and
refuse with a toast.

Zone from network: geoclue's `where-am-i` demo client (the only way to ask
geoclue without a GUI agent), then the nearest zone in `zone.tab` and
`zone1970.tab` (zone.tab first: zone1970 folds Copenhagen into Berlin). When
geoclue is missing the row says so and stays off. The key defaults to false
(not true as planned): a default of on would claim a zone nothing sets.
Decisions: the Zone row offers the zone in use, the world clocks and 20 big
zones rather than all 400; the formats detail drops "monday first" because
LC_TIME is not one of the variables set.

Still to check by a person: nothing here changed the system. A real zone
change (the password prompt, and that the running shell's clocks follow
without a restart), a real language change, and zone from network need doing on
a machine with geoclue; geoclue is not installed on this one, so that path is
tested only against sample output. The default date style (14/10/2026) makes
the lock face read "Wednesday 14/10" where it said "Wednesday 14 October";
`words` restores that and is one word in `config/Config.qml`.
