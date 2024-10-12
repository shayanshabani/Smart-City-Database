from peewee import *
from dotenv import load_dotenv
import os


##########################  models  ##########################

load_dotenv()

database = PostgresqlDatabase(
     os.getenv('DB_NAME'), 
    **{
        'user':  os.getenv('DB_USER'), 
        'password':  os.getenv('DB_PASSWORD'),
    }
)



class PointField(Field):
    field_type = 'point'

    # def db_value(self, value):
    #     return fn.ST_GeomFromGeoJSON(value)

    # def python_value(self, value):
    #     return fn.ST_AsGeoJSON(value) 

class BaseModel(Model):
    class Meta:
        database = database

class Citizen(BaseModel):
    date_of_birth = DateField(null=True)
    first_name = CharField(null=True)
    gender = CharField(null=True)
    headman = ForeignKeyField(column_name='headman', field='national_id', model='self')
    last_name = CharField(null=True)
    national_id = CharField(primary_key=True)

    class Meta:
        table_name = 'citizen'

class Account(BaseModel):
    balance = IntegerField(null=True)
    owner = ForeignKeyField(column_name='owner', field='national_id', model=Citizen, primary_key=True)

    class Meta:
        table_name = 'account'

class HouseBill(BaseModel):
    bill_id = CharField(primary_key=True)
    finish_date = DateField(null=True)
    issue_date = DateField(null=True)
    price = IntegerField(null=True)
    start_date = DateField(null=True)
    to_account = ForeignKeyField(column_name='to_account', field='owner', model=Account)

    class Meta:
        table_name = 'house_bill'

class House(BaseModel):
    alley = CharField(null=True)
    house_id = CharField(primary_key=True)
    location = PointField(null=True)  # point
    owner = ForeignKeyField(column_name='owner', field='national_id', model=Citizen, null=True)
    postal_code = CharField(null=True, unique=True)
    street = CharField(null=True)

    class Meta:
        table_name = 'house'

class HouseServiceRequest(BaseModel):
    accepted = BooleanField(constraints=[SQL("DEFAULT false")], null=True)
    house = ForeignKeyField(column_name='house_id', field='house_id', model=House)
    price_per_unit = IntegerField(null=True)
    request_date = DateField()
    request_type = CharField()
    id = AutoField(primary_key=True)

    class Meta:
        table_name = 'house_service_request'
        indexes = (
            (('request_type', 'request_date', 'house'), True),
        )
        # primary_key = CompositeKey('house', 'request_date', 'request_type')

class DailyUsage(BaseModel):
    bill = ForeignKeyField(column_name='bill_id', field='bill_id', model=HouseBill, null=True)
    request_id = ForeignKeyField(column_name='id', field='id', model=HouseServiceRequest)
    total_usage = IntegerField(null=True)
    usage_date = DateField()

    class Meta:
        table_name = 'daily_usage'
        indexes = (
            (('request_id', 'usage_date'), True),
        )
        primary_key = CompositeKey('request_id', 'usage_date')

class Station(BaseModel):
    location = PointField(null=True)  # point
    name = CharField(null=True)
    station_id = AutoField()

    class Meta:
        table_name = 'station'

class Network(BaseModel):
    cost_per_km = IntegerField(null=True)
    type = CharField(primary_key=True)

    class Meta:
        table_name = 'network'

class Path(BaseModel):
    name = CharField(null=True)
    path_id = CharField(primary_key=True)
    type = ForeignKeyField(column_name='type', field='type', model=Network)

    class Meta:
        table_name = 'path'

class EdgeInPath(BaseModel):
    distance_km = IntegerField(null=True)
    end_station = ForeignKeyField(column_name='end_station', field='station_id', model=Station)
    estimated_time_minute = IntegerField(null=True)
    path = ForeignKeyField(column_name='path_id', field='path_id', model=Path)
    start_station = ForeignKeyField(backref='station_start_station_set', column_name='start_station', field='station_id', model=Station)

    class Meta:
        table_name = 'edge_in_path'
        indexes = (
            (('path', 'start_station', 'end_station'), True),
        )
        primary_key = CompositeKey('end_station', 'path', 'start_station')

