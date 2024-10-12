-- query 12
select c.national_id, (select avg(trip_bill.price) 
from citizen as c1
inner join trip_bill on c1.national_id = trip_bill.to_account 
where c.national_id=c1.national_id)
from citizen as c
where c.national_id in(select owner from personal_vehicle);