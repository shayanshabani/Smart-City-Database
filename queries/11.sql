-- ELEVENTH QUERY
@price
@station_id

WITH RECURSIVE Traverse_Paths AS (
  SELECT
    e.start_station AS start_node,
	e.end_station AS end_node,
    e.distance_km AS distance,
    1 AS depth
  FROM
    edge_in_path e
  WHERE
    e.start_station = @station_id

  UNION ALL

  SELECT
    e.start_station AS start_node,
	e.end_station AS end_node,
    tp.distance + e.distance_km AS distance,
    tp.depth + 1 AS depth
  FROM
    Traverse_Paths tp
    JOIN edge_in_path e ON tp.end_node = e.start_station
	JOIN path ON e.path_id = path.path_id
  WHERE
    tp.depth < 31 AND
	path.type = 'taxi' AND
	tp.distance * (SELECT cost_per_km FROM network WHERE type = 'taxi') < @price
)

SELECT DISTINCT
  end_node,
  distance * (SELECT cost_per_km FROM network WHERE type = 'taxi') as total_price
FROM
  Traverse_Paths
ORDER BY
  total_price;