class Parking(BaseModel):
    capacity = IntegerField(null=True)
    closing_time = TimeField(null=True)
    cost_per_hour = IntegerField(null=True)
    location = PointField(null=True)  # point
    name = CharField(null=True)
    opening_time = TimeField(null=True)
    parking_id = CharField(primary_key=True)

    class Meta:
        table_name = 'parking'

class PersonalVehicle(BaseModel):
    brand = CharField(null=True)
    color = CharField(null=True)
    owner = ForeignKeyField(column_name='owner', field='national_id', model=Citizen)
    vehicle_id = CharField(primary_key=True)

    class Meta:
        table_name = 'personal_vehicle'

class ParkingBill(BaseModel):
    bill_id = CharField(primary_key=True)
    end_time = DateTimeField(null=True)
    issue_date = DateField(null=True)
    parking = ForeignKeyField(column_name='parking_id', field='parking_id', model=Parking)
    price = IntegerField(null=True)
    start_time = DateTimeField(null=True)
    to_account = ForeignKeyField(column_name='to_account', field='owner', model=Account)
    vehicle = ForeignKeyField(column_name='vehicle_id', field='vehicle_id', model=PersonalVehicle)

    class Meta:
        table_name = 'parking_bill'

class PublicVehicle(BaseModel):
    brand = CharField(null=True)
    color = CharField(null=True)
    driver = ForeignKeyField(column_name='driver', field='national_id', model=Citizen, unique=True)
    network = ForeignKeyField(column_name='network', field='type', model=Network)
    vehicle_id = CharField(primary_key=True)

    class Meta:
        table_name = 'public_vehicle'

class StationPath(BaseModel):
    path = ForeignKeyField(column_name='path_id', field='path_id', model=Path)
    station = ForeignKeyField(column_name='station_id', field='station_id', model=Station)

    class Meta:
        table_name = 'station_path'
        indexes = (
            (('path', 'station'), True),
        )
        primary_key = CompositeKey('path', 'station')

class Trip(BaseModel):
    end_time = DateTimeField(null=True)
    start_time = DateTimeField(null=True)
    total_distance = IntegerField(null=True)
    trip_id = AutoField()
    vehicle = ForeignKeyField(column_name='vehicle_id', field='vehicle_id', model=PublicVehicle)

    class Meta:
        table_name = 'trip'

class TraversedPath(BaseModel):
    end_station = ForeignKeyField(column_name='end_station', field='station_id', model=Station)
    entrance_time = DateTimeField(null=True)
    path = ForeignKeyField(column_name='path_id', field='path_id', model=Path)
    start_station = ForeignKeyField(backref='station_start_station_set', column_name='start_station', field='station_id', model=Station)
    trip = ForeignKeyField(column_name='trip_id', field='trip_id', model=Trip)

    class Meta:
        table_name = 'traversed_path'
        indexes = (
            (('trip', 'path', 'start_station', 'end_station'), True),
        )
        primary_key = CompositeKey('end_station', 'path', 'start_station', 'trip')

class TripBill(BaseModel):
    bill_id = CharField(primary_key=True)
    issue_date = DateField(null=True)
    price = IntegerField(null=True)
    to_account = ForeignKeyField(column_name='to_account', field='owner', model=Account)
    trip = ForeignKeyField(column_name='trip_id', field='trip_id', model=Trip)

    class Meta:
        table_name = 'trip_bill'


##########################  functions  ##########################

def create_tables():
    print('creating tables')
    database.create_tables([
        Citizen,
        Account,
        HouseBill,
        House,
        HouseServiceRequest,
        DailyUsage,
        Station,
        Network,
        Path,
        EdgeInPath,
        Parking,
        PersonalVehicle,
        ParkingBill,
        PublicVehicle,
        StationPath,
        Trip,
        TraversedPath,
        TripBill,
    ])
    
    print('done')


