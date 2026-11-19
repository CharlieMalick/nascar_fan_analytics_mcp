CREATE TABLE dim_tracks (
    track_id VARCHAR PRIMARY KEY,
    canonical_name VARCHAR NOT NULL,
    surface VARCHAR NOT NULL,
    length_miles DOUBLE NOT NULL,
    track_type VARCHAR NOT NULL,
    is_drafting_pack BOOLEAN NOT NULL
);

CREATE TABLE dim_races (
    race_id VARCHAR PRIMARY KEY,
    season_year INTEGER NOT NULL,
    race_number INTEGER NOT NULL,
    race_name VARCHAR NOT NULL,
    track_id VARCHAR NOT NULL,
    is_playoff BOOLEAN NOT NULL,
    is_crown_jewel BOOLEAN NOT NULL,
    UNIQUE (season_year, race_number),
    FOREIGN KEY (track_id) REFERENCES dim_tracks(track_id)
);

CREATE TABLE fact_broadcast_metrics (
    race_id VARCHAR PRIMARY KEY,
    network VARCHAR,
    viewers_millions DOUBLE,
    broadcast_notes VARCHAR,
    distinct_leaders INTEGER NOT NULL,
    field_size INTEGER NOT NULL,
    scheduled_laps INTEGER NOT NULL,
    actual_laps INTEGER NOT NULL,
    FOREIGN KEY (race_id) REFERENCES dim_races(race_id)
);