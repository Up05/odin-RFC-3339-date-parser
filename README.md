# odin-RFC-3339-date-parser

Parser for the [RFC 3339 date & time spec](https://datatracker.ietf.org/doc/html/rfc3339) written in odin.
I mainly wrote this for my TOML parser, so you're allowed to have just the date or just the time, or NOTHING AT ALLLLL.

And by the way, it probably works.

```odin
  import dates "RFC_3339_date_parser"
  // ...
  date, err := dates.from_string("1996-02-29 16:39:57-08:00")
  fmt.println(dates.to_string(date)) // prints: 1996-02-29 16:39:57-08:00 NONE

  assert(dates.is_date_lax("1996-02-29 doesn't matter")) // quickly determines if some
  assert(dates.is_date_lax("96:02:29   doesn't matter")) // string looks like a date
```