def second_query():
    table_name = input('enter table name: ')
    if table_name == 'Citizen':
        first_name = input('first name: ')
        first_name = None if first_name == 'null' else first_name
        last_name = input('last name: ')
        last_name = None if last_name == 'null' else last_name
        gender = input('gender: ')
        gender = None if gender == 'null' else gender
        national_id = input('national id: ')
        dob = input('date of birth in yyyy-mm-dd format: ')
        dob = None if dob == 'null' else dob
        headman = input('headman national id: ')
        headman = None if headman == 'null' else headman
        citizen = Citizen(first_name=first_name, last_name=last_name, gender=gender, national_id=national_id, date_of_birth=dob, headman=headman)
        try:
            if citizen.save(force_insert=True) == 1:
                print('successful')
            else:
                print('create new citizen failed')
        except Exception as e:
            print('something went wrong')
    elif table_name == 'PublicVehicle':
        vehicle_id = input('vehicle_id: ')
        driver = input('driver: ')
        driver = None if driver == 'null' else driver
        network = input('network: ')
        network = None if network == 'null' else network
        color = input('color: ')
        color = None if color == 'null' else color
        brand = input('brand: ')
        brand = None if brand == 'null' else brand

        public_vehicle = PublicVehicle(vehicle_id=vehicle_id, driver=driver, network=network, color=color, brand=brand)
        try:
            if public_vehicle.save(force_insert=True) == 1:
                print('successful')
            else:
                print('failed')
        except Exception as e:
            print('something went wrong')
    elif table_name == 'Station':
        name = input('name: ')
        name = None if name == 'null' else name
        location = input('location in format (x,y): ')
        location = None if location == 'null' else location
        station = Station(name=name, location=location)
        try:
            if station.save(force_insert=True) == 1:
                print('successful')
            else:
                print('failed')
        except Exception as e:
            print('something went wrong')
    elif table_name == 'Parking':
        parking_id = input('parking_id: ')
        opening_time = input('opening_time in format hh:mm:ss: ')
        opening_time = None if opening_time == 'null' else opening_time
        name = input('name: ')
        name = None if name == 'null' else name
        location = input('location in format (x,y): ')
        location = None if location == 'null' else location
        cost_per_hour = input('cost per hour: ')
        cost_per_hour = None if cost_per_hour == '0' else cost_per_hour
        closing_time = input('closing_time in format hh:mm:ss: ')
        closing_time = None if closing_time == 'null' else closing_time
        capacity = input('capacity: ')
        capacity = None if capacity == '0' else capacity
        parking = Parking(parking_id=parking_id, opening_time=opening_time, name=name, location=location, cost_per_hour=int(cost_per_hour), closing_time=closing_time, capacity=int(capacity))
        try:
            if parking.save(force_insert=True) == 1:
                print('successful')
            else:
                print('failed')
        except Exception as e:
            print('something went wrong')
    else:
        print('invalid input!')


