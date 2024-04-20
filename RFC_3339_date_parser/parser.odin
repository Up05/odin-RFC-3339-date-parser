package dateparser

import "core:strconv"
import "core:slice"
import "core:strings"
import "core:fmt"

DateError :: enum {
    NONE,

    // Where parser REALIZED something is wrong!
    FAILED_AT_YEAR, 
    FAILED_AT_MONTH,
    FAILED_AT_DAY,
    FAILED_AT_HOUR,
    FAILED_AT_MINUTE,
    FAILED_AT_SECOND,
    FAILED_AT_OFFSET_HOUR,
    FAILED_AT_OFFSET_MINUTE,

    YEAR_OUT_OF_BOUNDS,
    MONTH_OUT_OF_BOUNDS, // 01-12
    DAY_OUT_OF_BOUNDS,
    HOUR_OUT_OF_BOUNDS,
    MINUTE_OUT_OF_BOUNDS,
    SECOND_OUT_OF_BOUNDS,
    OFFSET_HOUR_OUT_OF_BOUNDS,
    OFFSET_MINUTE_OUT_OF_BOUNDS,

    FAILED_AT_TIME_SEPERATOR, // character seperating full-date & full-time isn't in variable "time_separators"
}

// may be overwritten. Set to empty array to accept any time seperator
time_separators : [] string = { "t", "T", " " }
offset_separators : [] string = { "z", "Z", "+", "-" }

Date :: struct {
    year, month, day : int,

    hour, minute     : int,
    second           : f32,

    offset_hour      : int, 
    offset_minute    : int, 
}

from_string :: proc(date: string) -> (out: Date, err: DateError) {
    date := date
    
    ok : bool
    
    // ##############################  D A T E  ##############################
    
    // Because there has to be a leading zero
    if date[4:5] == "-" { 
        out.year,  ok = parse_int(date[0:4])
        if !ok do return out, .FAILED_AT_YEAR

        out.month, ok = parse_int(date[5:7])
        if !ok do return out, .FAILED_AT_MONTH
        if !between(out.month, 0, 12) do return out, .MONTH_OUT_OF_BOUNDS

        out.day, ok = parse_int(date[8:10])
        if !ok do return out, .FAILED_AT_DAY
        if !between(out.day, 0, days_in_month(out.year, out.month)) do return out, .DAY_OUT_OF_BOUNDS

        if len(date) > 10 {
            if !(len(time_separators) == 0 || slice.any_of(time_separators, date[10:11])) { 
                return out, .FAILED_AT_TIME_SEPERATOR
            }

            date = date[11:]
        }
    }
    
    // ##############################  T I M E  ##############################

    if len(date) > 7 {
        out.hour, ok = parse_int(date[0:2])
        if !ok do return out, .FAILED_AT_HOUR
        if !between(out.hour, 0, 23) do return out, .HOUR_OUT_OF_BOUNDS

        out.minute, ok = parse_int(date[3:5])
        if !ok do return out, .FAILED_AT_MINUTE
        if !between(out.minute, 0, 59) do return out, .MINUTE_OUT_OF_BOUNDS

        date = date[6:] // because of "-"
        offset, _ := strings.index_multi(date, offset_separators)

        out.second, ok = strconv.parse_f32(date[:offset if offset != -1 else len(date)])
        if !ok do return out, .FAILED_AT_SECOND
        // seconds \in [00, 60], because of leap seconds 
        if !between(int(out.second), 0, 60) do return out, .SECOND_OUT_OF_BOUNDS

        if offset != -1 {
            date = date[offset:]
            // fine to have lowercase here, because it wouldn't have been detected otherwise
            if strings.to_lower(date[:1]) == "z" do return

            out.offset_hour, ok = parse_int(date[1:3])
            if !ok do return out, .FAILED_AT_OFFSET_HOUR
            if !between(out.offset_hour, 0, 23) do return out, .OFFSET_HOUR_OUT_OF_BOUNDS

            out.offset_minute, ok = parse_int(date[4:6])
            if !ok do return out, .FAILED_AT_OFFSET_MINUTE
            if !between(out.offset_minute, 0, 59) do return out, .OFFSET_MINUTE_OUT_OF_BOUNDS

            if date[:1] == "-" {
                out.offset_hour *= -1
                out.offset_minute *= -1
            }

        }
    }

    return
}

to_string :: proc(date: Date, time_sep := ' ') -> (out: string, err: DateError) {
    date := date

    {
        using date
        if !between(year, 0, 9999)      do return "", .YEAR_OUT_OF_BOUNDS
        if !between(month, 0, 12)       do return "", .MONTH_OUT_OF_BOUNDS
        if !between(day, 0, days_in_month(year, month)) do return "", .DAY_OUT_OF_BOUNDS
        if !between(hour, 0, 23)        do return "", .HOUR_OUT_OF_BOUNDS
        if !between(minute, 0, 59)      do return "", .MINUTE_OUT_OF_BOUNDS
        if !between(int(second), 0, 60) do return "", .SECOND_OUT_OF_BOUNDS
        if !between(offset_hour, -23, 23)   do return "", .OFFSET_HOUR_OUT_OF_BOUNDS
        if !between(offset_minute, -59, 59) do return "", .OFFSET_MINUTE_OUT_OF_BOUNDS
    }

    b : strings.Builder
    strings.builder_init_len_cap(&b, 0, 25)
    
    fmt.sbprintf(&b, "%04d-%02d-%02d", date.year, date.month, date.day)
    strings.write_rune(&b, time_sep)
    fmt.sbprintf(&b, "%02d:%02d:%02.0f", date.hour, date.minute, date.second)
    
    if date.offset_hour == 0 && date.offset_minute == 0 do strings.write_rune(&b, 'Z')
    else {
        if date.offset_hour < 0 do strings.write_rune(&b, '-')
        else do strings.write_rune(&b, '+')

        if date.offset_hour < 0 && date.offset_minute > 0 {
            date.offset_hour -= 1
            date.offset_minute = 60 - date.offset_minute
        } else if date.offset_hour > 0 && date.offset_minute < 0 {
            date.offset_hour += 1
            date.offset_minute = 60 - date.offset_minute
        } 

        fmt.sbprintf(&b, "%02d:%02d", abs(date.offset_hour), abs(date.offset_minute))
    }

    return strings.to_string(b), .NONE
}





// this is a very specific function, kind of a misnomer, but whatever.
@(private="file")
parse_int :: proc(num: string) -> (int, bool) {
   num, ok := strconv.parse_uint(num, 10) 
   return int(num), ok
}

@(private="file")
between :: proc(a, lo, hi: int) -> bool {
    return a >= lo && a <= hi
}

@(private="file")
days_in_month :: proc(year: int, month: int) -> int {
    if slice.any_of([] int { 1, 3, 5, 7, 8, 10, 12 }, month) do return 31
    if slice.any_of([] int { 4, 6, 9, 11 }, month) do return 30
    // just February left
    if leap_year(year) do return 29
    return 28
}

@(private="file")
leap_year :: proc(year: int) -> bool {
    return (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0))
}
