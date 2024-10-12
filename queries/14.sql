-- FOURTEENTH QUERY
@start_station
@end_station

WITH RECURSIVE Traverse_Paths AS (
  SELECT
    e.start_station AS start_node,
	  e.end_station AS end_node,
    e.distance_km AS distance,
    1 AS depth
  FROM
    edge_in_path e
  WHERE
    e.start_station = @start_station

  UNION ALL

  SELECT
    tp.end_node AS start_node,
	e.end_station AS end_node,
    tp.distance + e.distance_km AS distance,
    tp.depth + 1 AS depth
  FROM
    Traverse_Paths tp
    JOIN edge_in_path e ON tp.end_node = e.start_station
  WHERE
    tp.depth < 31 AND
	tp.end_node <> @end_station
)

SELECT DISTINCT
  distance
FROM
  Traverse_Paths
ORDER BY
  distance desc 1;