def third_query():
    delete = input('delete or update: ') == 'delete'
    table_name = input('enter table name: ')
    if table_name == 'Citizen':
        national_id = input('national id: ')
        try:
            citizen = Citizen.get(Citizen.national_id == national_id)
            if not delete:
                field = input('enter field name: ')
                if field == 'first_name':
                    first_name = input('first_name: ')
                    first_name = None if first_name == 'null' else first_name
                    citizen.first_name = first_name
                    citizen.save()
                elif field == 'last_name':
                    last_name = input('last_name: ')
                    last_name = None if last_name == 'null' else last_name
                    citizen.last_name = last_name
                    citizen.save()
                elif field == 'gender':
                    gender = input('gender: ')
                    gender = None if gender == 'null' else gender
                    citizen.gender = gender
                    citizen.save()
                elif field == 'date_of_birth':
                    date_of_birth = input('date_of_birth name: ')
                    date_of_birth = None if date_of_birth == 'null' else date_of_birth
                    citizen.date_of_birth = date_of_birth
                    citizen.save()
                elif field == 'headman':
                    headman = input('headman: ')
                    headman = None if headman == 'null' else headman
                    citizen.headman = headman
                    citizen.save()
                else:
                    print('invalid input!')
                return

        except Exception as e:
            print('citizen with national id', national_id, 'did not found')
            return
        try:
            citizen.delete_instance()
        except Exception as e:
            print('citizen is head man of a family')
            if input('do you want to delete them too?') == 'yes':
                citizen.delete_instance(recursive=True)
            return
        print('successful')
    elif table_name == 'PublicVehicle':
        vehicle_id = input('vehicle id: ')
        try:
            vehicle = PublicVehicle.get(PublicVehicle.vehicle_id == vehicle_id)
            if not delete:
                field = input('enter field name: ')
                if field == 'driver':
                    driver = input('driver: ')
                    driver = None if driver == 'null' else driver
                    vehicle.driver = driver
                    vehicle.save()
                elif field == 'network':
                    network = input('network: ')
                    network = None if network == 'null' else network
                    vehicle.network = network
                    vehicle.save()
                elif field == 'color':
                    color = input('color: ')
                    color = None if color == 'null' else color
                    vehicle.color = color
                    vehicle.save()
                elif field == 'brand':
                    brand = input('brand: ')
                    brand = None if brand == 'null' else brand
                    vehicle.brand = brand
                    vehicle.save()
                else:
                    print('invalid input!')
                return
        except Exception as e:
            print('public vehicle with vehicle id', vehicle_id, 'did not found')
            print(e)
            return
        try:
            vehicle.delete_instance()
        except Exception as e:
            print('has references')
            if input('do you want to delete them too?') == 'yes':
                vehicle.delete_instance(recursive=True)
            return
        print('successful')
    elif table_name == 'Station':
        station_id = input('station id: ')
        try:
            station = Station.get(Station.station_id == station_id)
            if not delete:
                field = input('enter field name: ')
                if field == 'name':
                    name = input('name: ')
                    name = None if name == 'null' else name
                    station.name = name
                    station.save()
                elif field == 'location':
                    location = input('location in format (x,y): ')
                    location = None if location == 'null' else location
                    station.location = location
                    station.save()
                else:
                    print('invalid input!')
                return
        except Exception as e:
            print('Station with station id', station_id, 'did not found')
            return
        try:
            station.delete_instance()
        except Exception as e:
            print('has references')
            if input('do you want to delete them too?') == 'yes':
                station.delete_instance(recursive=True)
            return
        print('successful')
    elif table_name == 'Parking':
        parking_id = input('Parking id: ')
        try:
            parking = Parking.get(Parking.parking_id == parking_id)
            if not delete:
                field = input('enter field name: ')
                if field == 'opening_time':
                    opening_time = input('opening_time in format hh:mm:ss: ')
                    opening_time = None if opening_time == 'null' else opening_time
                    parking.opening_time = opening_time
                    parking.save()
                elif field == 'name':
                    name = input('name: ')
                    name = None if name == 'null' else name
                    parking.name = name
                    parking.save()
                elif field == 'location':
                    location = input('location in format (x,y): ')
                    location = None if location == 'null' else location
                    parking.location = location
                    parking.save()
                elif field == 'cost_per_hour':
                    cost_per_hour = input('cost per hour: ')
                    cost_per_hour = None if cost_per_hour == '0' else cost_per_hour
                    parking.cost_per_hour = cost_per_hour
                    parking.save()
                elif field == 'closing_time':
                    closing_time = input('closing_time in format hh:mm:ss: ')
                    closing_time = None if closing_time == 'null' else closing_time
                    parking.closing_time = closing_time
                    parking.save()
                elif field == 'capacity':
                    capacity = input('capacity: ')
                    capacity = None if capacity == '0' else capacity
                    parking.capacity = capacity
                    parking.save()
                else:
                    print('invalid input!')
                return
        except Exception as e:
            print('Parking with Parking id', parking_id, 'did not found')
            return
        try:
            parking.delete_instance()
        except Exception as e:
            print('has references')
            if input('do you want to delete them too?') == 'yes':
                parking.delete_instance(recursive=True)
            return
        print('successful')
    else:
        print('invalid table')
        
        
