-- FIFTH QUERY
@location
SELECT 
    station_id,
    name,
	(((location[0] - @location[0])^2 + (location[1] - @location[1])^2)^0.5)
     AS distance
FROM 
    station
ORDER BY 
    distance ASC
LIMIT 5;