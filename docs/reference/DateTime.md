---
title: Date & Period
parent: API Reference
---

# Date & Period

`OCCTDate` and `Period` wrap OCCT's `Quantity_Date` and `Quantity_Period`, providing a date/time point (January 1, 1979 onward, with microsecond precision) and a signed duration (days through microseconds) respectively. Both types are value types conforming to `Sendable`, `Equatable`, and `Comparable`.

## Topics

- [OCCTDate — Initializers](#occtdate--initializers) · [OCCTDate — Properties](#occtdate--properties) · [OCCTDate — Arithmetic](#occtdate--arithmetic) · [OCCTDate — Operators](#occtdate--operators) · [OCCTDate — Static Validation](#occtdate--static-validation) · [OCCTDate — Equatable & Comparable](#occtdate--equatable--comparable) · [Period — Initializers](#period--initializers) · [Period — Properties](#period--properties) · [Period — Operators](#period--operators) · [Period — Static Validation](#period--static-validation) · [Period — Equatable & Comparable](#period--equatable--comparable)

---

## OCCTDate — Initializers

### `OCCTDate.init?(month:day:year:hour:minute:second:millisecond:microsecond:)`

Creates a date from calendar components. Returns `nil` if the combination is not a valid Gregorian date or if `year` is before 1979.

```swift
public init?(month: Int, day: Int, year: Int, hour: Int = 0, minute: Int = 0,
             second: Int = 0, millisecond: Int = 0, microsecond: Int = 0)
```

All time-of-day components default to zero so you can create a date with only month/day/year. Validation is delegated to OCCT — the call returns `nil` whenever `Quantity_Date::IsValid` would return `false`.

- **Parameters:**
  - `month` — calendar month (1–12).
  - `day` — calendar day (1–31, validated against the month/year).
  - `year` — four-digit year; must be ≥ 1979.
  - `hour` — hour of day (0–23, default 0).
  - `minute` — minute (0–59, default 0).
  - `second` — second (0–59, default 0).
  - `millisecond` — millisecond sub-second component (0–999, default 0).
  - `microsecond` — microsecond sub-second component (0–999, default 0).
- **Returns:** An `OCCTDate`, or `nil` if any component is out of range or the year is before 1979.
- **OCCT:** `Quantity_Date::IsValid` (guard) → `Quantity_Date(mm, dd, yyyy, hh, mn, ss, mis, mics)`.
- **Example:**
  ```swift
  if let d = OCCTDate(month: 6, day: 15, year: 2024, hour: 9, minute: 30) {
      print(d.year, d.month, d.day)  // 2024, 6, 15
  }
  ```

---

### `OCCTDate.epoch`

The OCCT epoch date: January 1, 1979, 00:00:00.

```swift
public static var epoch: OCCTDate { get }
```

This is the zero-reference point for all internal `Quantity_Date` representations. All other dates are stored as a `Quantity_Period` offset from this value.

- **OCCT:** `Quantity_Date()` — default constructor returns January 1, 1979 00:00:00.
- **Example:**
  ```swift
  let e = OCCTDate.epoch
  print(e.year, e.month, e.day)  // 1979, 1, 1
  ```

---

## OCCTDate — Properties

### `components`

Decomposes the date into all calendar and time-of-day fields in one call.

```swift
public var components: (month: Int, day: Int, year: Int, hour: Int, minute: Int,
                        second: Int, millisecond: Int, microsecond: Int) { get }
```

Reconstructs the `Quantity_Date` from the stored seconds/microseconds offset and extracts all fields via `Quantity_Date::Values`.

- **Returns:** Named tuple with all eight date/time components.
- **OCCT:** `Quantity_Date::Values(mm, dd, yyyy, hh, mn, ss, mis, mics)`.
- **Example:**
  ```swift
  if let d = OCCTDate(month: 3, day: 21, year: 2000, hour: 12) {
      let c = d.components
      print(c.year, c.month, c.day, c.hour)  // 2000, 3, 21, 12
  }
  ```

---

### `month`

Calendar month of the date (1–12).

```swift
public var month: Int { get }
```

- **OCCT:** `Quantity_Date::Values` — extracts the month component.
- **Example:**
  ```swift
  let d = OCCTDate(month: 11, day: 5, year: 2023)!
  print(d.month)  // 11
  ```

---

### `day`

Calendar day of the month (1–31).

```swift
public var day: Int { get }
```

- **OCCT:** `Quantity_Date::Values` — extracts the day component.
- **Example:**
  ```swift
  let d = OCCTDate(month: 11, day: 5, year: 2023)!
  print(d.day)  // 5
  ```

---

### `year`

Four-digit calendar year (≥ 1979).

```swift
public var year: Int { get }
```

- **OCCT:** `Quantity_Date::Values` — extracts the year component.
- **Example:**
  ```swift
  let d = OCCTDate(month: 1, day: 1, year: 2000)!
  print(d.year)  // 2000
  ```

---

### `hour`

Hour of day (0–23).

```swift
public var hour: Int { get }
```

- **OCCT:** `Quantity_Date::Values` — extracts the hour component.
- **Example:**
  ```swift
  let d = OCCTDate(month: 1, day: 1, year: 2000, hour: 14, minute: 30)!
  print(d.hour)  // 14
  ```

---

### `minute`

Minute of hour (0–59).

```swift
public var minute: Int { get }
```

- **OCCT:** `Quantity_Date::Values` — extracts the minute component.
- **Example:**
  ```swift
  let d = OCCTDate(month: 1, day: 1, year: 2000, hour: 14, minute: 30)!
  print(d.minute)  // 30
  ```

---

### `second`

Second of minute (0–59).

```swift
public var second: Int { get }
```

- **OCCT:** `Quantity_Date::Values` — extracts the second component.
- **Example:**
  ```swift
  let d = OCCTDate(month: 1, day: 1, year: 2000, second: 45)!
  print(d.second)  // 45
  ```

---

### `millisecond`

Millisecond sub-second component (0–999).

```swift
public var millisecond: Int { get }
```

- **OCCT:** `Quantity_Date::Values` — extracts the millisecond component.
- **Example:**
  ```swift
  let d = OCCTDate(month: 1, day: 1, year: 2000, millisecond: 500)!
  print(d.millisecond)  // 500
  ```

---

### `microsecond`

Microsecond sub-second component (0–999).

```swift
public var microsecond: Int { get }
```

- **OCCT:** `Quantity_Date::Values` — extracts the microsecond component.
- **Example:**
  ```swift
  let d = OCCTDate(month: 1, day: 1, year: 2000, microsecond: 250)!
  print(d.microsecond)  // 250
  ```

---

## OCCTDate — Arithmetic

### `adding(_:)`

Returns a new date offset forward by the given period.

```swift
public func adding(_ period: Period) -> OCCTDate
```

Equivalent to the `+` operator. Always succeeds because adding a period to a valid date cannot underflow the epoch.

- **Parameters:** `period` — duration to add.
- **Returns:** A new `OCCTDate` advanced by `period`.
- **OCCT:** `Quantity_Date operator+` — computes `d + p` via OCCT, then re-encodes as a `Quantity_Period` offset from the epoch.
- **Example:**
  ```swift
  let start = OCCTDate(month: 1, day: 1, year: 2024)!
  if let week = Period(days: 7) {
      let next = start.adding(week)
      print(next.day)  // 8
  }
  ```

---

### `subtracting(_:)`

Returns a new date offset backward by the given period, or `nil` if the result would precede the OCCT epoch (Jan 1, 1979).

```swift
public func subtracting(_ period: Period) -> OCCTDate?
```

Returns `nil` if OCCT's subtraction would produce a date before January 1, 1979.

- **Parameters:** `period` — duration to subtract.
- **Returns:** New `OCCTDate` moved backward, or `nil` if the result predates the epoch.
- **OCCT:** `Quantity_Date operator-` — computes `d - p` via OCCT.
- **Example:**
  ```swift
  let d = OCCTDate(month: 3, day: 1, year: 2024)!
  if let month = Period(days: 29),
     let prev = d.subtracting(month) {
      print(prev.month, prev.day)  // 2, 1
  }
  ```

---

### `difference(to:)`

Computes the absolute duration between this date and another.

```swift
public func difference(to other: OCCTDate) -> Period
```

The result is always non-negative — it is the absolute value of the difference regardless of which date is earlier.

- **Parameters:** `other` — date to compare against.
- **Returns:** A `Period` representing the absolute duration between the two dates.
- **OCCT:** `Quantity_Date::Difference` — returns `|d1 − d2|` as a `Quantity_Period`.
- **Example:**
  ```swift
  let a = OCCTDate(month: 1, day: 1, year: 2024)!
  let b = OCCTDate(month: 1, day: 11, year: 2024)!
  let gap = a.difference(to: b)
  print(gap.components.days)  // 10
  ```

---

## OCCTDate — Operators

### `OCCTDate.+(_:_:)`

Adds a period to a date, returning a new date.

```swift
public static func + (date: OCCTDate, period: Period) -> OCCTDate
```

Calls `date.adding(period)`.

- **OCCT:** `Quantity_Date operator+`.
- **Example:**
  ```swift
  let d = OCCTDate(month: 12, day: 25, year: 2023)!
  if let oneWeek = Period(days: 7) {
      let newYear = d + oneWeek
      print(newYear.month, newYear.day)  // 1, 1
  }
  ```

---

### `OCCTDate.-(_:_:)`

Subtracts a period from a date, returning a new date or `nil` if the result precedes the epoch.

```swift
public static func - (date: OCCTDate, period: Period) -> OCCTDate?
```

Calls `date.subtracting(period)`.

- **OCCT:** `Quantity_Date operator-`.
- **Example:**
  ```swift
  let d = OCCTDate(month: 6, day: 1, year: 2024)!
  if let month = Period(days: 31),
     let prev = d - month {
      print(prev.month)  // 5
  }
  ```

---

## OCCTDate — Static Validation

### `OCCTDate.isValid(month:day:year:hour:minute:second:millisecond:microsecond:)`

Returns whether the given calendar and time components form a valid OCCT date.

```swift
public static func isValid(month: Int, day: Int, year: Int, hour: Int = 0,
                            minute: Int = 0, second: Int = 0,
                            millisecond: Int = 0, microsecond: Int = 0) -> Bool
```

Use this to pre-validate inputs before constructing an `OCCTDate` when you want to avoid optionals.

- **Parameters:** Same as `init?(month:day:year:hour:minute:second:millisecond:microsecond:)`.
- **Returns:** `true` if a date with these components can be created.
- **OCCT:** `Quantity_Date::IsValid(mm, dd, yyyy, hh, mn, ss, mis, mics)`.
- **Example:**
  ```swift
  print(OCCTDate.isValid(month: 2, day: 29, year: 2024))  // true (leap year)
  print(OCCTDate.isValid(month: 2, day: 29, year: 2023))  // false (not a leap year)
  ```

---

### `OCCTDate.isLeap(year:)`

Returns whether the given year is a leap year according to the Gregorian calendar.

```swift
public static func isLeap(year: Int) -> Bool
```

- **Parameters:** `year` — four-digit year.
- **Returns:** `true` if the year has 366 days.
- **OCCT:** `Quantity_Date::IsLeap(year)`.
- **Example:**
  ```swift
  print(OCCTDate.isLeap(year: 2000))  // true
  print(OCCTDate.isLeap(year: 1900))  // false
  print(OCCTDate.isLeap(year: 2024))  // true
  ```

---

## OCCTDate — Equatable & Comparable

### `OCCTDate.==(_:_:)`

Returns whether two dates represent the same instant.

```swift
public static func == (lhs: OCCTDate, rhs: OCCTDate) -> Bool
```

- **OCCT:** `OCCTDateCompare` returns 0 when both stored (sec, usec) pairs are equal.
- **Example:**
  ```swift
  let a = OCCTDate(month: 1, day: 1, year: 2024)!
  let b = OCCTDate(month: 1, day: 1, year: 2024)!
  #expect(a == b)
  ```

---

### `OCCTDate.<(_:_:)`

Returns whether the left date is earlier than the right date.

```swift
public static func < (lhs: OCCTDate, rhs: OCCTDate) -> Bool
```

Provides `Comparable` conformance, enabling sorting and range operations on `OCCTDate` values.

- **OCCT:** `OCCTDateCompare` returns a negative value when `lhs` precedes `rhs`.
- **Example:**
  ```swift
  let a = OCCTDate(month: 1, day: 1, year: 2020)!
  let b = OCCTDate(month: 1, day: 1, year: 2024)!
  #expect(a < b)
  let sorted = [b, a].sorted()
  #expect(sorted[0] == a)
  ```

---

## Period — Initializers

### `Period.init?(days:hours:minutes:seconds:milliseconds:microseconds:)`

Creates a period from component durations. Returns `nil` if the combination is not valid.

```swift
public init?(days: Int = 0, hours: Int = 0, minutes: Int = 0, seconds: Int = 0,
             milliseconds: Int = 0, microseconds: Int = 0)
```

All parameters default to zero, so you can create a period with only the components you need (e.g. `Period(days: 1)`). Validation is delegated to `Quantity_Period::IsValid`.

- **Parameters:**
  - `days` — number of days (default 0).
  - `hours` — hours component (default 0).
  - `minutes` — minutes component (default 0).
  - `seconds` — seconds component (default 0).
  - `milliseconds` — milliseconds component (default 0).
  - `microseconds` — microseconds component (default 0).
- **Returns:** A `Period`, or `nil` if any component is out of range.
- **OCCT:** `Quantity_Period::IsValid(dd, hh, mn, ss, mis, mics)` (guard) → `Quantity_Period(dd, hh, mn, ss, mis, mics)`.
- **Example:**
  ```swift
  if let p = Period(days: 1, hours: 6, minutes: 30) {
      print(p.components.days, p.components.hours)  // 1, 6
  }
  ```

---

### `Period.init?(totalSeconds:microseconds:)`

Creates a period from a total-seconds count and an optional microseconds remainder.

```swift
public init?(totalSeconds: Int, microseconds: Int = 0)
```

Useful when the duration comes from a raw elapsed-time measurement rather than calendar decomposition.

- **Parameters:**
  - `totalSeconds` — total number of seconds.
  - `microseconds` — additional microseconds (default 0).
- **Returns:** A `Period`, or `nil` if the values are invalid.
- **OCCT:** `Quantity_Period::IsValid(ss, mics)` (guard) → `Quantity_Period(ss, mics)` (two-argument constructor).
- **Example:**
  ```swift
  if let p = Period(totalSeconds: 3600) {
      let c = p.components
      print(c.hours)  // 1
  }
  ```

---

## Period — Properties

### `components`

Decomposes the period into days, hours, minutes, seconds, milliseconds, and microseconds.

```swift
public var components: (days: Int, hours: Int, minutes: Int, seconds: Int,
                        milliseconds: Int, microseconds: Int) { get }
```

- **Returns:** Named tuple with all six duration components.
- **OCCT:** `Quantity_Period::Values(dd, hh, mn, ss, mis, mics)`.
- **Example:**
  ```swift
  if let p = Period(totalSeconds: 90061) {
      let c = p.components
      print(c.days, c.hours, c.minutes, c.seconds)  // 1, 1, 1, 1
  }
  ```

---

### `totalSeconds`

The integer-seconds part of the total duration.

```swift
public var totalSeconds: Int { get }
```

Pair with `totalMicroseconds` to get the full sub-second precision. Together they satisfy: `duration ≈ totalSeconds + totalMicroseconds * 1e-6`.

- **OCCT:** `Quantity_Period::GetWhole(ss, mics)` — the seconds output.
- **Example:**
  ```swift
  if let p = Period(days: 1) {
      print(p.totalSeconds)  // 86400
  }
  ```

---

### `totalMicroseconds`

The microseconds remainder after expressing the duration as whole seconds.

```swift
public var totalMicroseconds: Int { get }
```

Returns the sub-second microsecond part only (0–999999). For example, a period of 1.0005 seconds has `totalSeconds == 1` and `totalMicroseconds == 500`.

- **OCCT:** `Quantity_Period::GetWhole(ss, mics)` — the microseconds output.
- **Example:**
  ```swift
  if let p = Period(seconds: 1, milliseconds: 500) {
      print(p.totalSeconds, p.totalMicroseconds)  // 1, 500000
  }
  ```

---

## Period — Operators

### `Period.+(_:_:)`

Adds two periods, returning a new period.

```swift
public static func + (lhs: Period, rhs: Period) -> Period
```

- **OCCT:** `Quantity_Period operator+`.
- **Example:**
  ```swift
  if let a = Period(hours: 1), let b = Period(minutes: 30) {
      let total = a + b
      print(total.components.hours, total.components.minutes)  // 1, 30
  }
  ```

---

### `Period.-(_:_:)`

Subtracts one period from another, returning a new period.

```swift
public static func - (lhs: Period, rhs: Period) -> Period
```

- **Note:** No overflow guard is applied; subtracting a larger period from a smaller one produces a period whose internal representation may be negative. Validate with `Period.isValid` if needed.
- **OCCT:** `Quantity_Period operator-`.
- **Example:**
  ```swift
  if let a = Period(hours: 2), let b = Period(hours: 1) {
      let diff = a - b
      print(diff.components.hours)  // 1
  }
  ```

---

## Period — Static Validation

### `Period.isValid(days:hours:minutes:seconds:milliseconds:microseconds:)`

Returns whether the given component values form a valid period.

```swift
public static func isValid(days: Int = 0, hours: Int = 0, minutes: Int = 0,
                            seconds: Int = 0, milliseconds: Int = 0,
                            microseconds: Int = 0) -> Bool
```

- **Parameters:** Same as `init?(days:hours:minutes:seconds:milliseconds:microseconds:)`.
- **Returns:** `true` if a period with these components can be created.
- **OCCT:** `Quantity_Period::IsValid(dd, hh, mn, ss, mis, mics)`.
- **Example:**
  ```swift
  print(Period.isValid(hours: 25))  // false (hours must be 0–23)
  print(Period.isValid(hours: 23, minutes: 59, seconds: 59))  // true
  ```

---

### `Period.isValid(totalSeconds:microseconds:)`

Returns whether a total-seconds representation is valid.

```swift
public static func isValid(totalSeconds: Int, microseconds: Int = 0) -> Bool
```

- **Parameters:**
  - `totalSeconds` — proposed total seconds count.
  - `microseconds` — proposed sub-second microseconds (default 0).
- **Returns:** `true` if these values can represent a valid `Quantity_Period`.
- **OCCT:** `Quantity_Period::IsValid(ss, mics)` (two-argument overload).
- **Example:**
  ```swift
  print(Period.isValid(totalSeconds: 86400))  // true (one day)
  print(Period.isValid(totalSeconds: -1))     // false
  ```

---

## Period — Equatable & Comparable

### `Period.==(_:_:)`

Returns whether two periods represent the same duration.

```swift
public static func == (lhs: Period, rhs: Period) -> Bool
```

- **OCCT:** `OCCTPeriodCompare` returns 0 when both (sec, usec) pairs are equal.
- **Example:**
  ```swift
  let a = Period(totalSeconds: 3600)!
  let b = Period(hours: 1)!
  #expect(a == b)
  ```

---

### `Period.<(_:_:)`

Returns whether the left period is shorter than the right.

```swift
public static func < (lhs: Period, rhs: Period) -> Bool
```

Provides `Comparable` conformance, enabling sorting and `min`/`max` on `Period` values.

- **OCCT:** `OCCTPeriodCompare` returns a negative value when `lhs` is shorter than `rhs`.
- **Example:**
  ```swift
  let minute = Period(minutes: 1)!
  let hour   = Period(hours: 1)!
  #expect(minute < hour)
  let sorted = [hour, minute].sorted()
  #expect(sorted[0] == minute)
  ```