def forth_query():
    table_name = input('enter table name: ')
    if table_name == 'Citizen':
        national_id = input('national id: ')
        try:
            citizen = Citizen.get(Citizen.national_id == national_id)
            print(citizen.__dict__['__data__'])
        except Exception as e:
            print('citizen with national id', national_id, 'did not found')
            return
    elif table_name == 'PublicVehicle':
        vehicle_id = input('vehicle id: ')
        try:
            vehicle = PublicVehicle.get(PublicVehicle.vehicle_id == vehicle_id)
            print(vehicle.__dict__['__data__'])
        except Exception as e:
            print('public vehicle with vehicle id', vehicle_id, 'did not found')
            return
    elif table_name == 'Station':
        station_id = input('station id: ')
        try:
            station = Station.get(Station.station_id == station_id)
            print(station.__dict__['__data__'])
        except Exception as e:
            print('Station with station id', station_id, 'did not found')
            return
    elif table_name == 'Parking':
        parking_id = input('Parking id: ')
        try:
            parking = Parking.get(Parking.parking_id == parking_id)
            print(parking.__dict__['__data__'])
        except Exception as e:
            print('Parking with Parking id', parking_id, 'did not found')
            return
    else:
        print('invalid table')


def fifth_query():
    
    target_first_name = input('First Name: ')
    target_last_name = input('Last Name: ')

    matching_citizens = Citizen.select().where(
        (Citizen.first_name == target_first_name) &
        (Citizen.last_name == target_last_name)
    )
    print(matching_citizens)
    return matching_citizens


def sixth_query():

    citizen_national_id = input('Owner National ID: ')
    increase_amount = input('Amount to be charged: ')

    query = Account.update(balance = Account.balance + increase_amount).where(
        Account.owner == citizen_national_id
    )

    rows_updated = query.execute()

    if rows_updated > 0:
        print(f"Balance increased by {increase_amount} for citizen with national_id {citizen_national_id}")
    else:
        print(f"Citizen with national_id {citizen_national_id} not found")



def seventh_query():
    
    print('Enter the required information to create a new trip:')
    start_time = input('start time: ')
    end_time = input('end time: ')
    total_distance = input('total distance: ')
    vehicle_id = input('vehicle id: ')
    new_trip_data = {
        'start_time': start_time,
        'end_time': end_time,
        'total_distance': total_distance,
        'vehicle_id': vehicle_id
    }
    
    print('Enter the required information to create a new trip bill:')
    bill_id = input('bill id: ')
    issue_date = input('issue date: ')
    price = input('price: ')
    to_account = input('National ID of citizen: ')
    new_trip_bill_data = {
        'bill_id': bill_id,
        'issue_date': issue_date,
        'price': price,
        'to_account': to_account
    }
    
    with database.atomic():
        new_trip = Trip.create(**new_trip_data)
        new_trip_bill_data['trip_id'] = new_trip.trip_id
        new_trip_bill = TripBill.create(**new_trip_bill_data)

        update_balance = Account.update(balance = Account.balance - new_trip_bill.price).where(
            Account.owner == new_trip_bill.to_account
        )
        updated_balance = update_balance.execute()
        if updated_balance > 0:
            print(f"Balance decreased by {price} for citizen with national_id {to_account}")
        else:
            print('An error occurred')



def eighth_query():
    print('Enter the required information to create a new parking bill:')
    bill_id = input('bill id: ')
    issue_date = input('issue date: ')
    start_time = input('start time: ')
    end_time = input('end time: ')
    price = input('price: ')
    to_account = input('National ID of citizen: ')
    vehicle_id = input('vehicle id: ')
    parking_id = input('parking id: ')

    new_parking_bill_data = {
        'bill_id': bill_id,
        'issue_date': issue_date,
        'start_time': start_time,
        'end_time': end_time,
        'price': price,
        'to_account': to_account,
        'vehicle_id': vehicle_id,
        'parking_id': parking_id
    }


    with database.atomic():
        new_parking_bill = ParkingBill.create(**new_parking_bill_data)
        update_balance = Account.update(balance = Account.balance - new_parking_bill.price).where(
            Account.owner == new_parking_bill.to_account
        )
        updated_balance = update_balance.execute()
        if updated_balance > 0:
            print(f"Balance decreased by {price} for citizen with national_id {to_account}")
        else:
            print('An error occurred')



