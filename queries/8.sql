-- EIGHTH QUERY
@parking_id
-- timestamps
@start_time
@end_time
SELECT COUNT(DISTINCT CONCAT(personal_vehicle.brand, personal_vehicle.color)) AS unique_vehicle_count
FROM parking
JOIN parking_bill ON parking.parking_id = parking_bill.parking_id
JOIN personal_vehicle ON parking_bill.vehicle_id = personal_vehicle.vehicle_id
WHERE parking_bill.start_time BETWEEN @start_time AND @end_time
AND parking_bill.end_time BETWEEN @start_time AND @end_time AND
parking.parking_id = @parking_id;