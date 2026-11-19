# Business Definitions & Data Governance — NASCAR Cup Series Analytics (2022–2026)

This document serves as the single source of truth for analytical definitions, track normalizations, metric calculations, and data-quality rules across `nascar_fan_analytics_mcp`. Both the ingestion pipeline and the MCP AI agent must strictly adhere to these rules.

---

## 1. Track Normalization & Data Imputation Rules

- **Sponsored Venue Renames:**
  - `Atlanta Motor Speedway` (2022–Spring 2025) and `EchoPark Speedway` (Summer 2025–2026) represent the exact same 1.54-mile physical venue in Hampton, Georgia. Both normalize to a single canonical `track_id` (`ATLANTA`) so multi-year track comparisons remain continuous.
- **Distinct Multi-Layout Venues (Kept Separate):**
  - Venues hosting races on distinct physical layouts remain separate `track_id` entries with distinct canonical names because they belong to different competitive archetypes:
    - `Charlotte Oval` (`CHARLOTTE_OVAL`, 1.50-mile paved oval) vs. `Charlotte Roval` (`CHARLOTTE_ROVAL`, 2.28-mile road course/roval)
    - `Indianapolis Oval` (`INDY_OVAL`, 2.50-mile flat rectangular oval) vs. `Indianapolis Road Course` (`INDY_ROAD`, 2.44-mile road course)
    - `Bristol Oval` (`BRISTOL_OVAL`, 0.53-mile paved short track) vs. `Bristol Dirt Track` (`BRISTOL_DIRT`, 0.53-mile dirt surface)
- **Missing Schedule Metadata Imputation (`NaN` Values in Raw 2026 Rows):**
  - Four 2026 entries lack `Surface` and `Length` values in `cup_series.parquet` and are explicitly imputed during ingestion:
    - `Chicagoland Speedway` (`CHICAGOLAND`): `surface = "paved"`, `length_miles = 1.50`
    - `EchoPark Speedway` (`ATLANTA`): `surface = "paved"`, `length_miles = 1.54`
    - `Naval Base Coronado` (`CORONADO`): `surface = "road"`, `length_miles = 3.40`
    - `North Wilkesboro Speedway` (`NORTH_WILKESBORO`): `surface = "paved"`, `length_miles = 0.625`

---

## 2. Track Archetype Taxonomy (`track_type`)

Every canonical track in `dim_tracks` is classified into one of five mutually exclusive `track_type` values, paired with a separate `is_drafting_pack` boolean flag (`TRUE` for pack/drafting-style racing, `FALSE` otherwise):

- **`Superspeedway`:** High-banked drafting ovals `>= 2.50` miles (`Daytona International Speedway`, `Talladega Superspeedway`). `is_drafting_pack = TRUE`.
- **`Intermediate`:** Paved ovals between `1.25` and `2.00` miles (`Atlanta/EchoPark`, `Auto Club`, `Charlotte Oval`, `Chicagoland`, `Homestead-Miami`, `Kansas`, `Las Vegas`, `Michigan`, `Nashville`, `Texas`, `World Wide Technology Raceway at Gateway`). Set `is_drafting_pack = TRUE` for `Atlanta/EchoPark` and `FALSE` for other intermediates.
- **`Short_Track`:** Paved ovals `< 1.10` miles (`Bristol Oval`, `Dover`, `Iowa`, `Martinsville`, `New Hampshire`, `North Wilkesboro`, `Phoenix`, `Richmond`). `is_drafting_pack = FALSE`.
- **`Road_Course`:** Purpose-built road circuits, rovals, and street circuits (`Autodromo Hermanos Rodriguez`, `Charlotte Roval`, `Chicago Street Course`, `Circuit of the Americas`, `Indianapolis Road Course`, `Naval Base Coronado`, `Road America`, `Sonoma`, `Watkins Glen`). `is_drafting_pack = FALSE`.
- **`Unique_Oval_or_Dirt`:** Non-standard flat/rectangular/triangular ovals or dirt surfaces (`Pocono Raceway` [2.50-mile flat triangular oval], `Indianapolis Oval` [2.50-mile flat rectangular oval], `Bristol Dirt Track`). `is_drafting_pack = FALSE`.

---

## 3. Table Grain, Keys & Data-Quality Contracts

| Table | Grain (1 Row Per) | Primary Key | Uniqueness & Nullability Rules |
|---|---|---|---|
| `dim_tracks` | Canonical track layout (`track_id`) | `track_id` | `track_id`, `canonical_name`, `track_type`, `is_drafting_pack` non-null; `track_id` unique |
| `dim_races` | NASCAR Cup Series points race (`race_id`) | `race_id` | `(season_year, race_number)` unique; `track_id` must exist in `dim_tracks` |
| `fact_broadcast_metrics` | Broadcast/metric record per points race (`race_id`) | `race_id` | 1:1 with `dim_races` points races; exhibition/non-points events excluded unless flagged |

---

## 4. Season & Event Flags (`dim_races`)

- **Regular Season vs. Playoff Window (`is_playoff`):**
  - **Regular Season (`FALSE`):** `race_number` `1` through `26`.
  - **NASCAR Cup Series Playoffs (`TRUE`):** `race_number` `27` through `36` (10-race postseason elimination format).
- **Crown Jewel Events (`is_crown_jewel`):**
  - `TRUE` for NASCAR's four historic prestige events regardless of title sponsor changes:
    1. **Daytona 500** (Season opener at `Daytona International Speedway`, `race_number = 1`)
    2. **Coca-Cola 600** (Memorial Day weekend 600-mile race at `Charlotte Oval`)
    3. **Brickyard 400** (Oval race at `Indianapolis Oval`—`TRUE` for 2024–2026 oval runs; `FALSE` for 2022–2023 road course runs)
    4. **Southern 500** (Labor Day weekend race at `Darlington Raceway`)

---

## 5. Broadcast & Competitiveness Metric Definitions (`fact_broadcast_metrics`)

- **`viewers_millions`:** Total average live+same-day viewership in millions as reported by Nielsen / Sports Media Watch / Jayski.
- **`network`:** Primary broadcast or streaming platform airing the race (`FOX`, `FS1`, `Prime`, `TNT`, `USA`, `NBC`). For weather-delayed or multi-day split broadcasts, record the primary/concluding network and note weather/split status in a separate `broadcast_notes` field if present.
- **`distinct_leaders`:** Count of unique drivers who led at least one lap (`Led > 0`) during the race; serves as the primary on-track parity/competitiveness proxy.
- **`field_size`:** Total number of classified starters (`COUNT(DISTINCT Driver)`) in the event.
- **`actual_laps`:** Maximum laps completed by the race winner (`MAX(Laps)`), capturing overtime/Green-White-Checkered extensions. Store planned distance separately in `scheduled_laps` so overtime extensions (`actual_laps > scheduled_laps`) are explicit.

---

## 6. MCP AI Agent Guardrails

- **Do:** Always join tables on canonical `track_id` and `race_id`; use `is_drafting_pack = TRUE` when answering queries about pack/drafting racing across both superspeedways and Atlanta/EchoPark; compare `actual_laps` against `scheduled_laps` when discussing overtime finishes.
- **Don't:** Do not treat `Indianapolis Oval` and `Indianapolis Road Course` as the same layout; do not compare `viewers_millions` across different days of week, time slots, or streaming/linear windows without noting those differences; do not include exhibition/non-points races in `race_number` `1–36` points-season aggregations.