def ninth_query():
    print('Welcome to the bills section, enter a binary number between 000 and 111, each digit representing a specific type of bill')
    print('First digit: Trip Bill')
    print('Second digit: Parking Bill')
    print('Third digit: House Bill')
    types = input('Enter your binary choice for type of bills: ')
    start_date = input('Enter the date you want bills to be after it: ')
    end_date = input('Enter the date you want bills to be before it: ')
    to_account = input('Enter National ID of citizen: ')
    returned_object = (None, None, None)
    # retrieve trip bills
    if types[0] == '1':
        matching_trip_bills = TripBill.select().where(
            (TripBill.issue_date >= start_date) &
            (TripBill.issue_date <= end_date) &
            (TripBill.to_account == to_account)
        )
        returned_object[0] = matching_trip_bills
        print('Trip Bills:')
        print(matching_trip_bills)
    # retrieve parking bills
    if types[1] == '1':
        matching_parking_bills = ParkingBill.select().where(
            (ParkingBill.issue_date >= start_date) &
            (ParkingBill.issue_date <= end_date) &
            (ParkingBill.to_account == to_account)
        )
        returned_object[1] = matching_parking_bills
        print('Parking Bills:')
        print(matching_parking_bills)
    # retrieve house bills
    if types[2] == '1':
        matching_house_bills = HouseBill.select().where(
            (HouseBill.issue_date >= start_date) &
            (HouseBill.issue_date <= end_date) &
            (HouseBill.to_account == to_account)
        )
        returned_object[2] = matching_house_bills
        print('House Bills:')
        print(matching_house_bills)

    return returned_object



def tenth_query():
    start_date = input('Set the start date range: ')
    end_date = input('Set the end date range: ')
    total_price_range_start = input('Set the start price range: ')
    total_price_range_end = input('Set the end price range: ')
    matching_citizens = (Citizen
         .select(Citizen, fn.SUM(fn.COALESCE(ParkingBill.price, 0) + fn.COALESCE(TripBill.price, 0) + fn.COALESCE(HouseBill.price, 0)).alias('total_spent'))
         .join(Account)
         .join(ParkingBill, JOIN.LEFT_OUTER)
         .join(TripBill, JOIN.LEFT_OUTER)
         .join(HouseBill, JOIN.LEFT_OUTER)
         .where(
             ((ParkingBill.issue_date.between(start_date, end_date) | ParkingBill.issue_date.is_null()) &
              (TripBill.issue_date.between(start_date, end_date) | TripBill.issue_date.is_null()) & 
              (HouseBill.issue_date.between(start_date, end_date) | HouseBill.issue_date.is_null())) &
             ((ParkingBill.to_account == Citizen.national_id) &
              (TripBill.to_account == Citizen.national_id) &
              (HouseBill.to_account == Citizen.national_id))
         )
         .group_by(Citizen.national_id)
         .having(
             (fn.SUM(fn.COALESCE(ParkingBill.price, 0) + fn.COALESCE(TripBill.price, 0) + fn.COALESCE(HouseBill.price, 0)) >= total_price_range_start) &
             (fn.SUM(fn.COALESCE(ParkingBill.price, 0) + fn.COALESCE(TripBill.price, 0) + fn.COALESCE(HouseBill.price, 0)) <= total_price_range_end)
         ))
    print(matching_citizens)
    return matching_citizens

##########################  main program  ##########################


try:
    print('connection is ok:',database.connect())
except Exception  as e :
    
    print('error in connection to database. maybe database doesnt exist?')
    print(e)
    exit(1)


options = {
    1 : create_tables,
    2 : second_query,
    3 : third_query,
    4 : forth_query,
    5 : fifth_query,
    6 : sixth_query,
    7 : seventh_query,
    8 : eighth_query,
    9: ninth_query,
    10: tenth_query,
}

while True:
    try:
        inp = int(input('enter a number between 1 to 10 for your query:'))
        options[inp]()
    except Exception as e:
        
        print('probably invalid input')
        raise e # comment it latter for usage
        
    