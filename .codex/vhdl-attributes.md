# VHDL Predefined Attributes (Concise Overview)

This is a cleaned, concise reference based on:
- `.codex/VHDL attributes - Converse.pdf` (created February 16, 2026)
- Previous draft in `.codex/vhdl-attributes.md`
- Source page: <https://vhdlwhiz.com/attributes/converse/>

Scope note: this covers the 20 attributes listed on that source page as of February 16, 2026.

## Quick syntax

- General form: `prefix'attribute[(arg)]`
- `prefix` can be a signal, object, type, subtype, array, or mode view (depends on attribute).

## Attribute overview

| Attribute | Typical syntax | Returns / meaning | Key notes |
|---|---|---|---|
| `active` | `s'active` | `true` if a transaction (assignment/force/release) is scheduled for `s` in the current simulation cycle. | Transaction-based, not value-change-based. |
| `ascending` | `p'ascending`, `a'ascending(n)` | `true` if range direction is ascending (`to`), else `false` (`downto`). | For multidimensional arrays, `n` selects dimension. |
| `base` | `t'base`, `p'base` | The base type (root type) of a subtype/object. | `p'base` on objects is VHDL-2019; pre-2019 use type/subtype form. Usually chained (for example `t'base'right`). |
| `converse` | `m'converse` | Mode view with directions transformed (`in ↔ out`, `inout`/`buffer` unchanged). | VHDL-2019 mode-view feature. |
| `delayed` | `s'delayed`, `s'delayed(T)` | A signal representing `s` delayed by `T`. | Default `T` is `0 ns`; mainly simulation/timing modeling. |
| `designated_subtype` | `a'designated_subtype`, `f'designated_subtype` | The subtype designated by an access type/object or file type/object. | Useful for generic helpers over access/file abstractions. |
| `driving` | `s'driving` | `true` if the current process has an active driver on resolved signal `s`. | Process-local driver introspection; simulation-oriented. |
| `driving_value` | `s'driving_value` | Value currently driven on `s` by the current process. | Only meaningful for resolved signals in a driving process. |
| `element` | `a'element` | Element subtype of an array type/object. | VHDL-2008+. |
| `event` | `s'event` | `true` if `s` changed value in current simulation cycle. | Value-change detector; often used in clocked-process idioms. |
| `high` | `p'high`, `a'high(n)` | Upper bound of range. | Direction-aware bound query. |
| `image` | `t'image(x)` | String image of value `x`. | Classic for scalar types; VHDL-2019 improves composite coverage. |
| `index` | `a'index`, `a'index(n)` | Index type for array dimension `n`. | VHDL-2019+. |
| `left` | `p'left`, `a'left(n)` | Left bound of range declaration. | Left/right are declaration-order bounds, not min/max. |
| `leftof` | `p'leftof(x)` | Neighbor immediately to the left of `x` in type ordering. | Depends on type direction/order. |
| `low` | `p'low`, `a'low(n)` | Lower bound of range. | Min bound query. |
| `quiet` | `s'quiet`, `s'quiet(T)` | `true` if no transaction occurred on `s` during interval `T`. | Differs from `stable`: even same-value assignments break `quiet`. |
| `right` | `p'right`, `a'right(n)` | Right bound of range declaration. | Complements `left`. |
| `rightof` | `p'rightof(x)` | Neighbor immediately to the right of `x` in type ordering. | Complement of `leftof`. |
| `stable` | `s'stable`, `s'stable(T)` | `true` if `s` has had no value change during interval `T`. | Value-change based; same-value transactions do not break `stable`. |

## Grouping by use

- Simulation/time behavior: `active`, `event`, `stable`, `quiet`, `delayed`, `driving`, `driving_value`
- Range/type introspection: `ascending`, `high`, `low`, `left`, `right`, `leftof`, `rightof`, `base`, `index`, `element`, `designated_subtype`
- Formatting/view semantics: `image`, `converse`

## Practical reminders

- Prefer these attributes over hard-coded bounds (`'left`, `'right`, `'high`, `'low`) for generic RTL.
- Treat `driving*`, `active`, `delayed`, `quiet`, and many `event`-style checks as simulation-first constructs unless your synthesis tool explicitly supports the pattern.
- For portable code, guard VHDL-2019-only attributes (`converse`, object-form `base`, `index`) if your toolchain is older.
