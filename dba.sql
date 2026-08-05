CREATE SCHEMA bookings;

CREATE TABLE bookings.airplanes_data (
    airplane_code character(3) NOT NULL,
    model jsonb NOT NULL,
    range integer NOT NULL,
    speed integer NOT NULL,
    CONSTRAINT airplanes_data_range_check CHECK ((range > 0)),
    CONSTRAINT airplanes_data_speed_check CHECK ((speed > 0))
)
DISTRIBUTED BY(airplane_code)
;