-- SEVENTH QUERY
@start_time
@end_time
SELECT 
    DISTINCT citizen.national_id, 
    citizen.first_name
FROM 
    citizen 
JOIN 
    trip_bill ON citizen.national_id = trip_bill.to_account
WHERE 
(
    SELECT COALESCE(EXTRACT(EPOCH FROM SUM(end_time - start_time)), 0)
    FROM 
        trip 
    JOIN 
        public_vehicle ON trip.vehicle_id = public_vehicle.vehicle_id
    WHERE 
        trip.trip_id = trip_bill.trip_id AND
        public_vehicle.network = 'metro' AND
        trip.start_time BETWEEN @start_time AND @end_time AND
        trip.end_time BETWEEN @start_time AND @end_time
) >
(
    SELECT COALESCE(EXTRACT(EPOCH FROM SUM(end_time - start_time)), 0)
    FROM 
        trip 
    JOIN 
        public_vehicle ON trip.vehicle_id = public_vehicle.vehicle_id
    WHERE 
        trip.trip_id = trip_bill.trip_id AND
        public_vehicle.network = 'bus' AND
        trip.start_time BETWEEN @start_time AND @end_time AND
        trip.end_time BETWEEN @start_time AND @end_time
);