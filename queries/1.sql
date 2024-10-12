-- FIRST QUERY
@driver_id
@start_time
@end_time
SELECT COUNT(trip.trip_id)
FROM trip
WHERE @start_time <= trip.start_time
  AND @end_time >= trip.end_time  AND trip.vehicle_id IN (
      SELECT vehicle_id      
	  FROM public_vehicle
      WHERE driver = @driver_id  )
  AND (      
	  SELECT COUNT(citizen.national_id)
      FROM citizen      
	   JOIN account ON citizen.national_id = account.owner
      WHERE citizen.gender = 'female'        
	   AND citizen.national_id IN (
            SELECT to_account
            FROM trip_bill            
		   WHERE trip_id = trip.trip_id
        )  
	  ) >= 0.6 * (
      SELECT COUNT(citizen.national_id)      
		  FROM citizen
      JOIN account ON citizen.national_id = account.owner      
		  WHERE citizen.gender = 'male'
        AND citizen.national_id IN (            
			SELECT to_account
            FROM trip_bill            
			WHERE trip_id = trip.trip_id
        )  
	  );