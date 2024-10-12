--
-- PostgreSQL database dump
--

-- Dumped from database version 16.1
-- Dumped by pg_dump version 16.0

-- Started on 2023-12-18 07:39:32

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 233 (class 1259 OID 17242)
-- Name: edge_in_path; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.edge_in_path (
    path_id character varying(15) NOT NULL,
    start_station integer NOT NULL,
    end_station integer NOT NULL,
    estimated_time_minute integer,
    distance_km integer
);


ALTER TABLE public.edge_in_path OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 17189)
-- Name: public_vehicle; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.public_vehicle (
    vehicle_id character varying(31) NOT NULL,
    driver character varying(10) NOT NULL,
    network character varying(15) NOT NULL,
    brand character varying(31),
    color character varying(15)
);


ALTER TABLE public.public_vehicle OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 17279)
-- Name: traversed_path; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.traversed_path (
    trip_id integer NOT NULL,
    path_id character varying(15) NOT NULL,
    start_station integer NOT NULL,
    end_station integer NOT NULL,
    entrance_time timestamp without time zone
);


ALTER TABLE public.traversed_path OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 17265)
-- Name: trip; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trip (
    trip_id integer NOT NULL,
    vehicle_id character varying(31) NOT NULL,
    start_time timestamp without time zone,
    end_time timestamp without time zone,
    total_distance integer
);


ALTER TABLE public.trip OWNER TO postgres;

--
-- TOC entry 246 (class 1255 OID 17334)
-- Name: distance_of_driver(character varying, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.distance_of_driver(driver_id character varying, start_time timestamp without time zone, end_time timestamp without time zone) RETURNS integer
    LANGUAGE sql
    RETURN (SELECT sum(edge_in_path.distance_km) AS sum FROM (public.edge_in_path JOIN (SELECT DISTINCT traversed_path.path_id, traversed_path.start_station, traversed_path.end_station, traversed_path.entrance_time FROM (public.traversed_path JOIN (SELECT trip.trip_id FROM public.trip WHERE ((trip.vehicle_id)::text = ((SELECT public_vehicle.vehicle_id FROM public.public_vehicle WHERE ((public_vehicle.driver)::text = (distance_of_driver.driver_id)::text)))::text)) unnamed_subquery_1 USING (trip_id)) WHERE ((traversed_path.entrance_time >= distance_of_driver.start_time) AND (traversed_path.entrance_time <= distance_of_driver.end_time))) unnamed_subquery USING (path_id, start_station, end_station)));


ALTER FUNCTION public.distance_of_driver(driver_id character varying, start_time timestamp without time zone, end_time timestamp without time zone) OWNER TO postgres;

--
-- TOC entry 251 (class 1255 OID 17366)
-- Name: issue_parking_bill(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.issue_parking_bill() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 IF OLD.end_time IS NULL AND NEW.end_time IS NOT NULL THEN
    NEW.issue_date := current_date::date;
	NEW.price := (EXTRACT(EPOCH FROM (new.end_time - new.start_time)) / 3600) * (
		select cost_per_hour from parking where parking.parking_id = new.parking_id
	);
	IF (select balance from account where account.owner=new.to_account)<new.price THEN
		new.to_account := (select owner from personal_vehicle where personal_vehicle.vehicle_id=new.vehicle_id);
	END IF;
	UPDATE account SET balance = balance - NEW.price WHERE account.owner=new.to_account ;
	
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.issue_parking_bill() OWNER TO postgres;

--
-- TOC entry 252 (class 1255 OID 17368)
-- Name: issue_trip_bill(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.issue_trip_bill() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	cost INTEGER := new.total_distance * (
		select cost_per_km from network 
		where network.type=(select network from public_vehicle where public_vehicle.vehicle_id=new.vehicle_id));
BEGIN
 IF OLD.end_time IS NULL AND NEW.end_time IS NOT NULL THEN
    UPDATE trip_bill SET 
	issue_date=current_date::date, 
	price=cost
	WHERE account.owner=new.to_account;
	
	UPDATE account SET balance = balance - cost WHERE account.owner in (select to_account from trip_bill where trip_id=new.trip_id);
		
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.issue_trip_bill() OWNER TO postgres;

--
-- TOC entry 247 (class 1255 OID 17356)
-- Name: validate_opening_time_before_closing_time(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_opening_time_before_closing_time() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.opening_time > NEW.closing_time THEN
    RAISE EXCEPTION 'Start must be before End';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.validate_opening_time_before_closing_time() OWNER TO postgres;

--
-- TOC entry 250 (class 1255 OID 17363)
-- Name: validate_parking_bill_negetive_balance(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_parking_bill_negetive_balance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF (select sum(balance) from account where owner=NEW.to_account)<=0 THEN
    RAISE EXCEPTION 'balance must be positive';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.validate_parking_bill_negetive_balance() OWNER TO postgres;

--
-- TOC entry 249 (class 1255 OID 17360)
-- Name: validate_start_date_before_finish_date(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_start_date_before_finish_date() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.start_date > NEW.finish_date THEN
    RAISE EXCEPTION 'Start must be before End';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.validate_start_date_before_finish_date() OWNER TO postgres;

--
-- TOC entry 248 (class 1255 OID 17358)
-- Name: validate_start_time_before_end_time(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_start_time_before_end_time() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.start_time > NEW.end_time THEN
    RAISE EXCEPTION 'Start must be before End';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.validate_start_time_before_end_time() OWNER TO postgres;

--
-- TOC entry 253 (class 1255 OID 17370)
-- Name: withdraw_for_house(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.withdraw_for_house() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

BEGIN
	
	 IF TG_OP = 'INSERT' THEN
  
        IF NEW.price IS NOT NULL THEN
            UPDATE account SET balance = balance - new.price WHERE account.owner = new.to_account;
        END IF;

    ELSIF TG_OP = 'UPDATE' THEN
	
  		IF  OLD.price IS NULL AND NEW.price IS NOT NULL THEN
  
			UPDATE account SET balance = balance - new.price WHERE account.owner = new.to_account;
		
 		END IF;
	END IF;
	
	
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.withdraw_for_house() OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 17089)
-- Name: account; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.account (
    owner character varying(10) NOT NULL,
    balance integer
);


ALTER TABLE public.account OWNER TO postgres;

--
-- TOC entry 215 (class 1259 OID 17076)
-- Name: citizen; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.citizen (
    national_id character varying(10) NOT NULL,
    gender character varying(10),
    date_of_birth date,
    first_name character varying(255),
    last_name character varying(255),
    headman character varying(10) NOT NULL,
    CONSTRAINT citizen_gender_check CHECK (((gender)::text = ANY ((ARRAY['male'::character varying, 'female'::character varying])::text[])))
);


ALTER TABLE public.citizen OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 17133)
-- Name: daily_usage; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.daily_usage (
    house_id character varying(31) NOT NULL,
    request_type character varying(10) NOT NULL,
    request_date date NOT NULL,
    usage_date date NOT NULL,
    total_usage integer,
    bill_id character varying(31),
    CONSTRAINT daily_usage_request_type_check CHECK (((request_type)::text = ANY ((ARRAY['water'::character varying, 'power'::character varying, 'gas'::character varying])::text[])))
);


ALTER TABLE public.daily_usage OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 17241)
-- Name: edge_in_path_end_station_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.edge_in_path_end_station_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.edge_in_path_end_station_seq OWNER TO postgres;

--
-- TOC entry 5001 (class 0 OID 0)
-- Dependencies: 232
-- Name: edge_in_path_end_station_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.edge_in_path_end_station_seq OWNED BY public.edge_in_path.end_station;


--
-- TOC entry 231 (class 1259 OID 17240)
-- Name: edge_in_path_start_station_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.edge_in_path_start_station_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.edge_in_path_start_station_seq OWNER TO postgres;

--
-- TOC entry 5002 (class 0 OID 0)
-- Dependencies: 231
-- Name: edge_in_path_start_station_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.edge_in_path_start_station_seq OWNED BY public.edge_in_path.start_station;


--
-- TOC entry 217 (class 1259 OID 17099)
-- Name: house; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.house (
    house_id character varying(31) NOT NULL,
    owner character varying(10),
    street character varying(31),
    alley character varying(31),
    postal_code character varying(12),
    location point
);


ALTER TABLE public.house OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 17123)
-- Name: house_bill; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.house_bill (
    bill_id character varying(31) NOT NULL,
    to_account character varying(10) NOT NULL,
    issue_date date,
    price integer,
    start_date date,
    finish_date date
);


ALTER TABLE public.house_bill OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 17111)
-- Name: house_service_request; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.house_service_request (
    house_id character varying(31) NOT NULL,
    request_type character varying(10) NOT NULL,
    request_date date NOT NULL,
    price_per_unit integer,
    accepted boolean DEFAULT false,
    CONSTRAINT house_service_request_request_type_check CHECK (((request_type)::text = ANY ((ARRAY['water'::character varying, 'power'::character varying, 'gas'::character varying])::text[])))
);


ALTER TABLE public.house_service_request OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 17184)
-- Name: network; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.network (
    type character varying(15) NOT NULL,
    cost_per_km integer
);


ALTER TABLE public.network OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 17159)
-- Name: parking; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.parking (
    parking_id character varying(31) NOT NULL,
    opening_time time without time zone,
    closing_time time without time zone,
    name character varying(31),
    location point,
    capacity integer,
    cost_per_hour integer
);


ALTER TABLE public.parking OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 17164)
-- Name: parking_bill; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.parking_bill (
    bill_id character varying(31) NOT NULL,
    vehicle_id character varying(31) NOT NULL,
    parking_id character varying(31) NOT NULL,
    to_account character varying(10) NOT NULL,
    issue_date date,
    price integer,
    start_time timestamp without time zone,
    end_time timestamp without time zone
);


ALTER TABLE public.parking_bill OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 17206)
-- Name: path; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.path (
    path_id character varying(15) NOT NULL,
    type character varying(15) NOT NULL,
    name character varying(31)
);


ALTER TABLE public.path OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 17149)
-- Name: personal_vehicle; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.personal_vehicle (
    vehicle_id character varying(31) NOT NULL,
    owner character varying(10) NOT NULL,
    brand character varying(31),
    color character varying(15)
);


ALTER TABLE public.personal_vehicle OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 17217)
-- Name: station; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.station (
    station_id integer NOT NULL,
    location point,
    name character varying(31)
);


ALTER TABLE public.station OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 17224)
-- Name: station_path; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.station_path (
    path_id character varying(15) NOT NULL,
    station_id integer NOT NULL
);


ALTER TABLE public.station_path OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 17223)
-- Name: station_path_station_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.station_path_station_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.station_path_station_id_seq OWNER TO postgres;

--
-- TOC entry 5003 (class 0 OID 0)
-- Dependencies: 229
-- Name: station_path_station_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.station_path_station_id_seq OWNED BY public.station_path.station_id;


--
-- TOC entry 227 (class 1259 OID 17216)
-- Name: station_station_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.station_station_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.station_station_id_seq OWNER TO postgres;

--
-- TOC entry 5004 (class 0 OID 0)
-- Dependencies: 227
-- Name: station_station_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.station_station_id_seq OWNED BY public.station.station_id;


--
-- TOC entry 238 (class 1259 OID 17278)
-- Name: traversed_path_end_station_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.traversed_path_end_station_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.traversed_path_end_station_seq OWNER TO postgres;

--
-- TOC entry 5005 (class 0 OID 0)
-- Dependencies: 238
-- Name: traversed_path_end_station_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.traversed_path_end_station_seq OWNED BY public.traversed_path.end_station;


--
-- TOC entry 237 (class 1259 OID 17277)
-- Name: traversed_path_start_station_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.traversed_path_start_station_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.traversed_path_start_station_seq OWNER TO postgres;

--
-- TOC entry 5006 (class 0 OID 0)
-- Dependencies: 237
-- Name: traversed_path_start_station_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.traversed_path_start_station_seq OWNED BY public.traversed_path.start_station;


--
-- TOC entry 236 (class 1259 OID 17276)
-- Name: traversed_path_trip_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.traversed_path_trip_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.traversed_path_trip_id_seq OWNER TO postgres;

--
-- TOC entry 5007 (class 0 OID 0)
-- Dependencies: 236
-- Name: traversed_path_trip_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.traversed_path_trip_id_seq OWNED BY public.traversed_path.trip_id;


--
-- TOC entry 241 (class 1259 OID 17308)
-- Name: trip_bill; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trip_bill (
    bill_id character varying(31) NOT NULL,
    trip_id integer NOT NULL,
    to_account character varying(10) NOT NULL,
    issue_date date,
    price integer
);


ALTER TABLE public.trip_bill OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 17307)
-- Name: trip_bill_trip_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.trip_bill_trip_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.trip_bill_trip_id_seq OWNER TO postgres;

--
-- TOC entry 5008 (class 0 OID 0)
-- Dependencies: 240
-- Name: trip_bill_trip_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.trip_bill_trip_id_seq OWNED BY public.trip_bill.trip_id;


--
-- TOC entry 234 (class 1259 OID 17264)
-- Name: trip_trip_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.trip_trip_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.trip_trip_id_seq OWNER TO postgres;

--
-- TOC entry 5009 (class 0 OID 0)
-- Dependencies: 234
-- Name: trip_trip_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.trip_trip_id_seq OWNED BY public.trip.trip_id;


--
-- TOC entry 242 (class 1259 OID 17336)
-- Name: v1; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v1 AS
 SELECT national_id,
    gender,
    date_of_birth,
    first_name,
    last_name,
    headman
   FROM public.citizen
  WHERE (((national_id)::text IN ( SELECT public_vehicle.driver
           FROM public.public_vehicle
          WHERE ((public_vehicle.network)::text = 'bus'::text))) AND ((30 * 123) < public.distance_of_driver(national_id, ((CURRENT_TIMESTAMP - '30 days'::interval))::timestamp without time zone, (CURRENT_TIMESTAMP)::timestamp without time zone)));


ALTER VIEW public.v1 OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 17341)
-- Name: v2; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v2 AS
 SELECT station.station_id,
    station.name,
    sum(unnamed_subquery.num_people) AS sum
   FROM (public.station
     LEFT JOIN ( SELECT count(*) AS num_people,
            traversed_path.end_station AS destination
           FROM ((public.trip_bill
             JOIN public.trip USING (trip_id))
             JOIN public.traversed_path USING (trip_id))
          WHERE (((trip.start_time > (CURRENT_TIMESTAMP - '24:00:00'::interval)) OR (trip.end_time > (CURRENT_TIMESTAMP - '24:00:00'::interval))) AND (traversed_path.entrance_time >= ALL ( SELECT tp.entrance_time
                   FROM public.traversed_path tp
                  WHERE (tp.trip_id = tp.trip_id))))
          GROUP BY trip_bill.trip_id, traversed_path.path_id, traversed_path.start_station, traversed_path.end_station
        UNION
         SELECT count(*) AS num_people,
            traversed_path.start_station AS destination
           FROM ((public.trip_bill
             JOIN public.trip USING (trip_id))
             JOIN public.traversed_path USING (trip_id))
          WHERE (((trip.start_time > (CURRENT_TIMESTAMP - '24:00:00'::interval)) OR (trip.end_time > (CURRENT_TIMESTAMP - '24:00:00'::interval))) AND (traversed_path.entrance_time <= ALL ( SELECT tp.entrance_time
                   FROM public.traversed_path tp
                  WHERE (tp.trip_id = tp.trip_id))))
          GROUP BY trip_bill.trip_id, traversed_path.path_id, traversed_path.start_station, traversed_path.end_station) unnamed_subquery ON ((station.station_id = unnamed_subquery.destination)))
  GROUP BY station.station_id, station.name;


ALTER VIEW public.v2 OWNER TO postgres;

--
-- TOC entry 244 (class 1259 OID 17346)
-- Name: v3; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v3 AS
 SELECT pv.vehicle_id,
    count(DISTINCT tb.to_account) AS count
   FROM ((public.public_vehicle pv
     JOIN public.trip t ON (((pv.vehicle_id)::text = (t.vehicle_id)::text)))
     JOIN public.trip_bill tb ON ((t.trip_id = tb.trip_id)))
  WHERE ((pv.network)::text = 'metro'::text)
  GROUP BY pv.vehicle_id;


ALTER VIEW public.v3 OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 17351)
-- Name: v4; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v4 AS
 SELECT h.house_id
   FROM (public.house h
     JOIN public.daily_usage du ON (((h.house_id)::text = (du.house_id)::text)))
  WHERE (((CURRENT_DATE - '30 days'::interval))::date <= du.usage_date)
  GROUP BY h.house_id
 HAVING (sum(du.total_usage) > 30);


ALTER VIEW public.v4 OWNER TO postgres;

--
-- TOC entry 4737 (class 2604 OID 17245)
-- Name: edge_in_path start_station; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.edge_in_path ALTER COLUMN start_station SET DEFAULT nextval('public.edge_in_path_start_station_seq'::regclass);


--
-- TOC entry 4738 (class 2604 OID 17246)
-- Name: edge_in_path end_station; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.edge_in_path ALTER COLUMN end_station SET DEFAULT nextval('public.edge_in_path_end_station_seq'::regclass);


--
-- TOC entry 4735 (class 2604 OID 17220)
-- Name: station station_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.station ALTER COLUMN station_id SET DEFAULT nextval('public.station_station_id_seq'::regclass);


--
-- TOC entry 4736 (class 2604 OID 17227)
-- Name: station_path station_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.station_path ALTER COLUMN station_id SET DEFAULT nextval('public.station_path_station_id_seq'::regclass);


--
-- TOC entry 4740 (class 2604 OID 17282)
-- Name: traversed_path trip_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.traversed_path ALTER COLUMN trip_id SET DEFAULT nextval('public.traversed_path_trip_id_seq'::regclass);


--
-- TOC entry 4741 (class 2604 OID 17283)
-- Name: traversed_path start_station; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.traversed_path ALTER COLUMN start_station SET DEFAULT nextval('public.traversed_path_start_station_seq'::regclass);


--
-- TOC entry 4742 (class 2604 OID 17284)
-- Name: traversed_path end_station; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.traversed_path ALTER COLUMN end_station SET DEFAULT nextval('public.traversed_path_end_station_seq'::regclass);


--
-- TOC entry 4739 (class 2604 OID 17268)
-- Name: trip trip_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trip ALTER COLUMN trip_id SET DEFAULT nextval('public.trip_trip_id_seq'::regclass);


--
-- TOC entry 4743 (class 2604 OID 17311)
-- Name: trip_bill trip_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trip_bill ALTER COLUMN trip_id SET DEFAULT nextval('public.trip_bill_trip_id_seq'::regclass);


--
-- TOC entry 4970 (class 0 OID 17089)
-- Dependencies: 216
-- Data for Name: account; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.account (owner, balance) FROM stdin;
1	955030
2	432581
3	479682
4	114922
5	245585
6	910892
7	591035
8	446676
9	40482
10	739105
11	438240
12	360434
13	477705
14	827142
15	178959
16	763137
17	467010
18	447030
19	606957
20	128482
21	562111
22	659306
23	820475
24	140915
25	178964
26	476211
27	227783
28	529081
29	8702
30	247490
31	985106
32	560034
33	920772
34	608689
35	370829
36	646484
37	630136
38	371933
39	966842
40	940265
41	187416
42	45650
43	668046
44	347628
45	36205
46	731617
47	714889
48	987014
49	714010
50	275132
51	880343
52	239670
53	42910
54	214434
55	540026
56	221401
57	540362
58	499353
59	831011
60	748491
61	405116
62	798296
63	444524
64	564159
65	544231
66	48722
67	434806
68	166137
69	531161
70	211248
71	128646
72	799018
73	836883
74	808833
75	393905
76	885429
77	853590
78	492286
79	479922
80	889774
81	677991
82	442404
83	515282
84	237313
85	320927
86	558692
87	511757
88	674304
89	745052
90	955430
91	149
92	173034
93	89952
94	682167
95	844205
96	396933
97	438403
98	197141
99	738277
100	59131
101	544042
102	162977
103	628423
104	740829
105	540960
106	883066
107	270772
108	803550
109	190537
110	562581
111	830599
112	602561
113	605763
114	692187
115	106528
116	956339
117	507634
118	383933
119	256731
120	927588
121	52230
122	755019
123	568563
124	294540
125	467970
126	982992
127	287844
128	611741
129	293864
130	215446
131	424222
132	59979
133	287564
134	324998
135	567950
136	364771
137	525649
138	734167
139	919661
140	188898
141	509670
142	568453
143	672410
144	394384
145	197239
146	139995
147	441050
148	939840
149	578519
150	596890
151	468038
152	781709
153	651069
154	573230
155	559237
156	927565
157	122834
158	985556
159	365309
160	599739
161	918360
162	687213
163	554655
164	729180
165	105865
166	323935
167	425773
168	126183
169	985372
170	782518
171	117608
172	819452
173	677926
174	640150
175	685094
176	720720
177	278348
178	569188
179	142943
180	562424
181	586907
182	179040
183	58313
184	315775
185	633644
186	236042
187	760101
188	777771
189	483238
190	457377
191	118292
192	587669
193	573301
194	410486
195	938295
196	566564
197	580463
198	77820
199	833556
200	219903
201	558193
202	691931
203	186512
204	144129
205	277869
206	400915
207	457041
208	143022
209	505667
210	820821
211	802248
212	675690
213	913813
214	90214
215	843873
216	394971
217	629763
218	239068
219	645747
220	70626
221	142361
222	341388
223	48951
224	333870
225	441021
226	294256
227	737514
228	412032
229	153553
230	111849
231	55386
232	772963
233	541104
234	277905
235	521064
236	435158
237	496435
238	167070
239	827041
240	856929
241	130125
242	107188
243	558599
244	374444
245	854855
246	751438
247	89273
248	380784
249	134812
250	526842
251	677608
252	638289
253	329465
254	161666
255	907744
256	528453
257	420958
258	459538
259	777863
260	977432
261	790100
262	199796
263	946599
264	92704
265	363902
266	179107
267	464380
268	944672
269	675828
270	269185
271	222020
272	824252
273	795905
274	995861
275	853143
276	190268
277	986011
278	237521
279	865159
280	608738
281	334565
282	468125
283	839108
284	814804
285	980004
286	51170
287	723063
288	470084
289	487416
290	300472
291	765102
292	324455
293	279176
294	793362
295	735167
296	242666
297	672616
298	511873
299	37448
300	248991
301	731881
302	355463
303	409534
304	156139
305	215431
306	625615
307	94934
308	685229
309	649377
310	526615
311	659710
312	605861
313	69062
314	507232
315	835620
316	912162
317	444174
318	231593
319	692447
320	79114
321	769874
322	215924
323	938997
324	900743
325	883607
326	838309
327	786245
328	241830
329	127669
330	156281
331	895185
332	985790
333	901233
334	817849
335	774964
336	89981
337	924275
338	736112
339	631245
340	177732
341	46289
342	598697
343	496353
344	27842
345	33937
346	863133
347	640295
348	964096
349	266142
350	57680
351	70955
352	262702
353	202387
354	694252
355	27906
356	338040
357	842009
358	612
359	443812
360	818852
361	810250
362	407201
363	681210
364	222639
365	943703
366	372364
367	121237
368	588412
369	563505
370	433687
371	287751
372	568979
373	541834
374	869959
375	353837
376	764124
377	486228
378	695617
379	439525
380	705218
381	721113
382	640161
383	94499
384	313960
385	744855
386	195441
387	819313
388	384090
389	250335
390	359168
391	648945
392	130115
393	584122
394	903990
395	991893
396	337413
397	789333
398	706329
399	263519
400	26574
401	14121
402	885216
403	856159
404	544517
405	424402
406	553794
407	217226
408	643155
409	856688
410	966459
411	795706
412	32522
413	101963
414	407425
415	484298
416	614382
417	479583
418	604782
419	765635
420	704080
421	508940
422	440413
423	334838
424	584570
425	115869
426	491933
427	674756
428	613476
429	239905
430	74319
431	162218
432	961413
433	908150
434	270248
435	806688
436	611529
437	147969
438	445283
439	340736
440	713079
441	760221
442	649047
443	46158
444	83837
445	407693
446	443661
447	721187
448	482123
449	164007
450	31852
451	418304
452	426852
453	59248
454	983713
455	240686
456	476659
457	850529
458	68705
459	613718
460	708678
461	70141
462	762473
463	913118
464	479226
465	988549
466	354921
467	757353
468	605080
469	226852
470	315311
471	545145
472	235287
473	24717
474	343390
475	163322
476	935988
477	980925
478	342768
479	91621
480	748838
481	568315
482	919267
483	687869
484	44273
485	228059
486	604131
487	203199
488	126484
489	100409
490	762156
491	591561
492	577892
493	840229
494	198321
495	775324
496	962473
497	884306
498	277906
499	88532
500	520024
501	321539
502	547779
503	597159
504	736944
505	335367
506	506591
507	281684
508	115522
509	601390
510	37484
511	474382
512	987498
513	985839
514	1417
515	742625
516	177920
517	43270
518	678182
519	973616
520	112915
521	490330
522	367097
523	365847
524	12742
525	827391
526	778627
527	809099
528	828425
529	542942
530	526842
531	906840
532	497488
533	839571
534	975143
535	703452
536	922936
537	636730
538	264451
539	933408
540	980052
541	902647
542	880567
543	229738
544	750884
545	604680
546	646908
547	479507
548	731214
549	207546
550	132437
551	696536
552	448739
553	230662
554	472811
555	487371
556	596730
557	127989
558	29977
559	34057
560	594521
561	888908
562	477278
563	553984
564	932791
565	667942
566	85968
567	686995
568	508936
569	203022
570	826538
571	124669
572	53324
573	986698
574	92179
575	643793
576	375236
577	709068
578	509640
579	43448
580	646654
581	236427
582	7903
583	310769
584	802450
585	11293
586	933317
587	928975
588	181692
589	883386
590	281623
591	529073
592	113813
593	95499
594	604928
595	170626
596	214436
597	645493
598	539890
599	860603
600	778361
601	852064
602	419384
603	475637
604	765411
605	451423
606	729734
607	786900
608	713433
609	356816
610	59254
611	943403
612	612499
613	37214
614	621256
615	239237
616	630150
617	158416
618	325420
619	800032
620	61319
621	702038
622	794135
623	814503
624	563105
625	309089
626	967732
627	754151
628	609206
629	882957
630	190534
631	173808
632	356249
633	708214
634	657483
635	80471
636	788003
637	249550
638	537905
639	664363
640	257002
641	182931
642	241922
643	982431
644	823952
645	714046
646	425070
647	962553
648	776907
649	571151
650	86248
651	313159
652	590940
653	69859
654	271853
655	370318
656	676695
657	312842
658	274422
659	301810
660	95652
661	59526
662	34795
663	826880
664	977450
665	500663
666	361172
667	546847
668	563166
669	139140
670	806751
671	660817
672	350748
673	345979
674	115237
675	668964
676	778984
677	72803
678	296974
679	657726
680	649005
681	376473
682	906699
683	536370
684	917994
685	597522
686	553778
687	101793
688	249694
689	969009
690	654579
691	731862
692	498055
693	363977
694	926612
695	308358
696	926158
697	678545
698	611189
699	651215
700	696090
701	214654
702	372678
703	673073
704	549433
705	145441
706	332562
707	198957
708	437705
709	851081
710	42957
711	550487
712	637081
713	86098
714	536497
715	154844
716	168131
717	407206
718	245658
719	353496
720	517850
721	362315
722	527922
723	269918
724	540920
725	377482
726	198071
727	115895
728	674062
729	661163
730	731931
731	376721
732	995342
733	335359
734	149669
735	496075
736	740551
737	522486
738	593958
739	421902
740	457380
741	129466
742	503177
743	555710
744	788207
745	805491
746	138223
747	313942
748	150874
749	984355
750	251740
751	611723
752	298530
753	770059
754	677001
755	563269
756	833761
757	16436
758	338365
759	373702
760	568147
761	906297
762	918023
763	50878
764	3237
765	678118
766	672194
767	971779
768	952412
769	848371
770	831236
771	43910
772	698845
773	739106
774	445613
775	306138
776	881750
777	820642
778	710893
779	939577
780	364119
781	743968
782	560297
783	636372
784	13282
785	871350
786	15117
787	157217
788	113185
789	983281
790	232314
791	715052
792	59517
793	286979
794	146319
795	80226
796	315396
797	178892
798	521837
799	392352
800	585800
801	686533
802	879016
803	580718
804	212770
805	468371
806	179441
807	337793
808	410622
809	565857
810	733450
811	107970
812	380633
813	116187
814	594167
815	918994
816	250358
817	852994
818	462751
819	524584
820	885445
821	389441
822	929193
823	524529
824	567093
825	101804
826	253206
827	220699
828	102039
829	434808
830	303869
831	987833
832	910476
833	94621
834	121578
835	831305
836	838896
837	755345
838	65553
839	403271
840	380956
841	509305
842	462414
843	537638
844	254474
845	289718
846	160829
847	746686
848	848637
849	52854
850	531054
851	90483
852	418196
853	6410
854	226499
855	522294
856	937675
857	241345
858	323132
859	381981
860	109145
861	642063
862	658505
863	597219
864	30372
865	472188
866	12408
867	843518
868	717127
869	172860
870	900823
871	902184
872	434258
873	737165
874	270227
875	130833
876	470628
877	971811
878	236224
879	774872
880	990662
881	659810
882	858013
883	204874
884	165623
885	421676
886	212474
887	329636
888	31679
889	526840
890	465866
891	654632
892	599431
893	24833
894	857199
895	833680
896	815142
897	12521
898	790542
899	380643
900	6977
901	239818
902	510199
903	584483
904	219943
905	154216
906	629122
907	805875
908	845287
909	335026
910	416981
911	222395
912	52610
913	142567
914	189429
915	152005
916	731879
917	866541
918	909481
919	168839
920	208722
921	196855
922	168959
923	619090
924	212080
925	266678
926	446859
927	406328
928	867515
929	510628
930	774588
931	778979
932	386796
933	306629
934	181923
935	812220
936	888305
937	150351
938	314580
939	893448
940	71197
941	339018
942	577586
943	66262
944	590856
945	885082
946	661489
947	658956
948	361185
949	792721
950	356201
951	632202
952	754971
953	88179
954	66354
955	178853
956	963323
957	543288
958	694424
959	63376
960	42442
961	114945
962	468942
963	963908
964	561033
965	872341
966	628369
967	567320
968	55797
969	948838
970	291351
971	597419
972	928121
973	702761
974	439654
975	456370
976	592929
977	657583
978	887506
979	610696
980	607570
981	337943
982	764141
983	846250
984	331135
985	331372
986	69854
987	452537
988	646143
989	975616
990	433007
991	237657
992	389591
993	155575
994	577917
995	283854
996	769659
997	722764
998	785725
999	155217
1000	349073
\.


--
-- TOC entry 4969 (class 0 OID 17076)
-- Dependencies: 215
-- Data for Name: citizen; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.citizen (national_id, gender, date_of_birth, first_name, last_name, headman) FROM stdin;
1	female	1930-08-17	ddxnestze	kiyfwd	1
2	male	1997-07-17	uptwxo	onannsxwm	1
3	female	2020-08-12	qrnujp	elbsa	1
4	male	1921-08-06	bursrl	uyfjbha	3
5	male	1951-08-26	zjtgdiljn	kwsmar	2
6	female	2001-06-17	yewmyc	kmpfusi	1
7	female	1914-11-17	jzlqowr	xhymdw	3
8	female	1940-08-11	hckfq	cynjhu	8
9	male	1960-08-05	hoooquw	vvrcblyq	5
10	female	2019-08-03	ryomeual	ciqkdwznji	8
11	male	2003-03-08	juegonnykk	xbdgdxcinz	9
12	female	1953-05-02	wmeyfm	zcqkfg	2
13	female	1904-09-08	gdwyfu	wasjbof	8
14	male	1951-09-24	fofbqxuvuo	mhexw	12
15	female	1900-07-17	ivhhwrwr	toskyrxxwz	11
16	female	2009-08-19	hhpveiu	gwcql	10
17	male	1949-01-28	otffkxoc	zohmxmn	15
18	female	1924-12-18	pvcqwuqlea	cvzbuzqxoi	1
19	male	1972-08-04	mttti	vlbxz	10
20	male	2009-03-09	wzgvawmqx	ymkufk	6
21	male	1974-03-27	enowki	ftwsk	16
22	female	1932-02-03	uytxluzgf	shxpxgb	16
23	female	1911-12-24	gtimfetbnw	thgxfa	6
24	female	2002-03-17	rnjvaxwl	hounihn	15
25	female	1971-11-25	qmzajtfyhg	emcvxii	23
26	female	1954-08-24	mnvrk	bovhjjv	2
27	female	1903-11-08	faqkn	hefifxp	21
28	female	1954-08-10	mnjsnvizqa	xmeclsf	25
29	male	2013-09-08	bulchykjya	rufykkfp	26
30	female	1929-10-16	bshcbiqyw	vvmuiu	24
31	male	1913-08-02	epmlhgzusm	jvdpldsuve	20
32	male	1955-08-07	rocscfyu	bweklgrm	9
33	female	2014-11-08	tyznmcqvub	spcousz	25
34	male	1980-03-14	ctnonxgbpc	umoqis	27
35	female	1999-02-21	xgvvwp	bxlllyft	25
36	female	1902-10-03	fkdfktwbdn	snzefyo	11
37	female	1992-09-25	fnoqsgr	qgjhchqlcn	35
38	male	1946-03-09	evtvpna	tzzmda	24
39	female	1946-07-09	kvitziajq	jeurqfeyvt	30
40	female	1924-03-02	dzplqqe	sherknm	2
41	female	1927-09-12	evzmtfzuz	tbwqyejku	8
42	male	1989-05-14	htxkoctsmu	tgnsdqdaqd	30
43	female	2004-06-01	vqzigjwpmn	xzxexgdl	19
44	male	1921-04-02	pyccgjg	xdugtjg	7
45	male	1923-06-25	lrbdmtl	ztjdqsdyae	9
46	male	1998-11-02	xfinxlfhaz	pmilsbfu	36
47	female	2016-09-19	sokvylwi	fmwwwz	8
48	male	2015-10-21	ymuuctr	sqzpeovxd	28
49	male	1912-11-11	mvyzu	itzea	10
50	female	1954-06-16	csmjayrwo	ywkbm	10
51	female	1943-10-04	mejwpt	uzkpla	15
52	male	1935-06-13	sfnpvch	wkyrvicll	48
53	female	1978-09-23	proyuz	ebknfr	49
54	male	1969-12-27	atwjdlsz	syufh	24
55	male	1905-08-26	givfwskb	ipqbmc	53
56	male	1960-01-27	wxurfuxs	fntyfvou	36
57	male	1967-07-20	zetzhvpfdb	wttplbjhuj	23
58	female	1906-04-18	gdsxh	opuwwppyr	57
59	male	1918-04-09	xufneggbk	jaqkutks	39
60	male	1932-01-26	rfmhrr	knoutgragp	47
61	female	1927-11-18	mvzvgxgyu	mmanrbxl	14
62	male	1923-04-03	hkdvcge	tdqbbldpt	15
63	female	1995-02-18	qwilvrvtrw	jkrfqnx	58
64	male	2003-10-14	pmqaccehkk	icjyq	34
65	female	2001-04-27	yuait	ylsfpacggj	65
66	female	1991-01-24	nlthc	isgdxntb	14
67	female	1959-12-27	zmqnyx	hkimr	9
68	male	2008-02-11	sykvyj	asnpioswsn	6
69	female	1953-09-08	sbfvqcg	qiexja	52
70	female	1916-01-25	pmjojokjfo	civbccpa	64
71	female	1992-08-24	hkhwca	csxjzogrd	5
72	male	2012-06-15	lyvqyowxb	mxqylso	14
73	male	1902-01-09	dxuhuolwe	ngkip	19
74	female	2013-11-21	kpsgwmoyvn	nuxqhqfqa	49
75	female	1940-05-19	shqlfa	ynnmjy	48
76	female	2008-03-07	davxbiwt	fjjmy	45
77	male	1988-06-27	gvurmdo	lmvfva	74
78	female	1992-10-13	dxunbznsj	tjwogiprk	26
79	male	1967-04-14	sbaqoxlv	qbvebcfme	48
80	male	1911-01-16	qtjkeyo	upgkpnb	58
81	male	1972-07-18	jxngqse	ikesjlupa	50
82	female	1978-09-05	rmqrbnt	yurflbkdr	18
83	female	1956-04-14	fdglaqde	nwvpam	75
84	female	1996-02-22	jzmgurysvb	ojwgfnterr	26
85	female	1985-05-02	ghhlxdbq	fcmiees	14
86	female	1968-07-03	zonolvn	wzrjdunx	32
87	female	1909-05-03	vsjtk	axcojs	76
88	male	1908-06-06	ewakygbxaw	qffnjiq	58
89	female	1944-05-09	jfppzolsd	vmzvaq	14
90	male	1931-04-04	efmoks	oqvti	8
91	male	1936-12-18	wgegs	rnuwfntzgg	44
92	male	1954-10-20	twloqd	wvpfuf	47
93	male	1924-03-10	txorvsbjt	wsmvi	50
94	male	1908-09-17	kczdvtzb	hxcvl	8
95	female	1989-04-18	ffrctmy	xsllemvute	32
96	male	1982-10-10	pdqky	tcjkyxmnsg	58
97	male	1915-07-22	mylhpjh	ipczsrc	13
98	female	1928-07-13	ptkhgu	szsxanx	62
99	male	1988-09-24	qdgrqb	faosrt	51
100	male	1994-12-12	iufxmx	mngbh	96
101	male	1902-08-13	dkshbbviiy	zbwsjuv	30
102	female	2017-02-22	lucqbgkuf	xmghgjyk	93
103	female	1990-02-02	xcaeqp	cnjrudc	20
104	male	1909-06-27	ururml	yrtfcjgd	43
105	male	1927-12-05	ixftp	einkovoyzs	6
106	male	1983-12-18	zoipnandpw	wtsgxheqk	67
107	male	2003-09-04	cwrnqjyfl	ncxyipw	15
108	female	2009-08-25	ukygxphv	sitox	50
109	male	1961-07-01	mglxvyf	kiryxt	12
110	male	1935-04-23	vzhifzxf	qoqjkssd	23
111	male	1976-04-22	xmlvlhwpmg	ofzcvr	103
112	female	1911-09-18	tbijqowvod	fkufoa	69
113	female	1911-11-07	fsnkhzuq	snvyucqrv	64
114	female	2014-08-19	vrjjioduf	cfaho	87
115	female	1919-11-08	yghalv	jypfnjfkx	94
116	male	1921-02-27	kzzixeo	ducjlc	18
117	male	1925-12-23	awosjkg	lsuvqrvjy	27
118	male	1968-04-19	turjj	pkhsq	102
119	male	1986-06-28	edjjd	oviim	68
120	male	1949-12-01	daxecehn	bolhqiwbhi	74
121	female	1935-01-15	qksrej	zvnwk	111
122	male	1975-12-07	dzmeqwny	jgcwu	29
123	male	1977-11-28	fqcoj	miwadznlv	50
124	male	1915-08-23	fztzdzhuo	ahunbysax	43
125	female	1924-12-22	xfshzqqx	kztsocy	59
126	female	2003-10-01	chfrv	vifrii	81
127	male	1951-01-15	ievqc	cxojinbju	63
128	female	1941-05-15	boybty	izpnbpfx	46
129	male	2021-11-07	kvbtrpl	ruwzpwnlyf	52
130	female	2006-02-19	gfixmxwsb	pxwcxefczg	75
131	female	1929-09-02	wyzzuy	zzqeuxsi	10
132	male	1943-07-03	rlcbsm	bxniqme	73
133	male	1949-01-19	pztrirqmw	jijgv	52
134	female	1922-02-16	dmsfrnz	pdvukqy	52
135	female	1924-05-06	fvxiyvg	pcppiupcgl	4
136	female	1971-07-17	sxfznf	ztteciowfk	97
137	male	1936-05-28	zvbgutqfi	cgloqs	58
138	male	2016-08-26	tadgjzecem	cgsilbsf	59
139	male	1975-03-17	bmsqaydal	gevyl	100
140	male	2008-02-02	dwimy	htkxmancje	99
141	female	1930-03-24	sajsaq	hgdjo	107
142	male	1931-04-06	tjqoiq	aemwahrg	54
143	female	2014-08-01	npoyojbvad	xxotdacdsx	20
144	male	1955-04-25	oqiatm	kpilrsy	90
145	female	2006-08-13	ssjgjpbkob	ykvdg	94
146	male	1979-03-13	uhignaoq	gewvszcdn	79
147	female	1975-03-19	ixbxbxwc	jnwubopt	52
148	female	1996-11-16	lfydw	axfvoqhm	90
149	female	1921-07-19	qujtzffd	tgvebt	26
150	female	1945-11-21	uvxtczx	zardt	117
151	male	1971-10-08	rtkbwodahe	geuvm	90
152	female	2019-10-02	sfnqy	jdwdcoil	9
153	male	1978-11-19	vmglqzzg	amuxoqhcd	119
154	male	1951-05-09	trftpwh	bugucveyxf	48
155	male	2017-06-24	gilvzghh	wscva	122
156	female	2008-06-19	myrhfmxq	essaybwsv	86
157	female	1910-11-27	ivjnsiiypc	uuhxeeky	1
158	male	1935-09-25	eqmacebj	tnppmwr	16
159	male	1973-11-14	febubeas	vvelmhpd	125
160	female	2001-05-20	xcsuhe	qfaaejvh	79
161	male	1940-11-21	ddxmsnwyxu	ecekreh	78
162	female	1924-05-26	gfomlnovq	krbsmvpev	149
163	female	1977-01-01	gnfoceh	abnsf	146
164	female	2009-04-20	rnxsm	mnatmcsfn	113
165	female	1977-11-27	shnuejieh	yemmkkogt	57
166	female	1942-11-04	arlbbnfcwc	rhkqi	87
167	male	1959-04-19	dgnjwzsmrw	gnziesoizq	88
168	male	1911-05-02	bryvpkn	mxsgplef	38
169	male	2000-07-21	zssjop	yofbsvgw	129
170	female	1978-03-15	wdewmxeh	tmvctywd	85
171	female	2000-05-12	rbydkygzyk	pdggx	138
172	female	1976-07-13	mbpbsqouce	zdmvm	172
173	female	1942-12-22	dbtpzljekf	ixsgzeeb	50
174	male	1994-03-22	woxvgs	mdlglp	49
175	female	1903-01-16	mwgvscps	mppsa	172
176	female	1982-12-05	bwpuyxfrl	ybevzd	57
177	male	1972-05-24	pwzcibfn	xnwjwufz	89
178	female	1905-09-01	eizseic	csfxjzbfki	32
179	female	1954-11-18	jwjqzc	dhvnjbf	25
180	male	1989-05-09	usvlcwqixy	bnhyqvc	1
181	male	2015-09-17	jrikdjor	pwiwnwkz	95
182	male	1913-10-15	luwxmskvyo	pimdsarxu	141
183	female	1904-08-12	tycbcjz	mazzphk	59
184	male	1950-09-02	vjqzytdi	wfjbz	58
185	male	1962-09-08	gucvspw	fgptb	74
186	male	1971-03-11	vaduasrm	fojfizcytu	79
187	male	1995-10-10	qgggy	kfxfymxnk	136
188	male	1959-03-09	ovslg	yeujwrjde	162
189	female	1901-01-19	byntjmcv	vaawbf	6
190	male	1949-06-10	latxe	czrvbxw	148
191	female	1938-09-15	hnotg	hlljqpnnzk	87
192	female	1944-03-04	drcmkdayp	ktexfss	60
193	male	1934-02-21	fsyqg	ppnewtcvxw	118
194	female	1941-04-11	oeyqtvaukl	cxqcelhrhr	149
195	female	1998-03-21	dcnnnli	rcxqqfdu	139
196	female	1965-04-05	jdtwvgzktu	csivu	79
197	female	1960-10-15	ccspbbjn	oeyhqphumq	142
198	male	1904-10-15	qwnrdqqozn	fpecyjou	193
199	female	2020-04-05	prgnnzh	rrbrrytbq	76
200	male	1952-07-26	jsoxjipsbf	ilfawzzfsq	128
201	female	1994-09-21	hqxejham	stzox	127
202	male	1914-01-21	ahbbizv	qzkloawhx	120
203	female	1935-10-18	zrbqizgdaf	kxqzkfke	133
204	female	1961-12-14	ywldb	vaknnuzu	70
205	female	1952-06-02	cdgqtw	jljdkrc	141
206	female	1904-03-25	zhguuh	wvjdkznplj	162
207	female	1925-10-19	soztrrribc	aeoikyu	47
208	male	1970-06-08	pxqwhjbgdz	slurgunvj	151
209	female	2007-02-01	shszckp	ayzbxsj	4
210	female	2015-08-02	viqcqurvc	gkxmlza	1
211	female	1938-06-19	feskmjeuvn	iuuigyauw	37
212	male	1904-11-01	nwpmrgaygg	zihqt	191
213	female	1990-06-05	spfdjmacnv	mdjoq	166
214	female	2009-09-15	tqrulcoi	oqloagxyh	82
215	female	1965-10-18	asbzraobv	kntonsabhk	22
216	female	1947-03-25	ykcce	tscery	110
217	male	1958-10-21	kjxbwnvaj	sszvp	166
218	female	1995-07-20	ksuxsb	kujzmspcrs	175
219	male	1914-01-14	aihcv	lsodn	135
220	female	1940-02-02	rqpreaz	xkgjq	185
221	male	1949-11-03	jjtzqhb	vvjtzy	215
222	male	2019-12-21	nwrct	xhigby	219
223	male	1974-05-06	geykqdko	zmarystb	186
224	male	1900-03-15	teifqboc	eeorb	47
225	female	1976-08-25	dgzrqhhl	gphds	82
226	male	1921-07-25	dqqwyjuitf	muhwsylzp	20
227	female	1920-10-01	znokxqnozr	hksrnkwodw	184
228	female	2000-03-23	dlvourlw	ucfasm	36
229	female	2016-12-08	zffvshx	qbcwhmop	56
230	female	1987-04-07	nuxwopoqv	mdgyu	151
231	female	2019-08-17	xuzfuazv	xvubza	109
232	male	1941-12-23	gspgh	cfnqabf	53
233	male	2014-04-19	aizia	xwvnh	16
234	female	1983-01-04	bqopch	bqeodrfgj	93
235	female	1904-06-16	dwfpeqxb	mzlerhaft	141
236	female	1965-11-18	xplbexdh	zjjvrct	143
237	female	1921-04-12	smrnebcp	ygzhnzf	83
238	male	1957-06-18	bzpnok	mxsqysnoub	1
239	male	1980-10-04	bahwqv	nmakthlqth	75
240	female	1980-05-15	mrowabqv	ydvhyxwo	53
241	female	1998-04-02	wapuaizzkz	ouhakhreg	9
242	male	1978-08-22	asmqbbopqs	wefwiav	20
243	male	1979-09-21	jeotx	vbhszib	195
244	male	1964-12-20	ndbftmklk	mkathm	76
245	female	1994-12-12	vkjmbnwg	pllrkynd	7
246	male	1968-07-23	wetln	vewiubo	144
247	male	1918-03-03	ritmrdafx	gghtnzietp	93
248	female	1907-05-01	ghdsnb	wgzqbg	154
249	male	1944-10-07	zmqjsucwof	qmsdn	71
250	female	1956-07-10	hwsqnoin	rmwkf	28
251	female	2013-05-23	uoznluibol	slyyhytmsy	188
252	male	1970-03-14	xqoludmbs	xhdidz	184
253	female	1926-06-19	ogfophenm	beexavy	138
254	female	1913-12-21	vaanqwnv	vxosm	23
255	female	1979-11-15	jkawfhi	uykxoxkpse	182
256	male	1952-07-14	spsjfkfv	sshvxwhqiq	101
257	female	1959-10-05	rijdfoo	gkcsuqnhg	106
258	female	1954-06-04	hilloixi	plrddkjvbe	172
259	male	1913-09-23	oqjgjyh	gsxctxnw	177
260	female	1980-05-16	xvuwsxl	apvyqvje	207
261	male	1928-06-09	ziursw	ywuuxi	172
262	female	1923-11-20	ixlglnx	mpacy	169
263	male	1932-05-19	vnbyiixs	lffmfefzkf	8
264	female	1938-02-28	afyodprre	hvaucxez	138
265	male	1905-08-21	ehyblo	kmruftkhfh	45
266	female	1910-04-28	wjtieqaz	oxoclcxqsa	116
267	male	1996-05-21	guldlqpzm	vatowz	182
268	female	1960-11-24	yuqgvkguun	wzfhd	17
269	female	1986-09-13	rccemsfp	gawkfgan	57
270	female	1996-06-23	twaqea	fjmlcbg	119
271	male	1988-12-10	craxfcbnvj	fihjmvupyp	134
272	male	1919-04-22	vyzxng	vkpud	86
273	male	1950-02-07	vdjak	cgurc	28
274	female	1945-10-11	ptnmv	twbqwz	91
275	male	1924-12-20	fughyextt	fgsmbptgp	154
276	male	1965-07-16	xlcoy	inevqmm	205
277	male	1957-01-15	vipddxxyiz	mpaahjv	168
278	female	1972-10-18	cytkt	jmpxnysmz	225
279	male	1939-02-21	hnzulbic	fyopben	136
280	female	1964-08-06	msivridz	vpqhcjq	17
281	male	1936-11-27	wlzfq	nuypgtbvj	204
282	female	1939-02-20	qtfuyfm	jskqgbjcq	69
283	female	1999-08-25	zghhehddqc	xjqsxt	65
284	female	1916-05-05	jgwyw	stqaswnk	110
285	male	1997-03-04	kkmfd	chkdl	161
286	male	2019-10-16	halldz	pqvhorbqc	37
287	male	1950-08-24	amfieqte	qodoetw	206
288	male	1917-07-04	seuifzw	dhuisfrgg	19
289	male	2000-03-07	lfnddgfrj	bqtdriokei	46
290	female	1913-11-12	otokz	lwieqfa	277
291	female	1942-08-20	khkipyey	hvbnxzldh	240
292	male	2013-09-02	ulrnezj	cyjnsytwk	113
293	male	1951-05-25	fcrnbekb	zwsboq	86
294	male	2017-07-19	avwpmjf	agoeaqox	291
295	female	1961-05-23	fzwtqwlrc	ptgwgxzq	94
296	female	1984-04-13	rnumwose	rzzokcz	288
297	female	1967-07-07	regxyk	chpjcbwhn	101
298	male	2021-06-22	xznvc	oczvfgbbwm	30
299	male	1906-09-23	manjmzg	vqjuti	88
300	male	1915-10-23	qnltssn	rzgoiyyo	222
301	male	1985-01-02	vdumh	npqsoni	133
302	male	1944-01-21	mteopkax	lqrov	232
303	male	1948-10-09	iheco	gdoxef	83
304	female	1972-02-07	vjfwmqyfs	pktespbwx	276
305	female	2013-12-15	zngflalqf	kxiyrh	88
306	female	1964-12-10	eaiiegsqx	pitwtxzyy	287
307	female	2019-06-22	qmdkhlr	froiu	123
308	male	1953-05-04	fvahqaot	ubjnf	293
309	male	2015-05-08	ybgnsewe	ykmlq	162
310	male	1947-04-01	uuxpxz	asuoswr	127
311	male	1994-08-06	ejtofp	kzxsoedjow	116
312	male	1927-05-10	patmv	wjkerwy	23
313	female	1996-08-09	fcmstydpxo	mwlkgkcx	241
314	male	1938-02-25	dbyhijkwi	lwnnhqz	223
315	female	1960-10-04	oexveg	atlhkfy	80
316	male	1925-03-11	szrfxxcq	bjsfuzyr	48
317	male	1924-05-21	iykwtwds	gipiapvi	307
318	female	2009-02-11	loyfgbglwp	cmreuywxb	298
319	male	2002-05-14	phgutmzqag	llyozqbbgx	4
320	male	2011-09-26	qqfbdtsm	hxniy	235
321	male	1985-06-03	ayupxujg	zshlwgqbcl	265
322	female	1955-03-16	vgqehlt	ybgktmvfva	237
323	male	1955-11-13	aolwxru	qkpmlfoxtq	238
324	male	2016-07-15	tsbixqth	kwpbvge	153
325	female	1911-03-28	lughxksmof	bcfxzh	254
326	male	1900-08-14	vdtfgggmr	usenmtel	262
327	female	1993-12-17	vfchsbyn	zpzwyu	284
328	male	2020-02-24	yzsujkmh	twvaq	83
329	female	1901-01-12	uhsnpjz	uhrgetvdvc	79
330	male	2009-04-15	byfxm	shjsdfzsr	220
331	female	1993-12-04	bxqgd	jqaih	158
332	female	1921-04-28	xisanbxzc	yeaxrnj	178
333	female	2001-09-23	wrhtuwjw	jqerakdkwt	255
334	male	1909-01-11	pqqekq	kdwat	203
335	male	1964-02-22	hcoklbl	hsvix	107
336	male	1993-11-10	yedsswhmtm	qsopwcjcaz	186
337	female	1955-02-17	ysjrzedsvo	zwwjjw	29
338	male	1916-07-28	aehcjswdc	emowaue	79
339	male	1926-02-13	tontca	ubeiliraz	165
340	female	2020-01-23	rcxcczv	phdaz	339
341	female	2015-08-25	nxeawd	ncugzgdvm	220
342	male	1993-03-02	hhvqkymom	tpuvad	14
343	male	1907-09-19	oqflv	bufyfzocz	175
344	male	1914-10-18	ihobztkyvu	cqavzt	145
345	female	1931-09-11	ovfjnsy	uukms	320
346	male	1986-05-10	oqzitdmq	lwjykdu	97
347	female	1956-10-16	ebznwzucei	fzkiqxq	190
348	female	1970-03-10	wxznnua	dices	288
349	female	1933-01-15	ifjdtejg	optigjngp	53
350	male	1909-10-02	glsiohu	mxifbydqyn	6
351	female	2015-01-24	fxsntmajr	dzotoj	155
352	male	1949-09-01	ysoafpvo	txuytr	297
353	male	1945-06-02	rvqgk	ildmt	334
354	female	1934-01-17	dbfalgeb	ffrfyjkw	319
355	female	2006-07-01	irzsdocyx	fqciwwcx	122
356	male	1931-03-22	ohiages	uyqfrcmasx	84
357	female	1982-07-12	ezhoswiirg	aknbiz	289
358	female	1970-05-01	komihoih	vqxtprbcj	322
359	female	2002-05-14	jvlatq	ltfqlgw	80
360	male	1900-10-12	ilknlqnsx	djrmaqpo	277
361	female	1963-01-13	tjsohnyrft	lsphvlah	322
362	female	1987-05-13	tnfgp	yqoke	303
363	female	1917-11-14	ahfekwykdt	pbelcmq	12
364	male	1992-12-06	jianwt	xxepvbc	153
365	male	1949-05-28	jdnlu	bggnmnatz	149
366	male	1996-01-16	zoagzaydkv	iglyuhg	93
367	male	1905-07-15	momajv	blwmvsjs	303
368	female	1921-01-25	lfmwika	immzy	320
369	female	1996-01-26	bhjijcc	eaaadrgfir	229
370	female	2006-08-20	fgxkyy	duzaj	109
371	female	1917-04-25	qskvsvwvi	wswmjb	286
372	male	1913-07-15	zmiqllgcq	okeabjmkrz	76
373	female	1969-06-03	uyshlup	wwbqke	195
374	male	1985-09-26	qkzmdmzd	huirogdi	112
375	female	1910-10-07	kaqcmv	qfozbaiao	141
376	female	1902-08-11	ayixx	qxnckg	213
377	female	1989-01-14	eegqzruj	ulnzjatir	337
378	female	1976-10-25	xutdyl	fsuid	24
379	male	2004-07-14	dngutoherw	rfiqmkxayl	374
380	male	1959-06-16	iywne	khjubn	326
381	male	2004-08-09	dipkmfgyfv	gxqtbyxkv	257
382	male	2015-05-04	slaljd	jsdvkcbqm	140
383	female	1942-04-03	qlldolx	dpcezwhivf	305
384	male	1959-06-21	qpldvv	ardnpa	348
385	male	1960-10-26	ghnsux	huwsfrjld	241
386	male	1936-08-06	eijzgiur	tkytd	90
387	male	1914-06-09	eqseij	yiximyvhae	203
388	female	1926-10-08	vbgtsh	rromgcbts	363
389	female	1938-01-28	qemuerqstj	zfeyvg	78
390	female	1930-04-13	yrqlijm	ydpqz	137
391	male	1916-08-19	duutsuql	ittygrbo	136
392	male	1979-01-11	ecjiinck	szhspltw	281
393	female	1955-01-02	hdqnjzzg	fgetzpdx	298
394	male	1936-07-07	kekgowgg	wdwvtijsxr	337
395	male	2018-12-23	mossa	ruutr	174
396	female	1940-06-09	sthqmaxur	kmxwdfxd	160
397	female	1929-11-23	gbkueo	elsxuo	147
398	female	1996-06-18	ynbpol	wnrtnsg	308
399	male	1929-11-20	nhvxnaor	svfoztbrm	318
400	male	2009-01-04	vawtykidt	wwzooyju	58
401	male	2013-02-22	uyjbb	tftcxn	332
402	male	1920-08-05	pytnp	lldgfwte	282
403	male	1942-09-21	pluqwlyp	rdwhywq	306
404	female	2022-01-04	mvzsopn	fvshb	330
405	female	2008-05-21	ndokbsydpe	ndfhto	80
406	male	1964-05-14	pbgotlvqk	fgagmqq	400
407	male	1974-06-19	ypzok	mcdlzyfyx	15
408	female	1968-01-11	ixnacxrp	cjkqptqmis	243
409	male	2009-09-10	zfndfnyhle	jpncaf	8
410	female	2009-05-26	gjwvcg	pcjruwanjk	44
411	male	2021-09-15	yyltnnwre	telowoaau	299
412	female	2010-02-14	nyeosjqx	cftatzg	14
413	male	1997-08-28	vgjax	jggwrpnc	113
414	male	1964-11-02	wedbiqbt	lvmblbc	110
415	male	1920-04-19	ppajodk	grrwlvqop	81
416	male	1942-11-26	abyzmx	yrssgnpudl	45
417	female	1941-07-06	gevdieahz	obcfndtx	273
418	male	2013-12-23	wcvgwj	cdzyroarwv	58
419	male	2017-12-03	cjgeoabza	rszbdjee	216
420	female	1976-12-23	mmzoxhbkw	pykygjtt	61
421	female	2018-08-15	yipacojpa	kelwgz	227
422	female	1971-07-12	jzlfpc	yrppngxp	22
423	male	1932-01-28	afvndpimtq	auwabil	226
424	female	1985-11-06	asuqvfzfny	xktvubscz	314
425	male	1902-02-12	avgfmmj	uqnwhwgyan	311
426	female	2000-08-16	gwmrkuqv	sbgwd	78
427	female	1956-07-08	kerdsvyxlc	ponijcq	116
428	male	2007-12-02	lenbzariv	zqzem	90
429	male	1988-03-13	yfchq	msybeepny	70
430	female	2020-10-16	wsilsgvw	ljoyuiv	368
431	female	1916-05-16	qmnamqiqft	nmerwhvk	220
432	male	1915-08-18	vojrscr	mwevs	216
433	male	1907-09-11	vrhzmrsibg	jtftojpkfj	149
434	female	1922-09-03	mavtnnmsb	mjabv	245
435	female	1972-03-20	uyqjyk	rmoypuf	1
436	female	1980-05-03	rzctm	jfgatvwh	222
437	female	1950-05-16	lhmpsours	kaffpwmy	175
438	female	1947-11-04	mzpqjlx	tloqfxam	242
439	male	1994-08-12	svvqsd	fcmev	296
440	female	1993-08-21	woacms	hkulgwt	216
441	female	1940-10-20	wlvxaoqsc	jetge	79
442	male	1962-08-03	ifzpb	sxmrt	382
443	female	1999-08-24	ylgtuj	fzmirlb	302
444	male	1980-02-08	fhtroexk	ckhkkd	257
445	male	1910-07-03	kpokocapt	nddwaeaof	179
446	male	1912-04-01	zmrgsimgh	uvgqvxjwlw	213
447	male	1990-03-09	izuurvpolr	obiiycn	28
448	female	1950-01-20	ialjdsq	pnnenttn	72
449	male	1911-06-01	rodziluxlc	rlcvfoekrz	249
450	male	1941-02-26	dktjpeavv	kkuvlwyl	243
451	female	1931-02-12	vjdjszxu	inxsqdg	50
452	male	1994-10-27	xyiun	ymzjajbnfy	189
453	male	2008-12-06	egenezndcy	zrqco	97
454	male	2001-02-23	ksjkdhozq	plmhgjnor	317
455	female	1924-08-25	ohvqqv	qdwlelvwe	39
456	male	1921-02-15	lxhvaza	rodthjm	104
457	male	1905-04-27	rjlvc	jiufo	349
458	male	1904-08-14	wiblwrgimi	yyvui	169
459	female	1944-02-10	sazvx	upcwuht	238
460	female	1954-04-11	jgzopwtew	ohfvcgtkz	233
461	male	2009-10-21	rhhrbnj	zirlpmali	189
462	male	2006-05-02	mpowks	nkfjtv	456
463	male	2004-07-24	olcqcxo	tfsopkdrv	292
464	male	1990-10-20	okwoq	edaqsrckpb	6
465	female	1910-12-03	sagdlvgd	unvednw	283
466	female	2010-09-05	lojut	ykaxf	451
467	male	1947-05-14	ajxfi	vgifrvvb	368
468	female	2008-08-05	fkbdn	rbpthk	251
469	male	1996-02-05	alzjxrjw	fyjwnvim	197
470	male	1928-05-23	yfrxjppwg	yftqeur	291
471	male	1919-08-22	qqxafi	zhrqfriqb	442
472	female	2001-10-04	leofe	cjhlzq	396
473	female	1980-11-25	slzlfht	zhzzkryfd	313
474	female	1975-02-02	ujqvj	sauzwu	190
475	female	1949-12-08	fmvlt	jptgee	86
476	female	1994-08-14	afagql	nvnvokm	106
477	female	1957-12-20	novhffc	fvgtxse	405
478	male	1922-01-02	qvunsrenel	gbunavei	338
479	male	1943-08-23	gwdqaqc	qzczgi	208
480	male	1982-02-08	kllkfvqh	ucuirue	418
481	female	1970-08-18	nglyhvwgj	diiefgpi	469
482	female	1922-01-26	fbwznpnck	nvwutb	216
483	female	2003-07-08	xzduhrt	ftuenjm	83
484	male	1936-06-08	etodihela	hophbajzp	443
485	female	2018-11-22	lkxzz	ccsrbun	340
486	female	2018-06-11	sbsqkbteya	dsspyvjqca	326
487	male	2015-06-23	dxgvrytbi	kgkmoqbdlr	204
488	female	1967-06-14	ftyjn	fxgkdzd	229
489	female	1941-03-10	ckqxerlbe	ugrmefgq	449
490	male	2009-07-10	tpwpfjhiq	eaegdsbolf	110
491	female	1981-05-18	spjnljb	hrhoaief	410
492	male	1939-12-14	tlolnn	rqhjvcn	440
493	male	2009-07-28	baosugixf	nfupmllqiv	474
494	male	1936-03-10	vcwuwrsg	jxspl	273
495	male	1959-01-18	gyccjo	xvvunfvjpb	18
496	male	1929-07-05	dnfbvjks	llokkdyrao	245
497	female	1934-04-05	hliqalxtc	vdbqhhfsp	334
498	female	2002-02-27	qcugqnc	vnudbpxp	145
499	male	1955-04-17	woaqe	xvxdzbxwk	72
500	female	1969-12-11	mevlzkem	tldwq	339
501	female	1911-04-23	dtpbq	qpwkjnoezd	282
502	male	1968-02-07	mdvbduurc	rppbmdjkzt	240
503	female	1946-09-13	qptgsp	lsseuryya	280
504	female	1914-02-17	kmcdpcxn	ezrxsm	211
505	female	1996-07-13	pwhgfu	vnjmebgff	71
506	male	1910-04-07	mnyhk	szdlbvzxn	348
507	female	2003-12-19	zejbrohya	osejx	216
508	female	1994-02-01	qjfjntitbp	ygogksn	333
509	female	1969-05-15	nkkuvcn	uqwbjqmwy	342
510	male	1903-06-28	pjgzonvr	ssrdy	136
511	female	1959-06-04	zgsrea	bcctxiy	504
512	male	2005-06-11	eyihufn	cijbxir	159
513	male	1997-08-13	owojqtn	slbwoh	246
514	female	1943-03-12	pmkspoyd	gztciisl	509
515	male	2000-12-11	fpphtm	clfejqumku	158
516	female	1972-10-04	whrqqxqlho	ppxmt	28
517	female	2021-03-04	bizplbcu	oazbxqx	53
518	male	1958-07-19	nocqxg	xqdrs	272
519	male	1967-02-26	rlouok	emvws	274
520	female	1936-01-11	jdmqgta	jlisq	258
521	female	1906-05-01	odcbagwh	gbepyutzs	77
522	male	1998-08-28	xjbilslujq	ikqvf	373
523	male	1990-11-03	wcvuwhwcfp	yrsycavq	32
524	male	1906-04-27	fqelx	jjwgovidaf	40
525	female	1956-10-20	ryaoglx	hdwkb	424
526	male	1938-02-13	alvtewg	skxsatxrey	403
527	male	1900-04-06	qrfgzn	ikeri	441
528	male	1928-07-24	gkhupfmf	ffasub	431
529	female	1930-03-22	bcinda	vcgajs	219
530	female	1962-02-19	wcmyrdbo	gtefzb	189
531	male	1997-06-24	zgiiuqc	wsttrjmeft	115
532	female	1903-06-13	kencz	ivmsjvpna	353
533	female	1959-04-23	jpfme	oldutodd	174
534	female	2001-06-18	uautlmh	yuomogfby	202
535	male	1975-05-13	owguqn	ypmsfj	391
536	female	1930-04-17	xohgvycg	pnbtm	337
537	female	1964-04-04	vpnksujhzz	vquylmd	281
538	male	1938-03-24	gbzrcvqdgy	snrjatbhmh	294
539	female	1943-11-21	rwiwhhmmql	eygkqsmltp	280
540	female	1921-09-23	pynevrduzn	rsiuojyvn	197
541	male	1962-01-21	qdkfa	qkiitsq	537
542	male	2013-03-23	wumoqwcy	ixujjotx	287
543	female	1927-01-11	veeswx	jnrihlro	323
544	male	1910-01-11	slsknciott	fmlmdc	126
545	female	2020-08-08	crpujsy	rwjmihwlvb	62
546	male	2015-04-17	hnlikwge	ftgfsdng	321
547	female	1941-10-03	snfkwum	ftioizlr	451
548	female	1909-09-09	cmorzzt	ghpotigpf	485
549	male	1900-06-11	gjylnvjbi	wvnrnpjv	5
550	female	2015-01-26	nvyye	cwhppxys	282
551	female	1937-08-05	ukkwznccgr	kyxlfwcx	85
552	male	1993-01-13	lmxvcjjah	gnnytecq	416
553	female	1908-04-12	tajmk	pikpoxcys	297
554	male	1968-10-22	yoyqdeco	xtiqbjzcd	520
555	female	1990-09-25	hhfisc	wjoqtxfh	29
556	female	1909-12-23	yiyzco	iifgc	86
557	male	1952-12-25	ptclrfjhwa	peynit	240
558	female	1980-09-27	wmgrnahx	nszksdq	23
559	female	1915-05-03	mvgfufrqaz	gajwskgpg	176
560	female	1918-02-28	ewfzae	uudepouju	123
561	female	1934-02-20	isuoweyx	ewijncml	353
562	male	2008-11-01	prisatlh	vwbyujv	289
563	female	1963-07-07	gvcpw	ncavrzsas	319
564	male	1984-05-19	hciwldbg	cjbrvzz	139
565	female	2003-09-03	dklidwkqln	bquut	307
566	female	1994-10-04	qartuatqtg	msstkft	140
567	female	1979-04-09	tgyetcudes	fwbhh	231
568	female	1924-06-01	jalfaevqo	hinnkom	470
569	female	1919-05-04	bqssbzr	fxlfadze	196
570	male	1984-08-14	gsnag	rhyfdahyp	388
571	male	2017-07-01	qxlflsm	kcajo	378
572	male	1993-02-10	bimoixzrd	ktgmfew	97
573	female	1945-01-21	jfmvsuzmn	swddwhyu	355
574	female	1979-04-26	brjxcuaqgs	nazkppeyl	127
575	male	1937-01-26	jxsza	iltmmumb	197
576	male	1981-02-22	vwujxmwyip	dxijvbf	2
577	male	2022-08-17	yzuwfu	snhavmscm	281
578	female	1920-05-19	nnpbb	wesfenmyz	189
579	male	2004-12-06	avkml	pucxsbvwq	405
580	male	2020-01-09	hnabgnhzfi	zgsmr	298
581	male	1987-03-02	kafdoqj	puzygfo	234
582	female	1990-02-10	zyyqjmz	xrucqt	37
583	female	1903-08-01	bsswbsjzpc	bcbqz	168
584	female	1922-04-28	abiihigw	krbacwo	77
585	male	1980-05-13	mkrsklxwh	hzjnegmz	475
586	male	1980-12-23	cwxsafb	cjfmgrv	432
587	male	1977-07-02	gmwbvxe	ogjmw	74
588	male	1922-01-12	xrcqajprb	rfgsl	579
589	male	2005-12-09	mpabnkxqv	cjjfvpvb	458
590	female	2006-08-07	zkvel	sietpfzjq	146
591	female	1936-11-09	hirpwzio	yikddjnkn	361
592	male	1988-08-02	lizfzub	pcoeuetzoj	540
593	female	1912-03-16	uafqhqzfc	ymbjstxia	146
594	male	1968-07-26	xrcsylgpjo	yylkwzua	302
595	female	1997-05-17	uzzyl	grfbj	20
596	female	1918-04-19	ezhkmnwlk	ftjyuzuout	130
597	female	2008-08-17	kpavrja	aztji	176
598	female	2005-09-24	trfuacgjpm	wtvpupz	571
599	male	1920-05-02	ckotapr	zpjfsmivvz	311
600	male	2016-12-15	zuhjjevjcb	biloomx	363
601	female	1932-02-17	vrmmzhzom	fgqrieurx	238
602	male	1919-01-11	lrdtfwpbp	dtidxi	252
603	female	1911-11-03	txgoj	lonwmsbbli	126
604	female	1983-11-25	fmpylw	fmvaj	458
605	male	1961-03-13	wpywn	xzhlraapen	165
606	male	1909-11-17	ysrflj	phkgadoyn	232
607	female	2014-06-26	vahpqkuy	dmfkfxt	427
608	female	1994-11-16	waehifqp	gjqywrxzg	70
609	female	1930-01-11	ctjdbva	jpmqcxbuw	474
610	female	1946-05-07	kbblxcfex	fflnztuy	274
611	female	2001-07-14	wlxzdiy	mfmumwt	541
612	female	2013-01-15	yqzemkx	exxaijfm	570
613	male	2013-12-16	depmpyz	vbsdda	140
614	male	1991-02-06	lsbju	wzxfbtm	150
615	female	2004-07-25	fabieisf	ridbrxmzat	156
616	female	2010-10-01	veabxx	biwdc	432
617	female	1905-10-12	nqkix	lblfmnjee	514
618	female	1926-05-28	nlwrzqs	tvthmtjm	38
619	female	1976-01-06	sxxwnwrm	jzyte	127
620	male	1900-02-21	udswkgw	ipcenzp	73
621	male	1980-02-10	moitkatcwo	cdfnabk	437
622	female	1936-07-11	amjvnz	fvmwg	87
623	female	1929-04-11	sriiecx	fkwcqnjsq	480
624	female	1983-06-13	kuvsj	upjxazv	149
625	female	1968-08-11	bghurd	wsroznhnz	160
626	female	1946-02-10	maselsfrm	sjpkdnuwej	82
627	female	1966-03-15	jqbffnni	fjkyedmpsp	333
628	male	1943-01-17	zkycdyx	teroixplbf	323
629	female	2010-04-08	hpscxsnh	nhdfwzcyid	513
630	male	1944-02-15	dgdnyfvtgf	hbyjvmktj	629
631	male	1968-08-19	wxyijf	ugwyhulwh	164
632	female	1986-05-07	zeran	sretjweztd	575
633	male	2016-11-26	manwegdfsx	riwsah	583
634	male	1987-07-28	vblhn	lymdhytq	634
635	male	2004-02-06	btqsubzw	cwbefsax	160
636	female	1908-03-22	lcclogom	ghgbf	15
637	female	1904-10-26	xbogyrumd	nniobpo	338
638	male	1995-03-28	evhvwr	qacqwxggsw	244
639	male	1979-03-27	iqtmggc	zevwcfxbo	40
640	male	2016-03-05	cfjodmxkpa	vwljbcgud	65
641	female	1991-10-11	xmeey	qqywl	41
642	female	1976-11-26	fewxzdc	lfsqo	410
643	female	1983-01-18	svkpyjb	mjrogwmxp	421
644	male	1967-04-14	ehocok	ebhch	15
645	male	1936-04-01	rtffc	hmvrnxjhlw	580
646	female	1996-07-25	ktmqknktr	nqrfz	547
647	female	1978-11-08	rsskm	ovnhhi	83
648	male	1960-02-04	kbcbihf	bpyea	134
649	male	1995-02-28	efibyx	fxpjb	53
650	female	2002-08-07	saqibizk	gluraoni	213
651	female	1940-04-20	pvwvbvzg	yjwmadqoix	31
652	female	1927-09-13	jfaifbyj	oapqedjqd	56
653	female	1976-04-14	gjchum	dvmfwnkp	18
654	female	1920-10-28	mrrcpv	vlfwnss	530
655	female	1997-09-27	xocog	axaeayw	76
656	female	1963-04-08	winhscssr	xiakvgc	161
657	male	1943-11-27	fvkmh	vocdzd	504
658	male	2003-11-01	tpwcfzz	qhznskbt	193
659	female	1905-11-16	ntbhasph	wfxtzj	507
660	male	1994-11-19	nbguklol	muldaovtju	238
661	female	1984-03-03	addfbvp	cubqlqkuen	115
662	male	1941-01-06	xazyz	uwhiffo	281
663	male	1958-12-16	qtctqsfq	tryke	427
664	male	2013-06-18	yxerbdr	tiwmzwizqz	373
665	male	1953-08-17	rufvjhhf	rlkxanu	71
666	male	1963-02-25	stvzqxn	vhvoaeui	114
667	female	1985-08-24	gjkletj	lcwosuucj	59
668	female	1948-12-09	fhgqq	fckitq	600
669	female	1979-12-21	fixpet	qdfnd	14
670	male	1975-02-14	rgvoucfl	pmlalz	310
671	female	2000-11-06	xyximdbewb	ankytrvfu	299
672	female	1923-05-28	kjxqunmdx	ohasekwesn	432
673	male	2001-02-26	jrcfvls	efgthe	132
674	male	2019-02-27	umjri	klhmyld	63
675	female	2013-10-07	fytrjgxhe	oblkzor	524
676	female	1977-01-14	ywmskhaec	blbiehzlf	475
677	female	1935-11-28	gukxbgbrh	ifjgzt	263
678	female	1964-03-04	qqlaia	kqdcslf	61
679	male	2000-02-13	ipehv	ljmrame	47
680	female	1948-01-16	xdvcxwr	dyxlnoi	636
681	male	1985-10-27	figcr	sfvrd	324
682	female	1935-11-08	kpjondnrh	ecjmsaadsw	310
683	male	1978-01-07	wknwcwd	ycpol	482
684	male	1976-06-12	ummzvzpusd	hmpugyzoiv	561
685	female	1902-10-04	wizqguyli	znatn	277
686	male	1904-02-11	lajsbxksi	cltoqgysqw	354
687	female	1986-08-13	ejsfnbbqva	awmfdxpep	373
688	female	1953-04-05	jango	vigxtomh	607
689	male	2022-05-10	bhxxllrov	asxzdvd	336
690	female	2008-11-02	ttshgag	mmdgmd	336
691	male	1968-03-27	elnakpqok	vrygyayjyv	622
692	female	1942-08-23	iujolscsq	lampqt	16
693	male	2006-11-19	evdhnx	ovedtnvh	345
694	female	1951-04-08	brqiurkwag	wytfhz	411
695	male	1934-04-14	cbaelrscmz	htrpk	381
696	female	2015-05-14	vdznmlput	ygzvwleop	689
697	male	2005-08-01	dcbkmld	egvdfq	206
698	female	1919-08-28	qdtgykpn	pctxuldl	558
699	male	2000-12-05	mjwevqon	jitif	197
700	male	1988-01-19	vxoumrt	hgsrbec	14
701	female	1954-12-16	zoltqnveq	oecwrfx	483
702	male	2011-03-05	qvvdcc	cifqkz	395
703	female	1972-01-23	tnegmeuuwn	jlqih	91
704	female	1971-07-01	vmzddpygk	wipfap	654
705	female	1995-01-01	fyxpi	ouyotrwqw	342
706	female	1941-05-06	fwdjvpkje	hmuzynq	238
707	male	1918-11-08	lwxvjv	kpzcn	557
708	female	1932-11-11	epdli	nfvyivh	29
709	male	1935-07-10	rzreejeaz	dzkvwwihp	283
710	female	2022-06-12	imyavqo	hdixh	130
711	female	1980-10-23	pzfhclyd	cabge	149
712	female	1949-05-18	mvuwzf	efchr	616
713	male	1982-08-16	pdedzy	szkcrqo	434
714	female	1932-06-18	ldmzafgcwq	rjbztigkb	334
715	female	2010-11-22	yfxuc	dwsxkxpfi	399
716	male	1961-01-27	gmzublaso	xblfreh	236
717	male	1971-03-14	ltaujh	nvrqtv	63
718	male	1973-02-17	cepllexph	bcigneb	387
719	female	1986-04-09	ynnsy	iqcqlqt	411
720	female	1993-04-19	apaxjnu	hdysxauc	521
721	female	1903-03-18	ubzvj	vjoqbits	432
722	female	1920-10-02	itxuatufyx	dxuquooim	542
723	male	2018-02-28	fecknlei	fnpfhb	322
724	female	1995-04-16	vcrubm	twwvvac	627
725	male	1947-08-07	chkamcws	wpktez	613
726	male	1931-11-19	rnfdl	ovplszuuzm	675
727	female	1915-06-05	doetklsoi	qhbcwtjbyo	203
728	female	1920-04-02	oarqjr	ayaozsrmo	594
729	male	1999-12-14	ytfdsox	xsvjtcl	104
730	female	2018-05-01	eoqzdvw	ovqxxjk	19
731	male	1919-09-08	nknmxkrqo	pgtylgwgdd	54
732	male	1998-06-16	lnpjzubdoq	bvuzn	221
733	female	1985-10-09	iddnl	vqncuynzsm	112
734	female	2002-05-03	mmynrykf	schzihxsw	595
735	female	2012-11-04	teuwn	divvb	600
736	male	2019-02-25	kpxhmug	gcajar	345
737	male	1956-02-26	tkvsv	vdcolos	435
738	female	1996-05-27	bugxgcms	ygyzbfvko	720
739	male	1966-11-12	imftrrnhyh	irzvs	397
740	male	1906-02-12	mpkmtgsup	jfhvcdw	105
741	male	1928-11-02	uqstxhz	yxahgg	695
742	female	2006-01-27	jneyugkcx	sqxshfwqy	406
743	male	1936-11-04	dptmjpqzgx	hvylwwib	287
744	male	2000-12-18	lubum	nsefirqjdt	90
745	male	1958-06-09	sqrtgn	bxnyzrewp	210
746	male	2011-11-02	kwnxxtdaac	hnepfdokvx	55
747	male	1926-01-22	vstozgd	wnfjak	508
748	female	1951-03-05	vrsfaqj	sqsel	168
749	female	1995-05-09	neonyy	erhnv	345
750	female	1947-03-11	yyqvj	cgylugwk	731
751	male	1910-10-09	lkmkequs	zfmqxbil	474
752	male	1977-10-02	namhdt	evduf	433
753	male	2019-07-07	amhsneiycq	bguxp	215
754	female	1975-03-18	lphbedp	seqkvqs	152
755	female	1971-07-13	qbffhc	qwlvmhci	172
756	male	1995-03-05	wrvxgjqri	ofckrj	462
757	female	1975-06-17	gpdrpgcjg	etouupzoc	26
758	female	1994-10-03	rqrubrtel	mevxpra	615
759	female	2018-10-25	hyoduk	kuann	102
760	female	1947-07-16	stwam	rlqaoq	582
761	female	1985-08-08	acwmlv	xaofueqv	598
762	female	2006-07-23	lmqanckz	rnvnzm	110
763	female	1947-01-17	gowbmlerzw	ufalw	214
764	female	1985-06-23	oqmuuutcnl	gwyxtcnohj	56
765	female	1919-07-20	fgirjn	vcpto	2
766	male	1944-07-18	ilbrewx	utuess	659
767	male	2011-11-07	lzegykgy	txnex	210
768	female	1934-06-23	aswpi	tllkwgpev	32
769	female	2010-05-16	ktpbw	jmwhbzzx	476
770	female	1932-09-11	jrhcclzju	zexjorj	673
771	male	2011-09-04	krhefgak	tshmozbnhh	479
772	male	1906-10-08	nfxhmdsror	ppiggzsl	236
773	male	1975-07-14	bnylhq	qfhnjjg	12
774	male	1911-08-25	kgnkc	wbpuaelddy	487
775	male	1976-07-26	fqobejb	nbuvjrqa	457
776	female	1923-01-19	vhxjm	vwhgxe	167
777	male	1958-02-15	zymala	sgsotqeib	386
778	female	1968-05-02	nsspizfzb	ysjnzbx	368
779	female	1973-02-03	yzgubusep	xdxwnd	716
780	male	1932-09-05	dtrwqd	gutxj	344
781	female	1914-01-14	pzurnye	dymnis	330
782	female	1945-09-21	gxlecwm	lursqmnodo	737
783	male	1920-04-06	xwkcqjyuog	vcboj	621
784	male	2012-03-10	ricnqf	pkibqznvcg	415
785	male	1927-03-13	dmqumly	uvjwedvgd	771
786	female	1982-04-10	fpnvg	lezui	120
787	male	1901-09-07	gmsyhch	nkzcmpurih	166
788	female	1901-07-20	qhqwti	fqktp	259
789	male	1902-11-05	rmnxam	rlfvyknis	630
790	male	2013-09-18	cmpis	rmcmvxwqen	281
791	male	1946-09-28	obdzbuu	gesuu	201
792	male	2018-08-19	pkxvjmez	tuovuftez	692
793	female	2011-02-12	ypajrjev	ylxnffksi	774
794	female	2003-03-24	qkkzzda	tsyvfsgmht	357
795	male	1979-10-10	gontepcnu	dlaffdqbc	422
796	female	1911-12-16	pbzwn	jwvhjehf	312
797	male	1986-04-14	memythvfdx	wkbpwvu	291
798	female	1904-06-26	ayxms	mxdtjajw	418
799	male	1982-10-10	fvajkrqzb	ddyjc	97
800	female	1963-10-17	mhckcnbzvv	ehckwpnx	391
801	male	1962-10-21	yfcbqaas	zrqzjk	166
802	male	1945-12-25	imeyy	uqmgtuuqpt	283
803	female	1912-08-07	zsmugzli	qvelipas	496
804	male	2012-12-24	xrtoiyrzq	zctnt	263
805	male	2010-03-27	zhnodnx	pmyikgyqr	373
806	male	1915-09-02	mepbmdyng	kbvae	22
807	male	2005-10-23	uqirintkg	ebohy	666
808	female	1934-04-16	lrllpys	ltwkvascd	54
809	female	1987-07-02	brxjqyyyk	ousbnkdkb	760
810	female	1933-08-14	zblsmx	yrdyythxad	756
811	male	1982-08-07	yihytfrdrc	qgsabg	380
812	male	2008-03-26	ayxmex	zdxjvxt	70
813	female	1982-11-07	zrjwikxwuk	pxtncdw	319
814	male	1961-01-09	ghcsl	lqexyiz	748
815	male	1982-11-21	liiepjqn	oplzhwaf	253
816	male	1959-10-03	msmmmvbo	dwcwa	240
817	female	1925-02-08	atopnvj	hxspqwanfw	547
818	female	2003-02-15	bdeoykq	sixhmrmt	669
819	male	1954-11-09	nvtkx	nhxhwf	632
820	female	1934-05-21	usbtszjw	vqdfmbuhkp	161
821	male	1938-07-25	zutynigkvx	prqoe	262
822	male	1965-12-20	fthccs	ghldc	730
823	female	1976-06-25	pbnvu	waubqg	773
824	male	1904-06-05	cnryju	magli	656
825	male	1988-01-01	unjne	etdahg	681
826	female	1948-12-20	nomkdkmuvu	zmgvz	700
827	male	2018-06-05	gjdiii	iqcditety	118
828	male	2022-08-13	vjsmrunubz	dpbnsoc	363
829	female	1923-08-12	gqfxlw	zczltqz	370
830	male	1987-05-07	vwvpj	gbouittaa	96
831	male	2009-03-26	mgqhmiu	cocda	467
832	male	1920-08-24	mgdfxajid	gvillccymz	243
833	female	1997-08-12	zbvugia	ifjmvugpas	104
834	male	1954-12-09	kdhhopma	yekyvb	408
835	male	1994-12-13	dtgfqnpo	skjrvnklsi	196
836	male	1950-09-20	uxkqpabgnu	edqxmgfitz	163
837	female	1922-04-08	odkwjb	tldyigi	779
838	male	1922-05-16	iyujq	otsniqlpu	279
839	female	1949-11-14	yhfpoeugud	irbgbof	546
840	female	1974-06-27	zmbllfvtzo	jpoymda	383
841	female	1963-03-12	wwhzverb	vjnoxpo	368
842	female	1927-06-06	ckffdmifib	nasry	469
843	male	1957-02-20	izfkly	vzokama	54
844	male	1974-12-14	jlvljkiss	hskfy	92
845	female	1956-06-16	djstkwpsad	yfxgpsc	790
846	female	1933-07-13	vqcgv	wdblzqjb	664
847	female	1978-05-05	haevjkxk	dcvijs	222
848	male	2006-04-16	dqfzvjon	tbjwgkn	521
849	female	1945-08-06	rkwysow	vehyfxr	139
850	female	1968-07-14	cqrbiolfrj	zhnyjlf	301
851	male	1968-08-03	nnqgjise	bihez	39
852	male	1940-06-07	gzqoyvibvi	wqauphj	51
853	female	1999-04-17	kpjztxnv	fqxrzy	407
854	male	1907-07-08	eaajnxvjs	spbwux	261
855	male	1923-09-25	gzjpddvjq	urcoejhd	56
856	female	1937-02-21	vmyyhur	mcikp	152
857	female	1922-01-02	ywfzq	smozzab	314
858	male	1987-01-07	jzzkiq	chqkexadnr	244
859	female	2011-09-01	xmadrghpi	nzzna	170
860	male	1938-06-13	dziyudm	hlojvzd	724
861	female	2009-10-20	zeupvono	nzyqffl	191
862	male	2004-09-28	tbkwqwoe	wgodoiusd	516
863	female	1909-10-21	fkpdmrrp	kkgplfsbxp	460
864	male	1943-05-05	bhzrtvbaow	etlebxrc	840
865	male	1995-08-25	qigxhqpjz	oqlndlx	670
866	female	1938-10-24	hlgebbxgat	xtwodmlo	338
867	male	1933-12-22	kvctp	pjfygdmgug	787
868	female	2015-04-26	tukrm	ofqtc	355
869	female	1985-03-20	jmwqxm	dsouuorf	651
870	male	1976-09-28	ztxmjoptzm	ljlwglgkv	730
871	male	1906-04-14	tzcywrqpgk	uxilpdyn	192
872	female	1966-05-27	zomeyrcwx	qkwcuttxrg	782
873	female	1971-11-02	tijwwyyx	adghmztc	341
874	female	2022-05-11	xnorc	fdzaipdaob	723
875	male	1986-02-08	uksooodx	xmwnd	430
876	female	1904-04-27	hcnte	ygybysa	394
877	male	2010-02-07	pdoelohif	ibfgtq	567
878	female	1991-06-06	coqgzgznl	mmowmkf	471
879	female	1951-01-10	xnlvjiuuh	xzwfmxnb	66
880	male	1925-03-27	kcmvifewc	sithfs	830
881	female	1933-05-10	mmzuwaahh	dtiifon	253
882	female	2016-05-27	zbdcm	llsokye	143
883	female	1950-11-09	ywmdv	deezp	486
884	male	2019-06-09	muvvk	wibmw	82
885	female	1978-06-14	uziei	ccszzwqas	279
886	female	1954-11-05	ecruhsuttl	tkrnjfdf	322
887	male	1905-10-18	xpxmw	kkrgyqlkq	406
888	male	1982-07-23	hnugfwxq	qqlnn	593
889	male	2016-11-16	fhowgqsiab	ruhnek	159
890	male	1970-02-15	sgxmwiob	pduusjj	144
891	female	1923-04-15	jiqevyn	rlbwiocovq	701
892	female	1926-09-03	cpjemjq	tjoyfpoab	11
893	male	1952-12-15	griyoq	ucnumbtr	721
894	male	1944-02-25	kewlqgtxs	jmyklac	370
895	male	1970-12-23	mtcrrvtl	qylagfjbb	603
896	male	1905-10-13	etpqrm	wbfzt	743
897	male	1905-06-12	fmghsjpfuk	jzilun	817
898	female	1976-12-09	yfjktqdvsl	kiqydxrh	859
899	female	1935-09-08	eaqpoqsvp	yubhur	735
900	male	1941-09-28	lxummxzxs	vlnljfu	502
901	male	1997-03-11	cmtxhuoeng	rdkrsiftj	40
902	male	1924-09-25	rjuqjeqgx	fbylffjjbt	159
903	male	1921-12-05	nfpjga	fkpap	775
904	male	2022-07-27	aqomrgdn	ydrhektz	387
905	female	1948-09-12	qmpbcuac	ijpfsgc	229
906	female	2004-02-25	szvnod	lmypb	245
907	female	1910-04-07	ioffjsrxb	ubmlaljs	312
908	female	1923-02-14	rpmpbowj	uehznht	134
909	male	2004-12-12	hatgqya	svkgzbarx	467
910	male	1972-03-27	beboqcr	mervftjh	551
911	male	1948-01-26	grrbtwtvrb	hwywr	576
912	female	2012-08-18	paalbtse	pjsop	816
913	male	1931-12-07	gewideptnh	mrxho	272
914	male	1915-08-25	dmwebrv	lyfirybl	566
915	female	2001-06-06	krvynjl	fqpbtqz	520
916	male	1914-04-17	ricjspmvy	utczherb	378
917	male	2021-08-14	bxyaqx	oepbc	67
918	male	1924-06-11	wowxyvlrn	gdgqasti	630
919	male	2022-11-27	umimjxw	ekftij	22
920	female	1906-10-11	hvonxd	vqurcu	80
921	male	1914-10-13	xlrxybci	hwdyw	179
922	female	1925-02-01	otzlbdkws	byvgqlr	638
923	male	1943-04-23	zyrzjzn	kozmtv	841
924	female	1989-09-16	ucsfeagh	vspshh	296
925	female	1961-05-16	vvfrzdcpvu	slkxah	865
926	female	2022-01-06	isuahg	uknxnzq	561
927	male	1921-07-24	xfoppk	joiyncw	171
928	male	1910-11-01	ruqdv	qxguyepnoc	23
929	male	2011-10-05	rgeghknp	yogjzbor	109
930	male	1905-09-16	shkwugbmpo	cxqbjfqwox	281
931	female	1917-11-03	cxztwvut	tprxv	630
932	male	1998-05-24	jgofhliygp	liqlact	339
933	male	1981-07-03	ilcihce	bsbhancmz	710
934	female	1990-09-07	ywiavub	ardane	875
935	male	1980-07-14	khvkjvu	ekadcnhjxf	555
936	male	2009-01-19	pgauvuvmsi	qbxshu	127
937	female	1915-09-21	kaccansud	qgnyqotsok	282
938	female	1970-04-07	ggxiqz	ocbkbq	242
939	male	1983-11-26	baecq	bgniqityo	418
940	female	2016-03-22	wwtcb	rfjxdbuuan	859
941	male	1965-07-26	hqjmvgo	oextcipfw	360
942	female	1992-07-18	srgozqewyw	amzvtejie	868
943	male	1988-09-22	ubiuoqmear	uuqjrfpeme	12
944	female	1975-10-16	mdgppsmtf	efwcdtowy	790
945	female	1925-05-18	inhnq	hjtvzbk	824
946	male	1974-03-06	zbhvnhdff	izrtdhd	590
947	male	1912-02-13	bpgomxd	nwnyvpzpep	665
948	male	1906-01-09	jfmszcxuqo	dewdhj	92
949	male	1909-06-17	xxjxoize	fjtujtxr	629
950	male	1986-07-03	ahjzxsp	gubwhldjky	231
951	male	2009-07-10	bpzzbsvqh	ysrmxruhbm	429
952	female	1923-06-24	cldpszqlt	jkplockkm	524
953	female	1924-07-20	rqqdpy	sjnwndrc	346
954	female	1949-01-16	ujsqxhnegr	kuliynxxlj	648
955	male	1998-10-07	ievespt	pecryf	203
956	female	1934-08-24	cfnisgupxk	axwycisykj	362
957	male	1983-06-06	qdokuyl	natlr	612
958	female	1980-07-26	xndzbevshc	msrctjjibg	762
959	male	1939-11-25	jdryi	puyjkuass	899
960	female	1933-07-10	eqwxtseuz	yytjrmtxu	602
961	female	1914-11-18	jsxybyod	jvcxyoyczz	727
962	female	1960-11-22	xmkvlyc	rixiw	507
963	female	1935-10-10	utgjdxoec	iqibh	214
964	female	1928-07-05	igdmdd	pqbwfe	342
965	female	1928-06-16	mrfdv	oplhucc	786
966	female	1962-05-03	dtchgpb	cowffb	700
967	male	1960-06-26	yhfsub	popecdthvu	56
968	male	1994-05-11	sprxwllomv	kqpvcu	854
969	male	1943-07-07	uyztjhe	icueo	930
970	male	1981-08-13	upcwrme	owwjlrn	677
971	male	2001-10-27	pylaya	oqqpv	48
972	female	1910-08-19	iizftzw	bcbjaco	542
973	male	1969-03-03	czwffqiwqs	qktjsi	744
974	female	1966-07-08	yzfnxtu	ybappbo	290
975	male	1984-08-09	ghdiv	nfnoeiana	524
976	female	1998-08-09	ejppbxpv	egffiekhnv	697
977	male	1970-01-07	dmdwxux	dcysl	31
978	male	1931-02-20	sezektynmg	vtpbdhizt	825
979	male	1996-01-04	vjeafnw	qeciulceju	602
980	male	1915-10-18	sieczqh	qyovi	886
981	male	1984-08-27	ajhtetx	ykvitnaaa	892
982	female	1999-11-13	pprnwl	vywbstnk	878
983	male	1919-06-13	qrgztdqiq	pzkoahge	284
984	female	2018-01-04	uoaxdba	mroujps	599
985	male	1926-12-21	bhmokx	djuzbyn	183
986	male	1959-08-14	ovlayi	xzivsjxud	347
987	female	1935-01-01	jquacccxri	cmqrzt	295
988	male	1949-01-18	kuqkmitnc	pmalgos	9
989	female	1974-07-23	lvqqyf	bmamdtmven	503
990	male	1917-07-21	adymxvuvtf	ysurjykg	406
991	female	2008-02-18	uyqqcdcwlu	bzuztadvj	524
992	female	1931-07-25	dapdpqvc	daqeji	186
993	male	1965-08-16	asbifz	evypskqo	231
994	male	1941-12-13	cdqcbtzu	yrkwerku	975
995	male	1920-03-19	qwkznfdi	fzetnig	939
996	female	1922-03-08	wlyqbry	cijqdqmj	296
997	female	2019-11-08	rbxzx	sivkbzqkcu	961
998	female	1980-05-09	ogokpq	mbrzhrlgps	495
999	male	1995-03-13	iiddljecef	suvskqyonr	292
1000	female	1913-11-06	ywftcdb	djvddb	461
\.


--
-- TOC entry 4974 (class 0 OID 17133)
-- Dependencies: 220
-- Data for Name: daily_usage; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.daily_usage (house_id, request_type, request_date, usage_date, total_usage, bill_id) FROM stdin;
1	water	1970-01-01	2020-01-01	1	1
1	water	1970-01-01	2020-01-02	1	1
1	water	1970-01-01	2020-01-03	1	1
1	water	1970-01-01	2020-01-04	1	1
1	water	1970-01-01	2020-01-05	1	1
1	water	1970-01-01	2020-01-06	1	1
1	water	1970-01-01	2020-01-07	1	1
1	water	1970-01-01	2020-01-08	1	1
1	water	1970-01-01	2020-01-09	1	1
1	water	1970-01-01	2020-01-10	1	1
1	water	1970-01-01	2020-01-11	1	1
1	water	1970-01-01	2020-01-12	1	1
1	water	1970-01-01	2020-01-13	1	1
1	water	1970-01-01	2020-01-14	1	1
2	water	1970-01-01	2020-01-01	2	2
2	water	1970-01-01	2020-01-02	2	2
2	water	1970-01-01	2020-01-03	2	2
2	water	1970-01-01	2020-01-04	2	2
2	water	1970-01-01	2020-01-05	2	2
2	water	1970-01-01	2020-01-06	2	2
2	water	1970-01-01	2020-01-07	2	2
2	water	1970-01-01	2020-01-08	2	2
2	water	1970-01-01	2020-01-09	2	2
2	water	1970-01-01	2020-01-10	2	2
2	water	1970-01-01	2020-01-11	2	2
2	water	1970-01-01	2020-01-12	2	2
2	water	1970-01-01	2020-01-13	2	2
2	water	1970-01-01	2020-01-14	2	2
3	water	1970-01-01	2020-01-01	2	3
3	water	1970-01-01	2020-01-02	2	3
3	water	1970-01-01	2020-01-03	2	3
3	water	1970-01-01	2020-01-04	2	3
3	water	1970-01-01	2020-01-05	2	3
3	water	1970-01-01	2020-01-06	2	3
3	water	1970-01-01	2020-01-07	2	3
3	water	1970-01-01	2020-01-08	2	3
3	water	1970-01-01	2020-01-09	2	3
3	water	1970-01-01	2020-01-10	2	3
3	water	1970-01-01	2020-01-11	2	3
3	water	1970-01-01	2020-01-12	2	3
3	water	1970-01-01	2020-01-13	2	3
3	water	1970-01-01	2020-01-14	2	3
4	water	1970-01-01	2020-01-01	1	4
4	water	1970-01-01	2020-01-02	1	4
4	water	1970-01-01	2020-01-03	1	4
4	water	1970-01-01	2020-01-04	1	4
4	water	1970-01-01	2020-01-05	1	4
4	water	1970-01-01	2020-01-06	1	4
4	water	1970-01-01	2020-01-07	1	4
4	water	1970-01-01	2020-01-08	1	4
4	water	1970-01-01	2020-01-09	1	4
4	water	1970-01-01	2020-01-10	1	4
4	water	1970-01-01	2020-01-11	1	4
4	water	1970-01-01	2020-01-12	1	4
4	water	1970-01-01	2020-01-13	1	4
4	water	1970-01-01	2020-01-14	1	4
5	water	1970-01-01	2020-01-01	2	5
5	water	1970-01-01	2020-01-02	2	5
5	water	1970-01-01	2020-01-03	2	5
5	water	1970-01-01	2020-01-04	2	5
5	water	1970-01-01	2020-01-05	2	5
5	water	1970-01-01	2020-01-06	2	5
5	water	1970-01-01	2020-01-07	2	5
5	water	1970-01-01	2020-01-08	2	5
5	water	1970-01-01	2020-01-09	2	5
5	water	1970-01-01	2020-01-10	2	5
5	water	1970-01-01	2020-01-11	2	5
5	water	1970-01-01	2020-01-12	2	5
5	water	1970-01-01	2020-01-13	2	5
5	water	1970-01-01	2020-01-14	2	5
6	water	1970-01-01	2020-01-01	1	6
6	water	1970-01-01	2020-01-02	1	6
6	water	1970-01-01	2020-01-03	1	6
6	water	1970-01-01	2020-01-04	1	6
6	water	1970-01-01	2020-01-05	1	6
6	water	1970-01-01	2020-01-06	1	6
6	water	1970-01-01	2020-01-07	1	6
6	water	1970-01-01	2020-01-08	1	6
6	water	1970-01-01	2020-01-09	1	6
6	water	1970-01-01	2020-01-10	1	6
6	water	1970-01-01	2020-01-11	1	6
6	water	1970-01-01	2020-01-12	1	6
6	water	1970-01-01	2020-01-13	1	6
6	water	1970-01-01	2020-01-14	1	6
7	water	1970-01-01	2020-01-01	2	7
7	water	1970-01-01	2020-01-02	2	7
7	water	1970-01-01	2020-01-03	2	7
7	water	1970-01-01	2020-01-04	2	7
7	water	1970-01-01	2020-01-05	2	7
7	water	1970-01-01	2020-01-06	2	7
7	water	1970-01-01	2020-01-07	2	7
7	water	1970-01-01	2020-01-08	2	7
7	water	1970-01-01	2020-01-09	2	7
7	water	1970-01-01	2020-01-10	2	7
7	water	1970-01-01	2020-01-11	2	7
7	water	1970-01-01	2020-01-12	2	7
7	water	1970-01-01	2020-01-13	2	7
7	water	1970-01-01	2020-01-14	2	7
8	water	1970-01-01	2020-01-01	3	8
8	water	1970-01-01	2020-01-02	3	8
8	water	1970-01-01	2020-01-03	3	8
8	water	1970-01-01	2020-01-04	3	8
8	water	1970-01-01	2020-01-05	3	8
8	water	1970-01-01	2020-01-06	3	8
8	water	1970-01-01	2020-01-07	3	8
8	water	1970-01-01	2020-01-08	3	8
8	water	1970-01-01	2020-01-09	3	8
8	water	1970-01-01	2020-01-10	3	8
8	water	1970-01-01	2020-01-11	3	8
8	water	1970-01-01	2020-01-12	3	8
8	water	1970-01-01	2020-01-13	3	8
8	water	1970-01-01	2020-01-14	3	8
9	water	1970-01-01	2020-01-01	1	9
9	water	1970-01-01	2020-01-02	1	9
9	water	1970-01-01	2020-01-03	1	9
9	water	1970-01-01	2020-01-04	1	9
9	water	1970-01-01	2020-01-05	1	9
9	water	1970-01-01	2020-01-06	1	9
9	water	1970-01-01	2020-01-07	1	9
9	water	1970-01-01	2020-01-08	1	9
9	water	1970-01-01	2020-01-09	1	9
9	water	1970-01-01	2020-01-10	1	9
9	water	1970-01-01	2020-01-11	1	9
9	water	1970-01-01	2020-01-12	1	9
9	water	1970-01-01	2020-01-13	1	9
9	water	1970-01-01	2020-01-14	1	9
10	water	1970-01-01	2020-01-01	2	10
10	water	1970-01-01	2020-01-02	2	10
10	water	1970-01-01	2020-01-03	2	10
10	water	1970-01-01	2020-01-04	2	10
10	water	1970-01-01	2020-01-05	2	10
10	water	1970-01-01	2020-01-06	2	10
10	water	1970-01-01	2020-01-07	2	10
10	water	1970-01-01	2020-01-08	2	10
10	water	1970-01-01	2020-01-09	2	10
10	water	1970-01-01	2020-01-10	2	10
10	water	1970-01-01	2020-01-11	2	10
10	water	1970-01-01	2020-01-12	2	10
10	water	1970-01-01	2020-01-13	2	10
10	water	1970-01-01	2020-01-14	2	10
11	water	1970-01-01	2020-01-01	3	11
11	water	1970-01-01	2020-01-02	3	11
11	water	1970-01-01	2020-01-03	3	11
11	water	1970-01-01	2020-01-04	3	11
11	water	1970-01-01	2020-01-05	3	11
11	water	1970-01-01	2020-01-06	3	11
11	water	1970-01-01	2020-01-07	3	11
11	water	1970-01-01	2020-01-08	3	11
11	water	1970-01-01	2020-01-09	3	11
11	water	1970-01-01	2020-01-10	3	11
11	water	1970-01-01	2020-01-11	3	11
11	water	1970-01-01	2020-01-12	3	11
11	water	1970-01-01	2020-01-13	3	11
11	water	1970-01-01	2020-01-14	3	11
12	water	1970-01-01	2020-01-01	3	12
12	water	1970-01-01	2020-01-02	3	12
12	water	1970-01-01	2020-01-03	3	12
12	water	1970-01-01	2020-01-04	3	12
12	water	1970-01-01	2020-01-05	3	12
12	water	1970-01-01	2020-01-06	3	12
12	water	1970-01-01	2020-01-07	3	12
12	water	1970-01-01	2020-01-08	3	12
12	water	1970-01-01	2020-01-09	3	12
12	water	1970-01-01	2020-01-10	3	12
12	water	1970-01-01	2020-01-11	3	12
12	water	1970-01-01	2020-01-12	3	12
12	water	1970-01-01	2020-01-13	3	12
12	water	1970-01-01	2020-01-14	3	12
13	water	1970-01-01	2020-01-01	3	13
13	water	1970-01-01	2020-01-02	3	13
13	water	1970-01-01	2020-01-03	3	13
13	water	1970-01-01	2020-01-04	3	13
13	water	1970-01-01	2020-01-05	3	13
13	water	1970-01-01	2020-01-06	3	13
13	water	1970-01-01	2020-01-07	3	13
13	water	1970-01-01	2020-01-08	3	13
13	water	1970-01-01	2020-01-09	3	13
13	water	1970-01-01	2020-01-10	3	13
13	water	1970-01-01	2020-01-11	3	13
13	water	1970-01-01	2020-01-12	3	13
13	water	1970-01-01	2020-01-13	3	13
13	water	1970-01-01	2020-01-14	3	13
14	water	1970-01-01	2020-01-01	2	14
14	water	1970-01-01	2020-01-02	2	14
14	water	1970-01-01	2020-01-03	2	14
14	water	1970-01-01	2020-01-04	2	14
14	water	1970-01-01	2020-01-05	2	14
14	water	1970-01-01	2020-01-06	2	14
14	water	1970-01-01	2020-01-07	2	14
14	water	1970-01-01	2020-01-08	2	14
14	water	1970-01-01	2020-01-09	2	14
14	water	1970-01-01	2020-01-10	2	14
14	water	1970-01-01	2020-01-11	2	14
14	water	1970-01-01	2020-01-12	2	14
14	water	1970-01-01	2020-01-13	2	14
14	water	1970-01-01	2020-01-14	2	14
15	water	1970-01-01	2020-01-01	2	15
15	water	1970-01-01	2020-01-02	2	15
15	water	1970-01-01	2020-01-03	2	15
15	water	1970-01-01	2020-01-04	2	15
15	water	1970-01-01	2020-01-05	2	15
15	water	1970-01-01	2020-01-06	2	15
15	water	1970-01-01	2020-01-07	2	15
15	water	1970-01-01	2020-01-08	2	15
15	water	1970-01-01	2020-01-09	2	15
15	water	1970-01-01	2020-01-10	2	15
15	water	1970-01-01	2020-01-11	2	15
15	water	1970-01-01	2020-01-12	2	15
15	water	1970-01-01	2020-01-13	2	15
15	water	1970-01-01	2020-01-14	2	15
16	water	1970-01-01	2020-01-01	1	16
16	water	1970-01-01	2020-01-02	1	16
16	water	1970-01-01	2020-01-03	1	16
16	water	1970-01-01	2020-01-04	1	16
16	water	1970-01-01	2020-01-05	1	16
16	water	1970-01-01	2020-01-06	1	16
16	water	1970-01-01	2020-01-07	1	16
16	water	1970-01-01	2020-01-08	1	16
16	water	1970-01-01	2020-01-09	1	16
16	water	1970-01-01	2020-01-10	1	16
16	water	1970-01-01	2020-01-11	1	16
16	water	1970-01-01	2020-01-12	1	16
16	water	1970-01-01	2020-01-13	1	16
16	water	1970-01-01	2020-01-14	1	16
17	water	1970-01-01	2020-01-01	3	17
17	water	1970-01-01	2020-01-02	3	17
17	water	1970-01-01	2020-01-03	3	17
17	water	1970-01-01	2020-01-04	3	17
17	water	1970-01-01	2020-01-05	3	17
17	water	1970-01-01	2020-01-06	3	17
17	water	1970-01-01	2020-01-07	3	17
17	water	1970-01-01	2020-01-08	3	17
17	water	1970-01-01	2020-01-09	3	17
17	water	1970-01-01	2020-01-10	3	17
17	water	1970-01-01	2020-01-11	3	17
17	water	1970-01-01	2020-01-12	3	17
17	water	1970-01-01	2020-01-13	3	17
17	water	1970-01-01	2020-01-14	3	17
18	water	1970-01-01	2020-01-01	2	18
18	water	1970-01-01	2020-01-02	2	18
18	water	1970-01-01	2020-01-03	2	18
18	water	1970-01-01	2020-01-04	2	18
18	water	1970-01-01	2020-01-05	2	18
18	water	1970-01-01	2020-01-06	2	18
18	water	1970-01-01	2020-01-07	2	18
18	water	1970-01-01	2020-01-08	2	18
18	water	1970-01-01	2020-01-09	2	18
18	water	1970-01-01	2020-01-10	2	18
18	water	1970-01-01	2020-01-11	2	18
18	water	1970-01-01	2020-01-12	2	18
18	water	1970-01-01	2020-01-13	2	18
18	water	1970-01-01	2020-01-14	2	18
19	water	1970-01-01	2020-01-01	2	19
19	water	1970-01-01	2020-01-02	2	19
19	water	1970-01-01	2020-01-03	2	19
19	water	1970-01-01	2020-01-04	2	19
19	water	1970-01-01	2020-01-05	2	19
19	water	1970-01-01	2020-01-06	2	19
19	water	1970-01-01	2020-01-07	2	19
19	water	1970-01-01	2020-01-08	2	19
19	water	1970-01-01	2020-01-09	2	19
19	water	1970-01-01	2020-01-10	2	19
19	water	1970-01-01	2020-01-11	2	19
19	water	1970-01-01	2020-01-12	2	19
19	water	1970-01-01	2020-01-13	2	19
19	water	1970-01-01	2020-01-14	2	19
20	water	1970-01-01	2020-01-01	1	20
20	water	1970-01-01	2020-01-02	1	20
20	water	1970-01-01	2020-01-03	1	20
20	water	1970-01-01	2020-01-04	1	20
20	water	1970-01-01	2020-01-05	1	20
20	water	1970-01-01	2020-01-06	1	20
20	water	1970-01-01	2020-01-07	1	20
20	water	1970-01-01	2020-01-08	1	20
20	water	1970-01-01	2020-01-09	1	20
20	water	1970-01-01	2020-01-10	1	20
20	water	1970-01-01	2020-01-11	1	20
20	water	1970-01-01	2020-01-12	1	20
20	water	1970-01-01	2020-01-13	1	20
20	water	1970-01-01	2020-01-14	1	20
21	water	1970-01-01	2020-01-01	3	21
21	water	1970-01-01	2020-01-02	3	21
21	water	1970-01-01	2020-01-03	3	21
21	water	1970-01-01	2020-01-04	3	21
21	water	1970-01-01	2020-01-05	3	21
21	water	1970-01-01	2020-01-06	3	21
21	water	1970-01-01	2020-01-07	3	21
21	water	1970-01-01	2020-01-08	3	21
21	water	1970-01-01	2020-01-09	3	21
21	water	1970-01-01	2020-01-10	3	21
21	water	1970-01-01	2020-01-11	3	21
21	water	1970-01-01	2020-01-12	3	21
21	water	1970-01-01	2020-01-13	3	21
21	water	1970-01-01	2020-01-14	3	21
22	water	1970-01-01	2020-01-01	2	22
22	water	1970-01-01	2020-01-02	2	22
22	water	1970-01-01	2020-01-03	2	22
22	water	1970-01-01	2020-01-04	2	22
22	water	1970-01-01	2020-01-05	2	22
22	water	1970-01-01	2020-01-06	2	22
22	water	1970-01-01	2020-01-07	2	22
22	water	1970-01-01	2020-01-08	2	22
22	water	1970-01-01	2020-01-09	2	22
22	water	1970-01-01	2020-01-10	2	22
22	water	1970-01-01	2020-01-11	2	22
22	water	1970-01-01	2020-01-12	2	22
22	water	1970-01-01	2020-01-13	2	22
22	water	1970-01-01	2020-01-14	2	22
23	water	1970-01-01	2020-01-01	2	23
23	water	1970-01-01	2020-01-02	2	23
23	water	1970-01-01	2020-01-03	2	23
23	water	1970-01-01	2020-01-04	2	23
23	water	1970-01-01	2020-01-05	2	23
23	water	1970-01-01	2020-01-06	2	23
23	water	1970-01-01	2020-01-07	2	23
23	water	1970-01-01	2020-01-08	2	23
23	water	1970-01-01	2020-01-09	2	23
23	water	1970-01-01	2020-01-10	2	23
23	water	1970-01-01	2020-01-11	2	23
23	water	1970-01-01	2020-01-12	2	23
23	water	1970-01-01	2020-01-13	2	23
23	water	1970-01-01	2020-01-14	2	23
24	water	1970-01-01	2020-01-01	1	24
24	water	1970-01-01	2020-01-02	1	24
24	water	1970-01-01	2020-01-03	1	24
24	water	1970-01-01	2020-01-04	1	24
24	water	1970-01-01	2020-01-05	1	24
24	water	1970-01-01	2020-01-06	1	24
24	water	1970-01-01	2020-01-07	1	24
24	water	1970-01-01	2020-01-08	1	24
24	water	1970-01-01	2020-01-09	1	24
24	water	1970-01-01	2020-01-10	1	24
24	water	1970-01-01	2020-01-11	1	24
24	water	1970-01-01	2020-01-12	1	24
24	water	1970-01-01	2020-01-13	1	24
24	water	1970-01-01	2020-01-14	1	24
25	water	1970-01-01	2020-01-01	3	25
25	water	1970-01-01	2020-01-02	3	25
25	water	1970-01-01	2020-01-03	3	25
25	water	1970-01-01	2020-01-04	3	25
25	water	1970-01-01	2020-01-05	3	25
25	water	1970-01-01	2020-01-06	3	25
25	water	1970-01-01	2020-01-07	3	25
25	water	1970-01-01	2020-01-08	3	25
25	water	1970-01-01	2020-01-09	3	25
25	water	1970-01-01	2020-01-10	3	25
25	water	1970-01-01	2020-01-11	3	25
25	water	1970-01-01	2020-01-12	3	25
25	water	1970-01-01	2020-01-13	3	25
25	water	1970-01-01	2020-01-14	3	25
26	water	1970-01-01	2020-01-01	2	26
26	water	1970-01-01	2020-01-02	2	26
26	water	1970-01-01	2020-01-03	2	26
26	water	1970-01-01	2020-01-04	2	26
26	water	1970-01-01	2020-01-05	2	26
26	water	1970-01-01	2020-01-06	2	26
26	water	1970-01-01	2020-01-07	2	26
26	water	1970-01-01	2020-01-08	2	26
26	water	1970-01-01	2020-01-09	2	26
26	water	1970-01-01	2020-01-10	2	26
26	water	1970-01-01	2020-01-11	2	26
26	water	1970-01-01	2020-01-12	2	26
26	water	1970-01-01	2020-01-13	2	26
26	water	1970-01-01	2020-01-14	2	26
27	water	1970-01-01	2020-01-01	1	27
27	water	1970-01-01	2020-01-02	1	27
27	water	1970-01-01	2020-01-03	1	27
27	water	1970-01-01	2020-01-04	1	27
27	water	1970-01-01	2020-01-05	1	27
27	water	1970-01-01	2020-01-06	1	27
27	water	1970-01-01	2020-01-07	1	27
27	water	1970-01-01	2020-01-08	1	27
27	water	1970-01-01	2020-01-09	1	27
27	water	1970-01-01	2020-01-10	1	27
27	water	1970-01-01	2020-01-11	1	27
27	water	1970-01-01	2020-01-12	1	27
27	water	1970-01-01	2020-01-13	1	27
27	water	1970-01-01	2020-01-14	1	27
28	water	1970-01-01	2020-01-01	2	28
28	water	1970-01-01	2020-01-02	2	28
28	water	1970-01-01	2020-01-03	2	28
28	water	1970-01-01	2020-01-04	2	28
28	water	1970-01-01	2020-01-05	2	28
28	water	1970-01-01	2020-01-06	2	28
28	water	1970-01-01	2020-01-07	2	28
28	water	1970-01-01	2020-01-08	2	28
28	water	1970-01-01	2020-01-09	2	28
28	water	1970-01-01	2020-01-10	2	28
28	water	1970-01-01	2020-01-11	2	28
28	water	1970-01-01	2020-01-12	2	28
28	water	1970-01-01	2020-01-13	2	28
28	water	1970-01-01	2020-01-14	2	28
29	water	1970-01-01	2020-01-01	1	29
29	water	1970-01-01	2020-01-02	1	29
29	water	1970-01-01	2020-01-03	1	29
29	water	1970-01-01	2020-01-04	1	29
29	water	1970-01-01	2020-01-05	1	29
29	water	1970-01-01	2020-01-06	1	29
29	water	1970-01-01	2020-01-07	1	29
29	water	1970-01-01	2020-01-08	1	29
29	water	1970-01-01	2020-01-09	1	29
29	water	1970-01-01	2020-01-10	1	29
29	water	1970-01-01	2020-01-11	1	29
29	water	1970-01-01	2020-01-12	1	29
29	water	1970-01-01	2020-01-13	1	29
29	water	1970-01-01	2020-01-14	1	29
30	water	1970-01-01	2020-01-01	3	30
30	water	1970-01-01	2020-01-02	3	30
30	water	1970-01-01	2020-01-03	3	30
30	water	1970-01-01	2020-01-04	3	30
30	water	1970-01-01	2020-01-05	3	30
30	water	1970-01-01	2020-01-06	3	30
30	water	1970-01-01	2020-01-07	3	30
30	water	1970-01-01	2020-01-08	3	30
30	water	1970-01-01	2020-01-09	3	30
30	water	1970-01-01	2020-01-10	3	30
30	water	1970-01-01	2020-01-11	3	30
30	water	1970-01-01	2020-01-12	3	30
30	water	1970-01-01	2020-01-13	3	30
30	water	1970-01-01	2020-01-14	3	30
31	water	1970-01-01	2020-01-01	2	31
31	water	1970-01-01	2020-01-02	2	31
31	water	1970-01-01	2020-01-03	2	31
31	water	1970-01-01	2020-01-04	2	31
31	water	1970-01-01	2020-01-05	2	31
31	water	1970-01-01	2020-01-06	2	31
31	water	1970-01-01	2020-01-07	2	31
31	water	1970-01-01	2020-01-08	2	31
31	water	1970-01-01	2020-01-09	2	31
31	water	1970-01-01	2020-01-10	2	31
31	water	1970-01-01	2020-01-11	2	31
31	water	1970-01-01	2020-01-12	2	31
31	water	1970-01-01	2020-01-13	2	31
31	water	1970-01-01	2020-01-14	2	31
32	water	1970-01-01	2020-01-01	1	32
32	water	1970-01-01	2020-01-02	1	32
32	water	1970-01-01	2020-01-03	1	32
32	water	1970-01-01	2020-01-04	1	32
32	water	1970-01-01	2020-01-05	1	32
32	water	1970-01-01	2020-01-06	1	32
32	water	1970-01-01	2020-01-07	1	32
32	water	1970-01-01	2020-01-08	1	32
32	water	1970-01-01	2020-01-09	1	32
32	water	1970-01-01	2020-01-10	1	32
32	water	1970-01-01	2020-01-11	1	32
32	water	1970-01-01	2020-01-12	1	32
32	water	1970-01-01	2020-01-13	1	32
32	water	1970-01-01	2020-01-14	1	32
33	water	1970-01-01	2020-01-01	2	33
33	water	1970-01-01	2020-01-02	2	33
33	water	1970-01-01	2020-01-03	2	33
33	water	1970-01-01	2020-01-04	2	33
33	water	1970-01-01	2020-01-05	2	33
33	water	1970-01-01	2020-01-06	2	33
33	water	1970-01-01	2020-01-07	2	33
33	water	1970-01-01	2020-01-08	2	33
33	water	1970-01-01	2020-01-09	2	33
33	water	1970-01-01	2020-01-10	2	33
33	water	1970-01-01	2020-01-11	2	33
33	water	1970-01-01	2020-01-12	2	33
33	water	1970-01-01	2020-01-13	2	33
33	water	1970-01-01	2020-01-14	2	33
34	water	1970-01-01	2020-01-01	1	34
34	water	1970-01-01	2020-01-02	1	34
34	water	1970-01-01	2020-01-03	1	34
34	water	1970-01-01	2020-01-04	1	34
34	water	1970-01-01	2020-01-05	1	34
34	water	1970-01-01	2020-01-06	1	34
34	water	1970-01-01	2020-01-07	1	34
34	water	1970-01-01	2020-01-08	1	34
34	water	1970-01-01	2020-01-09	1	34
34	water	1970-01-01	2020-01-10	1	34
34	water	1970-01-01	2020-01-11	1	34
34	water	1970-01-01	2020-01-12	1	34
34	water	1970-01-01	2020-01-13	1	34
34	water	1970-01-01	2020-01-14	1	34
35	water	1970-01-01	2020-01-01	1	35
35	water	1970-01-01	2020-01-02	1	35
35	water	1970-01-01	2020-01-03	1	35
35	water	1970-01-01	2020-01-04	1	35
35	water	1970-01-01	2020-01-05	1	35
35	water	1970-01-01	2020-01-06	1	35
35	water	1970-01-01	2020-01-07	1	35
35	water	1970-01-01	2020-01-08	1	35
35	water	1970-01-01	2020-01-09	1	35
35	water	1970-01-01	2020-01-10	1	35
35	water	1970-01-01	2020-01-11	1	35
35	water	1970-01-01	2020-01-12	1	35
35	water	1970-01-01	2020-01-13	1	35
35	water	1970-01-01	2020-01-14	1	35
36	water	1970-01-01	2020-01-01	2	36
36	water	1970-01-01	2020-01-02	2	36
36	water	1970-01-01	2020-01-03	2	36
36	water	1970-01-01	2020-01-04	2	36
36	water	1970-01-01	2020-01-05	2	36
36	water	1970-01-01	2020-01-06	2	36
36	water	1970-01-01	2020-01-07	2	36
36	water	1970-01-01	2020-01-08	2	36
36	water	1970-01-01	2020-01-09	2	36
36	water	1970-01-01	2020-01-10	2	36
36	water	1970-01-01	2020-01-11	2	36
36	water	1970-01-01	2020-01-12	2	36
36	water	1970-01-01	2020-01-13	2	36
36	water	1970-01-01	2020-01-14	2	36
37	water	1970-01-01	2020-01-01	3	37
37	water	1970-01-01	2020-01-02	3	37
37	water	1970-01-01	2020-01-03	3	37
37	water	1970-01-01	2020-01-04	3	37
37	water	1970-01-01	2020-01-05	3	37
37	water	1970-01-01	2020-01-06	3	37
37	water	1970-01-01	2020-01-07	3	37
37	water	1970-01-01	2020-01-08	3	37
37	water	1970-01-01	2020-01-09	3	37
37	water	1970-01-01	2020-01-10	3	37
37	water	1970-01-01	2020-01-11	3	37
37	water	1970-01-01	2020-01-12	3	37
37	water	1970-01-01	2020-01-13	3	37
37	water	1970-01-01	2020-01-14	3	37
38	water	1970-01-01	2020-01-01	3	38
38	water	1970-01-01	2020-01-02	3	38
38	water	1970-01-01	2020-01-03	3	38
38	water	1970-01-01	2020-01-04	3	38
38	water	1970-01-01	2020-01-05	3	38
38	water	1970-01-01	2020-01-06	3	38
38	water	1970-01-01	2020-01-07	3	38
38	water	1970-01-01	2020-01-08	3	38
38	water	1970-01-01	2020-01-09	3	38
38	water	1970-01-01	2020-01-10	3	38
38	water	1970-01-01	2020-01-11	3	38
38	water	1970-01-01	2020-01-12	3	38
38	water	1970-01-01	2020-01-13	3	38
38	water	1970-01-01	2020-01-14	3	38
39	water	1970-01-01	2020-01-01	3	39
39	water	1970-01-01	2020-01-02	3	39
39	water	1970-01-01	2020-01-03	3	39
39	water	1970-01-01	2020-01-04	3	39
39	water	1970-01-01	2020-01-05	3	39
39	water	1970-01-01	2020-01-06	3	39
39	water	1970-01-01	2020-01-07	3	39
39	water	1970-01-01	2020-01-08	3	39
39	water	1970-01-01	2020-01-09	3	39
39	water	1970-01-01	2020-01-10	3	39
39	water	1970-01-01	2020-01-11	3	39
39	water	1970-01-01	2020-01-12	3	39
39	water	1970-01-01	2020-01-13	3	39
39	water	1970-01-01	2020-01-14	3	39
40	water	1970-01-01	2020-01-01	3	40
40	water	1970-01-01	2020-01-02	3	40
40	water	1970-01-01	2020-01-03	3	40
40	water	1970-01-01	2020-01-04	3	40
40	water	1970-01-01	2020-01-05	3	40
40	water	1970-01-01	2020-01-06	3	40
40	water	1970-01-01	2020-01-07	3	40
40	water	1970-01-01	2020-01-08	3	40
40	water	1970-01-01	2020-01-09	3	40
40	water	1970-01-01	2020-01-10	3	40
40	water	1970-01-01	2020-01-11	3	40
40	water	1970-01-01	2020-01-12	3	40
40	water	1970-01-01	2020-01-13	3	40
40	water	1970-01-01	2020-01-14	3	40
41	water	1970-01-01	2020-01-01	3	41
41	water	1970-01-01	2020-01-02	3	41
41	water	1970-01-01	2020-01-03	3	41
41	water	1970-01-01	2020-01-04	3	41
41	water	1970-01-01	2020-01-05	3	41
41	water	1970-01-01	2020-01-06	3	41
41	water	1970-01-01	2020-01-07	3	41
41	water	1970-01-01	2020-01-08	3	41
41	water	1970-01-01	2020-01-09	3	41
41	water	1970-01-01	2020-01-10	3	41
41	water	1970-01-01	2020-01-11	3	41
41	water	1970-01-01	2020-01-12	3	41
41	water	1970-01-01	2020-01-13	3	41
41	water	1970-01-01	2020-01-14	3	41
42	water	1970-01-01	2020-01-01	2	42
42	water	1970-01-01	2020-01-02	2	42
42	water	1970-01-01	2020-01-03	2	42
42	water	1970-01-01	2020-01-04	2	42
42	water	1970-01-01	2020-01-05	2	42
42	water	1970-01-01	2020-01-06	2	42
42	water	1970-01-01	2020-01-07	2	42
42	water	1970-01-01	2020-01-08	2	42
42	water	1970-01-01	2020-01-09	2	42
42	water	1970-01-01	2020-01-10	2	42
42	water	1970-01-01	2020-01-11	2	42
42	water	1970-01-01	2020-01-12	2	42
42	water	1970-01-01	2020-01-13	2	42
42	water	1970-01-01	2020-01-14	2	42
43	water	1970-01-01	2020-01-01	3	43
43	water	1970-01-01	2020-01-02	3	43
43	water	1970-01-01	2020-01-03	3	43
43	water	1970-01-01	2020-01-04	3	43
43	water	1970-01-01	2020-01-05	3	43
43	water	1970-01-01	2020-01-06	3	43
43	water	1970-01-01	2020-01-07	3	43
43	water	1970-01-01	2020-01-08	3	43
43	water	1970-01-01	2020-01-09	3	43
43	water	1970-01-01	2020-01-10	3	43
43	water	1970-01-01	2020-01-11	3	43
43	water	1970-01-01	2020-01-12	3	43
43	water	1970-01-01	2020-01-13	3	43
43	water	1970-01-01	2020-01-14	3	43
44	water	1970-01-01	2020-01-01	1	44
44	water	1970-01-01	2020-01-02	1	44
44	water	1970-01-01	2020-01-03	1	44
44	water	1970-01-01	2020-01-04	1	44
44	water	1970-01-01	2020-01-05	1	44
44	water	1970-01-01	2020-01-06	1	44
44	water	1970-01-01	2020-01-07	1	44
44	water	1970-01-01	2020-01-08	1	44
44	water	1970-01-01	2020-01-09	1	44
44	water	1970-01-01	2020-01-10	1	44
44	water	1970-01-01	2020-01-11	1	44
44	water	1970-01-01	2020-01-12	1	44
44	water	1970-01-01	2020-01-13	1	44
44	water	1970-01-01	2020-01-14	1	44
45	water	1970-01-01	2020-01-01	1	45
45	water	1970-01-01	2020-01-02	1	45
45	water	1970-01-01	2020-01-03	1	45
45	water	1970-01-01	2020-01-04	1	45
45	water	1970-01-01	2020-01-05	1	45
45	water	1970-01-01	2020-01-06	1	45
45	water	1970-01-01	2020-01-07	1	45
45	water	1970-01-01	2020-01-08	1	45
45	water	1970-01-01	2020-01-09	1	45
45	water	1970-01-01	2020-01-10	1	45
45	water	1970-01-01	2020-01-11	1	45
45	water	1970-01-01	2020-01-12	1	45
45	water	1970-01-01	2020-01-13	1	45
45	water	1970-01-01	2020-01-14	1	45
46	water	1970-01-01	2020-01-01	2	46
46	water	1970-01-01	2020-01-02	2	46
46	water	1970-01-01	2020-01-03	2	46
46	water	1970-01-01	2020-01-04	2	46
46	water	1970-01-01	2020-01-05	2	46
46	water	1970-01-01	2020-01-06	2	46
46	water	1970-01-01	2020-01-07	2	46
46	water	1970-01-01	2020-01-08	2	46
46	water	1970-01-01	2020-01-09	2	46
46	water	1970-01-01	2020-01-10	2	46
46	water	1970-01-01	2020-01-11	2	46
46	water	1970-01-01	2020-01-12	2	46
46	water	1970-01-01	2020-01-13	2	46
46	water	1970-01-01	2020-01-14	2	46
47	water	1970-01-01	2020-01-01	2	47
47	water	1970-01-01	2020-01-02	2	47
47	water	1970-01-01	2020-01-03	2	47
47	water	1970-01-01	2020-01-04	2	47
47	water	1970-01-01	2020-01-05	2	47
47	water	1970-01-01	2020-01-06	2	47
47	water	1970-01-01	2020-01-07	2	47
47	water	1970-01-01	2020-01-08	2	47
47	water	1970-01-01	2020-01-09	2	47
47	water	1970-01-01	2020-01-10	2	47
47	water	1970-01-01	2020-01-11	2	47
47	water	1970-01-01	2020-01-12	2	47
47	water	1970-01-01	2020-01-13	2	47
47	water	1970-01-01	2020-01-14	2	47
48	water	1970-01-01	2020-01-01	3	48
48	water	1970-01-01	2020-01-02	3	48
48	water	1970-01-01	2020-01-03	3	48
48	water	1970-01-01	2020-01-04	3	48
48	water	1970-01-01	2020-01-05	3	48
48	water	1970-01-01	2020-01-06	3	48
48	water	1970-01-01	2020-01-07	3	48
48	water	1970-01-01	2020-01-08	3	48
48	water	1970-01-01	2020-01-09	3	48
48	water	1970-01-01	2020-01-10	3	48
48	water	1970-01-01	2020-01-11	3	48
48	water	1970-01-01	2020-01-12	3	48
48	water	1970-01-01	2020-01-13	3	48
48	water	1970-01-01	2020-01-14	3	48
49	water	1970-01-01	2020-01-01	1	49
49	water	1970-01-01	2020-01-02	1	49
49	water	1970-01-01	2020-01-03	1	49
49	water	1970-01-01	2020-01-04	1	49
49	water	1970-01-01	2020-01-05	1	49
49	water	1970-01-01	2020-01-06	1	49
49	water	1970-01-01	2020-01-07	1	49
49	water	1970-01-01	2020-01-08	1	49
49	water	1970-01-01	2020-01-09	1	49
49	water	1970-01-01	2020-01-10	1	49
49	water	1970-01-01	2020-01-11	1	49
49	water	1970-01-01	2020-01-12	1	49
49	water	1970-01-01	2020-01-13	1	49
49	water	1970-01-01	2020-01-14	1	49
50	water	1970-01-01	2020-01-01	3	50
50	water	1970-01-01	2020-01-02	3	50
50	water	1970-01-01	2020-01-03	3	50
50	water	1970-01-01	2020-01-04	3	50
50	water	1970-01-01	2020-01-05	3	50
50	water	1970-01-01	2020-01-06	3	50
50	water	1970-01-01	2020-01-07	3	50
50	water	1970-01-01	2020-01-08	3	50
50	water	1970-01-01	2020-01-09	3	50
50	water	1970-01-01	2020-01-10	3	50
50	water	1970-01-01	2020-01-11	3	50
50	water	1970-01-01	2020-01-12	3	50
50	water	1970-01-01	2020-01-13	3	50
50	water	1970-01-01	2020-01-14	3	50
51	water	1970-01-01	2020-01-01	3	51
51	water	1970-01-01	2020-01-02	3	51
51	water	1970-01-01	2020-01-03	3	51
51	water	1970-01-01	2020-01-04	3	51
51	water	1970-01-01	2020-01-05	3	51
51	water	1970-01-01	2020-01-06	3	51
51	water	1970-01-01	2020-01-07	3	51
51	water	1970-01-01	2020-01-08	3	51
51	water	1970-01-01	2020-01-09	3	51
51	water	1970-01-01	2020-01-10	3	51
51	water	1970-01-01	2020-01-11	3	51
51	water	1970-01-01	2020-01-12	3	51
51	water	1970-01-01	2020-01-13	3	51
51	water	1970-01-01	2020-01-14	3	51
52	water	1970-01-01	2020-01-01	1	52
52	water	1970-01-01	2020-01-02	1	52
52	water	1970-01-01	2020-01-03	1	52
52	water	1970-01-01	2020-01-04	1	52
52	water	1970-01-01	2020-01-05	1	52
52	water	1970-01-01	2020-01-06	1	52
52	water	1970-01-01	2020-01-07	1	52
52	water	1970-01-01	2020-01-08	1	52
52	water	1970-01-01	2020-01-09	1	52
52	water	1970-01-01	2020-01-10	1	52
52	water	1970-01-01	2020-01-11	1	52
52	water	1970-01-01	2020-01-12	1	52
52	water	1970-01-01	2020-01-13	1	52
52	water	1970-01-01	2020-01-14	1	52
53	water	1970-01-01	2020-01-01	1	53
53	water	1970-01-01	2020-01-02	1	53
53	water	1970-01-01	2020-01-03	1	53
53	water	1970-01-01	2020-01-04	1	53
53	water	1970-01-01	2020-01-05	1	53
53	water	1970-01-01	2020-01-06	1	53
53	water	1970-01-01	2020-01-07	1	53
53	water	1970-01-01	2020-01-08	1	53
53	water	1970-01-01	2020-01-09	1	53
53	water	1970-01-01	2020-01-10	1	53
53	water	1970-01-01	2020-01-11	1	53
53	water	1970-01-01	2020-01-12	1	53
53	water	1970-01-01	2020-01-13	1	53
53	water	1970-01-01	2020-01-14	1	53
54	water	1970-01-01	2020-01-01	3	54
54	water	1970-01-01	2020-01-02	3	54
54	water	1970-01-01	2020-01-03	3	54
54	water	1970-01-01	2020-01-04	3	54
54	water	1970-01-01	2020-01-05	3	54
54	water	1970-01-01	2020-01-06	3	54
54	water	1970-01-01	2020-01-07	3	54
54	water	1970-01-01	2020-01-08	3	54
54	water	1970-01-01	2020-01-09	3	54
54	water	1970-01-01	2020-01-10	3	54
54	water	1970-01-01	2020-01-11	3	54
54	water	1970-01-01	2020-01-12	3	54
54	water	1970-01-01	2020-01-13	3	54
54	water	1970-01-01	2020-01-14	3	54
55	water	1970-01-01	2020-01-01	1	55
55	water	1970-01-01	2020-01-02	1	55
55	water	1970-01-01	2020-01-03	1	55
55	water	1970-01-01	2020-01-04	1	55
55	water	1970-01-01	2020-01-05	1	55
55	water	1970-01-01	2020-01-06	1	55
55	water	1970-01-01	2020-01-07	1	55
55	water	1970-01-01	2020-01-08	1	55
55	water	1970-01-01	2020-01-09	1	55
55	water	1970-01-01	2020-01-10	1	55
55	water	1970-01-01	2020-01-11	1	55
55	water	1970-01-01	2020-01-12	1	55
55	water	1970-01-01	2020-01-13	1	55
55	water	1970-01-01	2020-01-14	1	55
56	water	1970-01-01	2020-01-01	3	56
56	water	1970-01-01	2020-01-02	3	56
56	water	1970-01-01	2020-01-03	3	56
56	water	1970-01-01	2020-01-04	3	56
56	water	1970-01-01	2020-01-05	3	56
56	water	1970-01-01	2020-01-06	3	56
56	water	1970-01-01	2020-01-07	3	56
56	water	1970-01-01	2020-01-08	3	56
56	water	1970-01-01	2020-01-09	3	56
56	water	1970-01-01	2020-01-10	3	56
56	water	1970-01-01	2020-01-11	3	56
56	water	1970-01-01	2020-01-12	3	56
56	water	1970-01-01	2020-01-13	3	56
56	water	1970-01-01	2020-01-14	3	56
57	water	1970-01-01	2020-01-01	1	57
57	water	1970-01-01	2020-01-02	1	57
57	water	1970-01-01	2020-01-03	1	57
57	water	1970-01-01	2020-01-04	1	57
57	water	1970-01-01	2020-01-05	1	57
57	water	1970-01-01	2020-01-06	1	57
57	water	1970-01-01	2020-01-07	1	57
57	water	1970-01-01	2020-01-08	1	57
57	water	1970-01-01	2020-01-09	1	57
57	water	1970-01-01	2020-01-10	1	57
57	water	1970-01-01	2020-01-11	1	57
57	water	1970-01-01	2020-01-12	1	57
57	water	1970-01-01	2020-01-13	1	57
57	water	1970-01-01	2020-01-14	1	57
58	water	1970-01-01	2020-01-01	1	58
58	water	1970-01-01	2020-01-02	1	58
58	water	1970-01-01	2020-01-03	1	58
58	water	1970-01-01	2020-01-04	1	58
58	water	1970-01-01	2020-01-05	1	58
58	water	1970-01-01	2020-01-06	1	58
58	water	1970-01-01	2020-01-07	1	58
58	water	1970-01-01	2020-01-08	1	58
58	water	1970-01-01	2020-01-09	1	58
58	water	1970-01-01	2020-01-10	1	58
58	water	1970-01-01	2020-01-11	1	58
58	water	1970-01-01	2020-01-12	1	58
58	water	1970-01-01	2020-01-13	1	58
58	water	1970-01-01	2020-01-14	1	58
59	water	1970-01-01	2020-01-01	3	59
59	water	1970-01-01	2020-01-02	3	59
59	water	1970-01-01	2020-01-03	3	59
59	water	1970-01-01	2020-01-04	3	59
59	water	1970-01-01	2020-01-05	3	59
59	water	1970-01-01	2020-01-06	3	59
59	water	1970-01-01	2020-01-07	3	59
59	water	1970-01-01	2020-01-08	3	59
59	water	1970-01-01	2020-01-09	3	59
59	water	1970-01-01	2020-01-10	3	59
59	water	1970-01-01	2020-01-11	3	59
59	water	1970-01-01	2020-01-12	3	59
59	water	1970-01-01	2020-01-13	3	59
59	water	1970-01-01	2020-01-14	3	59
60	water	1970-01-01	2020-01-01	2	60
60	water	1970-01-01	2020-01-02	2	60
60	water	1970-01-01	2020-01-03	2	60
60	water	1970-01-01	2020-01-04	2	60
60	water	1970-01-01	2020-01-05	2	60
60	water	1970-01-01	2020-01-06	2	60
60	water	1970-01-01	2020-01-07	2	60
60	water	1970-01-01	2020-01-08	2	60
60	water	1970-01-01	2020-01-09	2	60
60	water	1970-01-01	2020-01-10	2	60
60	water	1970-01-01	2020-01-11	2	60
60	water	1970-01-01	2020-01-12	2	60
60	water	1970-01-01	2020-01-13	2	60
60	water	1970-01-01	2020-01-14	2	60
61	water	1970-01-01	2020-01-01	1	61
61	water	1970-01-01	2020-01-02	1	61
61	water	1970-01-01	2020-01-03	1	61
61	water	1970-01-01	2020-01-04	1	61
61	water	1970-01-01	2020-01-05	1	61
61	water	1970-01-01	2020-01-06	1	61
61	water	1970-01-01	2020-01-07	1	61
61	water	1970-01-01	2020-01-08	1	61
61	water	1970-01-01	2020-01-09	1	61
61	water	1970-01-01	2020-01-10	1	61
61	water	1970-01-01	2020-01-11	1	61
61	water	1970-01-01	2020-01-12	1	61
61	water	1970-01-01	2020-01-13	1	61
61	water	1970-01-01	2020-01-14	1	61
62	water	1970-01-01	2020-01-01	2	62
62	water	1970-01-01	2020-01-02	2	62
62	water	1970-01-01	2020-01-03	2	62
62	water	1970-01-01	2020-01-04	2	62
62	water	1970-01-01	2020-01-05	2	62
62	water	1970-01-01	2020-01-06	2	62
62	water	1970-01-01	2020-01-07	2	62
62	water	1970-01-01	2020-01-08	2	62
62	water	1970-01-01	2020-01-09	2	62
62	water	1970-01-01	2020-01-10	2	62
62	water	1970-01-01	2020-01-11	2	62
62	water	1970-01-01	2020-01-12	2	62
62	water	1970-01-01	2020-01-13	2	62
62	water	1970-01-01	2020-01-14	2	62
63	water	1970-01-01	2020-01-01	2	63
63	water	1970-01-01	2020-01-02	2	63
63	water	1970-01-01	2020-01-03	2	63
63	water	1970-01-01	2020-01-04	2	63
63	water	1970-01-01	2020-01-05	2	63
63	water	1970-01-01	2020-01-06	2	63
63	water	1970-01-01	2020-01-07	2	63
63	water	1970-01-01	2020-01-08	2	63
63	water	1970-01-01	2020-01-09	2	63
63	water	1970-01-01	2020-01-10	2	63
63	water	1970-01-01	2020-01-11	2	63
63	water	1970-01-01	2020-01-12	2	63
63	water	1970-01-01	2020-01-13	2	63
63	water	1970-01-01	2020-01-14	2	63
64	water	1970-01-01	2020-01-01	3	64
64	water	1970-01-01	2020-01-02	3	64
64	water	1970-01-01	2020-01-03	3	64
64	water	1970-01-01	2020-01-04	3	64
64	water	1970-01-01	2020-01-05	3	64
64	water	1970-01-01	2020-01-06	3	64
64	water	1970-01-01	2020-01-07	3	64
64	water	1970-01-01	2020-01-08	3	64
64	water	1970-01-01	2020-01-09	3	64
64	water	1970-01-01	2020-01-10	3	64
64	water	1970-01-01	2020-01-11	3	64
64	water	1970-01-01	2020-01-12	3	64
64	water	1970-01-01	2020-01-13	3	64
64	water	1970-01-01	2020-01-14	3	64
65	water	1970-01-01	2020-01-01	1	65
65	water	1970-01-01	2020-01-02	1	65
65	water	1970-01-01	2020-01-03	1	65
65	water	1970-01-01	2020-01-04	1	65
65	water	1970-01-01	2020-01-05	1	65
65	water	1970-01-01	2020-01-06	1	65
65	water	1970-01-01	2020-01-07	1	65
65	water	1970-01-01	2020-01-08	1	65
65	water	1970-01-01	2020-01-09	1	65
65	water	1970-01-01	2020-01-10	1	65
65	water	1970-01-01	2020-01-11	1	65
65	water	1970-01-01	2020-01-12	1	65
65	water	1970-01-01	2020-01-13	1	65
65	water	1970-01-01	2020-01-14	1	65
66	water	1970-01-01	2020-01-01	2	66
66	water	1970-01-01	2020-01-02	2	66
66	water	1970-01-01	2020-01-03	2	66
66	water	1970-01-01	2020-01-04	2	66
66	water	1970-01-01	2020-01-05	2	66
66	water	1970-01-01	2020-01-06	2	66
66	water	1970-01-01	2020-01-07	2	66
66	water	1970-01-01	2020-01-08	2	66
66	water	1970-01-01	2020-01-09	2	66
66	water	1970-01-01	2020-01-10	2	66
66	water	1970-01-01	2020-01-11	2	66
66	water	1970-01-01	2020-01-12	2	66
66	water	1970-01-01	2020-01-13	2	66
66	water	1970-01-01	2020-01-14	2	66
67	water	1970-01-01	2020-01-01	1	67
67	water	1970-01-01	2020-01-02	1	67
67	water	1970-01-01	2020-01-03	1	67
67	water	1970-01-01	2020-01-04	1	67
67	water	1970-01-01	2020-01-05	1	67
67	water	1970-01-01	2020-01-06	1	67
67	water	1970-01-01	2020-01-07	1	67
67	water	1970-01-01	2020-01-08	1	67
67	water	1970-01-01	2020-01-09	1	67
67	water	1970-01-01	2020-01-10	1	67
67	water	1970-01-01	2020-01-11	1	67
67	water	1970-01-01	2020-01-12	1	67
67	water	1970-01-01	2020-01-13	1	67
67	water	1970-01-01	2020-01-14	1	67
68	water	1970-01-01	2020-01-01	1	68
68	water	1970-01-01	2020-01-02	1	68
68	water	1970-01-01	2020-01-03	1	68
68	water	1970-01-01	2020-01-04	1	68
68	water	1970-01-01	2020-01-05	1	68
68	water	1970-01-01	2020-01-06	1	68
68	water	1970-01-01	2020-01-07	1	68
68	water	1970-01-01	2020-01-08	1	68
68	water	1970-01-01	2020-01-09	1	68
68	water	1970-01-01	2020-01-10	1	68
68	water	1970-01-01	2020-01-11	1	68
68	water	1970-01-01	2020-01-12	1	68
68	water	1970-01-01	2020-01-13	1	68
68	water	1970-01-01	2020-01-14	1	68
69	water	1970-01-01	2020-01-01	1	69
69	water	1970-01-01	2020-01-02	1	69
69	water	1970-01-01	2020-01-03	1	69
69	water	1970-01-01	2020-01-04	1	69
69	water	1970-01-01	2020-01-05	1	69
69	water	1970-01-01	2020-01-06	1	69
69	water	1970-01-01	2020-01-07	1	69
69	water	1970-01-01	2020-01-08	1	69
69	water	1970-01-01	2020-01-09	1	69
69	water	1970-01-01	2020-01-10	1	69
69	water	1970-01-01	2020-01-11	1	69
69	water	1970-01-01	2020-01-12	1	69
69	water	1970-01-01	2020-01-13	1	69
69	water	1970-01-01	2020-01-14	1	69
70	water	1970-01-01	2020-01-01	2	70
70	water	1970-01-01	2020-01-02	2	70
70	water	1970-01-01	2020-01-03	2	70
70	water	1970-01-01	2020-01-04	2	70
70	water	1970-01-01	2020-01-05	2	70
70	water	1970-01-01	2020-01-06	2	70
70	water	1970-01-01	2020-01-07	2	70
70	water	1970-01-01	2020-01-08	2	70
70	water	1970-01-01	2020-01-09	2	70
70	water	1970-01-01	2020-01-10	2	70
70	water	1970-01-01	2020-01-11	2	70
70	water	1970-01-01	2020-01-12	2	70
70	water	1970-01-01	2020-01-13	2	70
70	water	1970-01-01	2020-01-14	2	70
71	water	1970-01-01	2020-01-01	1	71
71	water	1970-01-01	2020-01-02	1	71
71	water	1970-01-01	2020-01-03	1	71
71	water	1970-01-01	2020-01-04	1	71
71	water	1970-01-01	2020-01-05	1	71
71	water	1970-01-01	2020-01-06	1	71
71	water	1970-01-01	2020-01-07	1	71
71	water	1970-01-01	2020-01-08	1	71
71	water	1970-01-01	2020-01-09	1	71
71	water	1970-01-01	2020-01-10	1	71
71	water	1970-01-01	2020-01-11	1	71
71	water	1970-01-01	2020-01-12	1	71
71	water	1970-01-01	2020-01-13	1	71
71	water	1970-01-01	2020-01-14	1	71
72	water	1970-01-01	2020-01-01	1	72
72	water	1970-01-01	2020-01-02	1	72
72	water	1970-01-01	2020-01-03	1	72
72	water	1970-01-01	2020-01-04	1	72
72	water	1970-01-01	2020-01-05	1	72
72	water	1970-01-01	2020-01-06	1	72
72	water	1970-01-01	2020-01-07	1	72
72	water	1970-01-01	2020-01-08	1	72
72	water	1970-01-01	2020-01-09	1	72
72	water	1970-01-01	2020-01-10	1	72
72	water	1970-01-01	2020-01-11	1	72
72	water	1970-01-01	2020-01-12	1	72
72	water	1970-01-01	2020-01-13	1	72
72	water	1970-01-01	2020-01-14	1	72
73	water	1970-01-01	2020-01-01	2	73
73	water	1970-01-01	2020-01-02	2	73
73	water	1970-01-01	2020-01-03	2	73
73	water	1970-01-01	2020-01-04	2	73
73	water	1970-01-01	2020-01-05	2	73
73	water	1970-01-01	2020-01-06	2	73
73	water	1970-01-01	2020-01-07	2	73
73	water	1970-01-01	2020-01-08	2	73
73	water	1970-01-01	2020-01-09	2	73
73	water	1970-01-01	2020-01-10	2	73
73	water	1970-01-01	2020-01-11	2	73
73	water	1970-01-01	2020-01-12	2	73
73	water	1970-01-01	2020-01-13	2	73
73	water	1970-01-01	2020-01-14	2	73
74	water	1970-01-01	2020-01-01	3	74
74	water	1970-01-01	2020-01-02	3	74
74	water	1970-01-01	2020-01-03	3	74
74	water	1970-01-01	2020-01-04	3	74
74	water	1970-01-01	2020-01-05	3	74
74	water	1970-01-01	2020-01-06	3	74
74	water	1970-01-01	2020-01-07	3	74
74	water	1970-01-01	2020-01-08	3	74
74	water	1970-01-01	2020-01-09	3	74
74	water	1970-01-01	2020-01-10	3	74
74	water	1970-01-01	2020-01-11	3	74
74	water	1970-01-01	2020-01-12	3	74
74	water	1970-01-01	2020-01-13	3	74
74	water	1970-01-01	2020-01-14	3	74
75	water	1970-01-01	2020-01-01	2	75
75	water	1970-01-01	2020-01-02	2	75
75	water	1970-01-01	2020-01-03	2	75
75	water	1970-01-01	2020-01-04	2	75
75	water	1970-01-01	2020-01-05	2	75
75	water	1970-01-01	2020-01-06	2	75
75	water	1970-01-01	2020-01-07	2	75
75	water	1970-01-01	2020-01-08	2	75
75	water	1970-01-01	2020-01-09	2	75
75	water	1970-01-01	2020-01-10	2	75
75	water	1970-01-01	2020-01-11	2	75
75	water	1970-01-01	2020-01-12	2	75
75	water	1970-01-01	2020-01-13	2	75
75	water	1970-01-01	2020-01-14	2	75
76	water	1970-01-01	2020-01-01	3	76
76	water	1970-01-01	2020-01-02	3	76
76	water	1970-01-01	2020-01-03	3	76
76	water	1970-01-01	2020-01-04	3	76
76	water	1970-01-01	2020-01-05	3	76
76	water	1970-01-01	2020-01-06	3	76
76	water	1970-01-01	2020-01-07	3	76
76	water	1970-01-01	2020-01-08	3	76
76	water	1970-01-01	2020-01-09	3	76
76	water	1970-01-01	2020-01-10	3	76
76	water	1970-01-01	2020-01-11	3	76
76	water	1970-01-01	2020-01-12	3	76
76	water	1970-01-01	2020-01-13	3	76
76	water	1970-01-01	2020-01-14	3	76
77	water	1970-01-01	2020-01-01	3	77
77	water	1970-01-01	2020-01-02	3	77
77	water	1970-01-01	2020-01-03	3	77
77	water	1970-01-01	2020-01-04	3	77
77	water	1970-01-01	2020-01-05	3	77
77	water	1970-01-01	2020-01-06	3	77
77	water	1970-01-01	2020-01-07	3	77
77	water	1970-01-01	2020-01-08	3	77
77	water	1970-01-01	2020-01-09	3	77
77	water	1970-01-01	2020-01-10	3	77
77	water	1970-01-01	2020-01-11	3	77
77	water	1970-01-01	2020-01-12	3	77
77	water	1970-01-01	2020-01-13	3	77
77	water	1970-01-01	2020-01-14	3	77
78	water	1970-01-01	2020-01-01	3	78
78	water	1970-01-01	2020-01-02	3	78
78	water	1970-01-01	2020-01-03	3	78
78	water	1970-01-01	2020-01-04	3	78
78	water	1970-01-01	2020-01-05	3	78
78	water	1970-01-01	2020-01-06	3	78
78	water	1970-01-01	2020-01-07	3	78
78	water	1970-01-01	2020-01-08	3	78
78	water	1970-01-01	2020-01-09	3	78
78	water	1970-01-01	2020-01-10	3	78
78	water	1970-01-01	2020-01-11	3	78
78	water	1970-01-01	2020-01-12	3	78
78	water	1970-01-01	2020-01-13	3	78
78	water	1970-01-01	2020-01-14	3	78
79	water	1970-01-01	2020-01-01	3	79
79	water	1970-01-01	2020-01-02	3	79
79	water	1970-01-01	2020-01-03	3	79
79	water	1970-01-01	2020-01-04	3	79
79	water	1970-01-01	2020-01-05	3	79
79	water	1970-01-01	2020-01-06	3	79
79	water	1970-01-01	2020-01-07	3	79
79	water	1970-01-01	2020-01-08	3	79
79	water	1970-01-01	2020-01-09	3	79
79	water	1970-01-01	2020-01-10	3	79
79	water	1970-01-01	2020-01-11	3	79
79	water	1970-01-01	2020-01-12	3	79
79	water	1970-01-01	2020-01-13	3	79
79	water	1970-01-01	2020-01-14	3	79
80	water	1970-01-01	2020-01-01	1	80
80	water	1970-01-01	2020-01-02	1	80
80	water	1970-01-01	2020-01-03	1	80
80	water	1970-01-01	2020-01-04	1	80
80	water	1970-01-01	2020-01-05	1	80
80	water	1970-01-01	2020-01-06	1	80
80	water	1970-01-01	2020-01-07	1	80
80	water	1970-01-01	2020-01-08	1	80
80	water	1970-01-01	2020-01-09	1	80
80	water	1970-01-01	2020-01-10	1	80
80	water	1970-01-01	2020-01-11	1	80
80	water	1970-01-01	2020-01-12	1	80
80	water	1970-01-01	2020-01-13	1	80
80	water	1970-01-01	2020-01-14	1	80
81	water	1970-01-01	2020-01-01	2	81
81	water	1970-01-01	2020-01-02	2	81
81	water	1970-01-01	2020-01-03	2	81
81	water	1970-01-01	2020-01-04	2	81
81	water	1970-01-01	2020-01-05	2	81
81	water	1970-01-01	2020-01-06	2	81
81	water	1970-01-01	2020-01-07	2	81
81	water	1970-01-01	2020-01-08	2	81
81	water	1970-01-01	2020-01-09	2	81
81	water	1970-01-01	2020-01-10	2	81
81	water	1970-01-01	2020-01-11	2	81
81	water	1970-01-01	2020-01-12	2	81
81	water	1970-01-01	2020-01-13	2	81
81	water	1970-01-01	2020-01-14	2	81
82	water	1970-01-01	2020-01-01	2	82
82	water	1970-01-01	2020-01-02	2	82
82	water	1970-01-01	2020-01-03	2	82
82	water	1970-01-01	2020-01-04	2	82
82	water	1970-01-01	2020-01-05	2	82
82	water	1970-01-01	2020-01-06	2	82
82	water	1970-01-01	2020-01-07	2	82
82	water	1970-01-01	2020-01-08	2	82
82	water	1970-01-01	2020-01-09	2	82
82	water	1970-01-01	2020-01-10	2	82
82	water	1970-01-01	2020-01-11	2	82
82	water	1970-01-01	2020-01-12	2	82
82	water	1970-01-01	2020-01-13	2	82
82	water	1970-01-01	2020-01-14	2	82
83	water	1970-01-01	2020-01-01	3	83
83	water	1970-01-01	2020-01-02	3	83
83	water	1970-01-01	2020-01-03	3	83
83	water	1970-01-01	2020-01-04	3	83
83	water	1970-01-01	2020-01-05	3	83
83	water	1970-01-01	2020-01-06	3	83
83	water	1970-01-01	2020-01-07	3	83
83	water	1970-01-01	2020-01-08	3	83
83	water	1970-01-01	2020-01-09	3	83
83	water	1970-01-01	2020-01-10	3	83
83	water	1970-01-01	2020-01-11	3	83
83	water	1970-01-01	2020-01-12	3	83
83	water	1970-01-01	2020-01-13	3	83
83	water	1970-01-01	2020-01-14	3	83
84	water	1970-01-01	2020-01-01	1	84
84	water	1970-01-01	2020-01-02	1	84
84	water	1970-01-01	2020-01-03	1	84
84	water	1970-01-01	2020-01-04	1	84
84	water	1970-01-01	2020-01-05	1	84
84	water	1970-01-01	2020-01-06	1	84
84	water	1970-01-01	2020-01-07	1	84
84	water	1970-01-01	2020-01-08	1	84
84	water	1970-01-01	2020-01-09	1	84
84	water	1970-01-01	2020-01-10	1	84
84	water	1970-01-01	2020-01-11	1	84
84	water	1970-01-01	2020-01-12	1	84
84	water	1970-01-01	2020-01-13	1	84
84	water	1970-01-01	2020-01-14	1	84
85	water	1970-01-01	2020-01-01	2	85
85	water	1970-01-01	2020-01-02	2	85
85	water	1970-01-01	2020-01-03	2	85
85	water	1970-01-01	2020-01-04	2	85
85	water	1970-01-01	2020-01-05	2	85
85	water	1970-01-01	2020-01-06	2	85
85	water	1970-01-01	2020-01-07	2	85
85	water	1970-01-01	2020-01-08	2	85
85	water	1970-01-01	2020-01-09	2	85
85	water	1970-01-01	2020-01-10	2	85
85	water	1970-01-01	2020-01-11	2	85
85	water	1970-01-01	2020-01-12	2	85
85	water	1970-01-01	2020-01-13	2	85
85	water	1970-01-01	2020-01-14	2	85
86	water	1970-01-01	2020-01-01	1	86
86	water	1970-01-01	2020-01-02	1	86
86	water	1970-01-01	2020-01-03	1	86
86	water	1970-01-01	2020-01-04	1	86
86	water	1970-01-01	2020-01-05	1	86
86	water	1970-01-01	2020-01-06	1	86
86	water	1970-01-01	2020-01-07	1	86
86	water	1970-01-01	2020-01-08	1	86
86	water	1970-01-01	2020-01-09	1	86
86	water	1970-01-01	2020-01-10	1	86
86	water	1970-01-01	2020-01-11	1	86
86	water	1970-01-01	2020-01-12	1	86
86	water	1970-01-01	2020-01-13	1	86
86	water	1970-01-01	2020-01-14	1	86
87	water	1970-01-01	2020-01-01	1	87
87	water	1970-01-01	2020-01-02	1	87
87	water	1970-01-01	2020-01-03	1	87
87	water	1970-01-01	2020-01-04	1	87
87	water	1970-01-01	2020-01-05	1	87
87	water	1970-01-01	2020-01-06	1	87
87	water	1970-01-01	2020-01-07	1	87
87	water	1970-01-01	2020-01-08	1	87
87	water	1970-01-01	2020-01-09	1	87
87	water	1970-01-01	2020-01-10	1	87
87	water	1970-01-01	2020-01-11	1	87
87	water	1970-01-01	2020-01-12	1	87
87	water	1970-01-01	2020-01-13	1	87
87	water	1970-01-01	2020-01-14	1	87
88	water	1970-01-01	2020-01-01	2	88
88	water	1970-01-01	2020-01-02	2	88
88	water	1970-01-01	2020-01-03	2	88
88	water	1970-01-01	2020-01-04	2	88
88	water	1970-01-01	2020-01-05	2	88
88	water	1970-01-01	2020-01-06	2	88
88	water	1970-01-01	2020-01-07	2	88
88	water	1970-01-01	2020-01-08	2	88
88	water	1970-01-01	2020-01-09	2	88
88	water	1970-01-01	2020-01-10	2	88
88	water	1970-01-01	2020-01-11	2	88
88	water	1970-01-01	2020-01-12	2	88
88	water	1970-01-01	2020-01-13	2	88
88	water	1970-01-01	2020-01-14	2	88
89	water	1970-01-01	2020-01-01	3	89
89	water	1970-01-01	2020-01-02	3	89
89	water	1970-01-01	2020-01-03	3	89
89	water	1970-01-01	2020-01-04	3	89
89	water	1970-01-01	2020-01-05	3	89
89	water	1970-01-01	2020-01-06	3	89
89	water	1970-01-01	2020-01-07	3	89
89	water	1970-01-01	2020-01-08	3	89
89	water	1970-01-01	2020-01-09	3	89
89	water	1970-01-01	2020-01-10	3	89
89	water	1970-01-01	2020-01-11	3	89
89	water	1970-01-01	2020-01-12	3	89
89	water	1970-01-01	2020-01-13	3	89
89	water	1970-01-01	2020-01-14	3	89
90	water	1970-01-01	2020-01-01	3	90
90	water	1970-01-01	2020-01-02	3	90
90	water	1970-01-01	2020-01-03	3	90
90	water	1970-01-01	2020-01-04	3	90
90	water	1970-01-01	2020-01-05	3	90
90	water	1970-01-01	2020-01-06	3	90
90	water	1970-01-01	2020-01-07	3	90
90	water	1970-01-01	2020-01-08	3	90
90	water	1970-01-01	2020-01-09	3	90
90	water	1970-01-01	2020-01-10	3	90
90	water	1970-01-01	2020-01-11	3	90
90	water	1970-01-01	2020-01-12	3	90
90	water	1970-01-01	2020-01-13	3	90
90	water	1970-01-01	2020-01-14	3	90
91	water	1970-01-01	2020-01-01	1	91
91	water	1970-01-01	2020-01-02	1	91
91	water	1970-01-01	2020-01-03	1	91
91	water	1970-01-01	2020-01-04	1	91
91	water	1970-01-01	2020-01-05	1	91
91	water	1970-01-01	2020-01-06	1	91
91	water	1970-01-01	2020-01-07	1	91
91	water	1970-01-01	2020-01-08	1	91
91	water	1970-01-01	2020-01-09	1	91
91	water	1970-01-01	2020-01-10	1	91
91	water	1970-01-01	2020-01-11	1	91
91	water	1970-01-01	2020-01-12	1	91
91	water	1970-01-01	2020-01-13	1	91
91	water	1970-01-01	2020-01-14	1	91
92	water	1970-01-01	2020-01-01	2	92
92	water	1970-01-01	2020-01-02	2	92
92	water	1970-01-01	2020-01-03	2	92
92	water	1970-01-01	2020-01-04	2	92
92	water	1970-01-01	2020-01-05	2	92
92	water	1970-01-01	2020-01-06	2	92
92	water	1970-01-01	2020-01-07	2	92
92	water	1970-01-01	2020-01-08	2	92
92	water	1970-01-01	2020-01-09	2	92
92	water	1970-01-01	2020-01-10	2	92
92	water	1970-01-01	2020-01-11	2	92
92	water	1970-01-01	2020-01-12	2	92
92	water	1970-01-01	2020-01-13	2	92
92	water	1970-01-01	2020-01-14	2	92
93	water	1970-01-01	2020-01-01	2	93
93	water	1970-01-01	2020-01-02	2	93
93	water	1970-01-01	2020-01-03	2	93
93	water	1970-01-01	2020-01-04	2	93
93	water	1970-01-01	2020-01-05	2	93
93	water	1970-01-01	2020-01-06	2	93
93	water	1970-01-01	2020-01-07	2	93
93	water	1970-01-01	2020-01-08	2	93
93	water	1970-01-01	2020-01-09	2	93
93	water	1970-01-01	2020-01-10	2	93
93	water	1970-01-01	2020-01-11	2	93
93	water	1970-01-01	2020-01-12	2	93
93	water	1970-01-01	2020-01-13	2	93
93	water	1970-01-01	2020-01-14	2	93
94	water	1970-01-01	2020-01-01	1	94
94	water	1970-01-01	2020-01-02	1	94
94	water	1970-01-01	2020-01-03	1	94
94	water	1970-01-01	2020-01-04	1	94
94	water	1970-01-01	2020-01-05	1	94
94	water	1970-01-01	2020-01-06	1	94
94	water	1970-01-01	2020-01-07	1	94
94	water	1970-01-01	2020-01-08	1	94
94	water	1970-01-01	2020-01-09	1	94
94	water	1970-01-01	2020-01-10	1	94
94	water	1970-01-01	2020-01-11	1	94
94	water	1970-01-01	2020-01-12	1	94
94	water	1970-01-01	2020-01-13	1	94
94	water	1970-01-01	2020-01-14	1	94
95	water	1970-01-01	2020-01-01	1	95
95	water	1970-01-01	2020-01-02	1	95
95	water	1970-01-01	2020-01-03	1	95
95	water	1970-01-01	2020-01-04	1	95
95	water	1970-01-01	2020-01-05	1	95
95	water	1970-01-01	2020-01-06	1	95
95	water	1970-01-01	2020-01-07	1	95
95	water	1970-01-01	2020-01-08	1	95
95	water	1970-01-01	2020-01-09	1	95
95	water	1970-01-01	2020-01-10	1	95
95	water	1970-01-01	2020-01-11	1	95
95	water	1970-01-01	2020-01-12	1	95
95	water	1970-01-01	2020-01-13	1	95
95	water	1970-01-01	2020-01-14	1	95
96	water	1970-01-01	2020-01-01	3	96
96	water	1970-01-01	2020-01-02	3	96
96	water	1970-01-01	2020-01-03	3	96
96	water	1970-01-01	2020-01-04	3	96
96	water	1970-01-01	2020-01-05	3	96
96	water	1970-01-01	2020-01-06	3	96
96	water	1970-01-01	2020-01-07	3	96
96	water	1970-01-01	2020-01-08	3	96
96	water	1970-01-01	2020-01-09	3	96
96	water	1970-01-01	2020-01-10	3	96
96	water	1970-01-01	2020-01-11	3	96
96	water	1970-01-01	2020-01-12	3	96
96	water	1970-01-01	2020-01-13	3	96
96	water	1970-01-01	2020-01-14	3	96
97	water	1970-01-01	2020-01-01	2	97
97	water	1970-01-01	2020-01-02	2	97
97	water	1970-01-01	2020-01-03	2	97
97	water	1970-01-01	2020-01-04	2	97
97	water	1970-01-01	2020-01-05	2	97
97	water	1970-01-01	2020-01-06	2	97
97	water	1970-01-01	2020-01-07	2	97
97	water	1970-01-01	2020-01-08	2	97
97	water	1970-01-01	2020-01-09	2	97
97	water	1970-01-01	2020-01-10	2	97
97	water	1970-01-01	2020-01-11	2	97
97	water	1970-01-01	2020-01-12	2	97
97	water	1970-01-01	2020-01-13	2	97
97	water	1970-01-01	2020-01-14	2	97
98	water	1970-01-01	2020-01-01	2	98
98	water	1970-01-01	2020-01-02	2	98
98	water	1970-01-01	2020-01-03	2	98
98	water	1970-01-01	2020-01-04	2	98
98	water	1970-01-01	2020-01-05	2	98
98	water	1970-01-01	2020-01-06	2	98
98	water	1970-01-01	2020-01-07	2	98
98	water	1970-01-01	2020-01-08	2	98
98	water	1970-01-01	2020-01-09	2	98
98	water	1970-01-01	2020-01-10	2	98
98	water	1970-01-01	2020-01-11	2	98
98	water	1970-01-01	2020-01-12	2	98
98	water	1970-01-01	2020-01-13	2	98
98	water	1970-01-01	2020-01-14	2	98
99	water	1970-01-01	2020-01-01	3	99
99	water	1970-01-01	2020-01-02	3	99
99	water	1970-01-01	2020-01-03	3	99
99	water	1970-01-01	2020-01-04	3	99
99	water	1970-01-01	2020-01-05	3	99
99	water	1970-01-01	2020-01-06	3	99
99	water	1970-01-01	2020-01-07	3	99
99	water	1970-01-01	2020-01-08	3	99
99	water	1970-01-01	2020-01-09	3	99
99	water	1970-01-01	2020-01-10	3	99
99	water	1970-01-01	2020-01-11	3	99
99	water	1970-01-01	2020-01-12	3	99
99	water	1970-01-01	2020-01-13	3	99
99	water	1970-01-01	2020-01-14	3	99
100	water	1970-01-01	2020-01-01	1	100
100	water	1970-01-01	2020-01-02	1	100
100	water	1970-01-01	2020-01-03	1	100
100	water	1970-01-01	2020-01-04	1	100
100	water	1970-01-01	2020-01-05	1	100
100	water	1970-01-01	2020-01-06	1	100
100	water	1970-01-01	2020-01-07	1	100
100	water	1970-01-01	2020-01-08	1	100
100	water	1970-01-01	2020-01-09	1	100
100	water	1970-01-01	2020-01-10	1	100
100	water	1970-01-01	2020-01-11	1	100
100	water	1970-01-01	2020-01-12	1	100
100	water	1970-01-01	2020-01-13	1	100
100	water	1970-01-01	2020-01-14	1	100
101	water	1970-01-01	2023-12-01	3	101
101	water	1970-01-01	2023-12-02	3	101
101	water	1970-01-01	2023-12-03	3	101
101	water	1970-01-01	2023-12-04	3	101
101	water	1970-01-01	2023-12-05	3	101
101	water	1970-01-01	2023-12-06	3	101
101	water	1970-01-01	2023-12-07	3	101
101	water	1970-01-01	2023-12-08	3	101
101	water	1970-01-01	2023-12-09	3	101
101	water	1970-01-01	2023-12-10	3	101
101	water	1970-01-01	2023-12-11	3	101
101	water	1970-01-01	2023-12-12	3	101
101	water	1970-01-01	2023-12-13	3	101
101	water	1970-01-01	2023-12-14	3	101
102	water	1970-01-01	2023-12-01	1	102
102	water	1970-01-01	2023-12-02	1	102
102	water	1970-01-01	2023-12-03	1	102
102	water	1970-01-01	2023-12-04	1	102
102	water	1970-01-01	2023-12-05	1	102
102	water	1970-01-01	2023-12-06	1	102
102	water	1970-01-01	2023-12-07	1	102
102	water	1970-01-01	2023-12-08	1	102
102	water	1970-01-01	2023-12-09	1	102
102	water	1970-01-01	2023-12-10	1	102
102	water	1970-01-01	2023-12-11	1	102
102	water	1970-01-01	2023-12-12	1	102
102	water	1970-01-01	2023-12-13	1	102
102	water	1970-01-01	2023-12-14	1	102
103	water	1970-01-01	2023-12-01	3	103
103	water	1970-01-01	2023-12-02	3	103
103	water	1970-01-01	2023-12-03	3	103
103	water	1970-01-01	2023-12-04	3	103
103	water	1970-01-01	2023-12-05	3	103
103	water	1970-01-01	2023-12-06	3	103
103	water	1970-01-01	2023-12-07	3	103
103	water	1970-01-01	2023-12-08	3	103
103	water	1970-01-01	2023-12-09	3	103
103	water	1970-01-01	2023-12-10	3	103
103	water	1970-01-01	2023-12-11	3	103
103	water	1970-01-01	2023-12-12	3	103
103	water	1970-01-01	2023-12-13	3	103
103	water	1970-01-01	2023-12-14	3	103
104	water	1970-01-01	2023-12-01	2	104
104	water	1970-01-01	2023-12-02	2	104
104	water	1970-01-01	2023-12-03	2	104
104	water	1970-01-01	2023-12-04	2	104
104	water	1970-01-01	2023-12-05	2	104
104	water	1970-01-01	2023-12-06	2	104
104	water	1970-01-01	2023-12-07	2	104
104	water	1970-01-01	2023-12-08	2	104
104	water	1970-01-01	2023-12-09	2	104
104	water	1970-01-01	2023-12-10	2	104
104	water	1970-01-01	2023-12-11	2	104
104	water	1970-01-01	2023-12-12	2	104
104	water	1970-01-01	2023-12-13	2	104
104	water	1970-01-01	2023-12-14	2	104
105	water	1970-01-01	2023-12-01	3	105
105	water	1970-01-01	2023-12-02	3	105
105	water	1970-01-01	2023-12-03	3	105
105	water	1970-01-01	2023-12-04	3	105
105	water	1970-01-01	2023-12-05	3	105
105	water	1970-01-01	2023-12-06	3	105
105	water	1970-01-01	2023-12-07	3	105
105	water	1970-01-01	2023-12-08	3	105
105	water	1970-01-01	2023-12-09	3	105
105	water	1970-01-01	2023-12-10	3	105
105	water	1970-01-01	2023-12-11	3	105
105	water	1970-01-01	2023-12-12	3	105
105	water	1970-01-01	2023-12-13	3	105
105	water	1970-01-01	2023-12-14	3	105
106	water	1970-01-01	2023-12-01	1	106
106	water	1970-01-01	2023-12-02	1	106
106	water	1970-01-01	2023-12-03	1	106
106	water	1970-01-01	2023-12-04	1	106
106	water	1970-01-01	2023-12-05	1	106
106	water	1970-01-01	2023-12-06	1	106
106	water	1970-01-01	2023-12-07	1	106
106	water	1970-01-01	2023-12-08	1	106
106	water	1970-01-01	2023-12-09	1	106
106	water	1970-01-01	2023-12-10	1	106
106	water	1970-01-01	2023-12-11	1	106
106	water	1970-01-01	2023-12-12	1	106
106	water	1970-01-01	2023-12-13	1	106
106	water	1970-01-01	2023-12-14	1	106
107	water	1970-01-01	2023-12-01	3	107
107	water	1970-01-01	2023-12-02	3	107
107	water	1970-01-01	2023-12-03	3	107
107	water	1970-01-01	2023-12-04	3	107
107	water	1970-01-01	2023-12-05	3	107
107	water	1970-01-01	2023-12-06	3	107
107	water	1970-01-01	2023-12-07	3	107
107	water	1970-01-01	2023-12-08	3	107
107	water	1970-01-01	2023-12-09	3	107
107	water	1970-01-01	2023-12-10	3	107
107	water	1970-01-01	2023-12-11	3	107
107	water	1970-01-01	2023-12-12	3	107
107	water	1970-01-01	2023-12-13	3	107
107	water	1970-01-01	2023-12-14	3	107
108	water	1970-01-01	2023-12-01	2	108
108	water	1970-01-01	2023-12-02	2	108
108	water	1970-01-01	2023-12-03	2	108
108	water	1970-01-01	2023-12-04	2	108
108	water	1970-01-01	2023-12-05	2	108
108	water	1970-01-01	2023-12-06	2	108
108	water	1970-01-01	2023-12-07	2	108
108	water	1970-01-01	2023-12-08	2	108
108	water	1970-01-01	2023-12-09	2	108
108	water	1970-01-01	2023-12-10	2	108
108	water	1970-01-01	2023-12-11	2	108
108	water	1970-01-01	2023-12-12	2	108
108	water	1970-01-01	2023-12-13	2	108
108	water	1970-01-01	2023-12-14	2	108
109	water	1970-01-01	2023-12-01	2	109
109	water	1970-01-01	2023-12-02	2	109
109	water	1970-01-01	2023-12-03	2	109
109	water	1970-01-01	2023-12-04	2	109
109	water	1970-01-01	2023-12-05	2	109
109	water	1970-01-01	2023-12-06	2	109
109	water	1970-01-01	2023-12-07	2	109
109	water	1970-01-01	2023-12-08	2	109
109	water	1970-01-01	2023-12-09	2	109
109	water	1970-01-01	2023-12-10	2	109
109	water	1970-01-01	2023-12-11	2	109
109	water	1970-01-01	2023-12-12	2	109
109	water	1970-01-01	2023-12-13	2	109
109	water	1970-01-01	2023-12-14	2	109
110	water	1970-01-01	2023-12-01	2	110
110	water	1970-01-01	2023-12-02	2	110
110	water	1970-01-01	2023-12-03	2	110
110	water	1970-01-01	2023-12-04	2	110
110	water	1970-01-01	2023-12-05	2	110
110	water	1970-01-01	2023-12-06	2	110
110	water	1970-01-01	2023-12-07	2	110
110	water	1970-01-01	2023-12-08	2	110
110	water	1970-01-01	2023-12-09	2	110
110	water	1970-01-01	2023-12-10	2	110
110	water	1970-01-01	2023-12-11	2	110
110	water	1970-01-01	2023-12-12	2	110
110	water	1970-01-01	2023-12-13	2	110
110	water	1970-01-01	2023-12-14	2	110
111	water	1970-01-01	2023-12-01	3	111
111	water	1970-01-01	2023-12-02	3	111
111	water	1970-01-01	2023-12-03	3	111
111	water	1970-01-01	2023-12-04	3	111
111	water	1970-01-01	2023-12-05	3	111
111	water	1970-01-01	2023-12-06	3	111
111	water	1970-01-01	2023-12-07	3	111
111	water	1970-01-01	2023-12-08	3	111
111	water	1970-01-01	2023-12-09	3	111
111	water	1970-01-01	2023-12-10	3	111
111	water	1970-01-01	2023-12-11	3	111
111	water	1970-01-01	2023-12-12	3	111
111	water	1970-01-01	2023-12-13	3	111
111	water	1970-01-01	2023-12-14	3	111
112	water	1970-01-01	2023-12-01	2	112
112	water	1970-01-01	2023-12-02	2	112
112	water	1970-01-01	2023-12-03	2	112
112	water	1970-01-01	2023-12-04	2	112
112	water	1970-01-01	2023-12-05	2	112
112	water	1970-01-01	2023-12-06	2	112
112	water	1970-01-01	2023-12-07	2	112
112	water	1970-01-01	2023-12-08	2	112
112	water	1970-01-01	2023-12-09	2	112
112	water	1970-01-01	2023-12-10	2	112
112	water	1970-01-01	2023-12-11	2	112
112	water	1970-01-01	2023-12-12	2	112
112	water	1970-01-01	2023-12-13	2	112
112	water	1970-01-01	2023-12-14	2	112
113	water	1970-01-01	2023-12-01	1	113
113	water	1970-01-01	2023-12-02	1	113
113	water	1970-01-01	2023-12-03	1	113
113	water	1970-01-01	2023-12-04	1	113
113	water	1970-01-01	2023-12-05	1	113
113	water	1970-01-01	2023-12-06	1	113
113	water	1970-01-01	2023-12-07	1	113
113	water	1970-01-01	2023-12-08	1	113
113	water	1970-01-01	2023-12-09	1	113
113	water	1970-01-01	2023-12-10	1	113
113	water	1970-01-01	2023-12-11	1	113
113	water	1970-01-01	2023-12-12	1	113
113	water	1970-01-01	2023-12-13	1	113
113	water	1970-01-01	2023-12-14	1	113
114	water	1970-01-01	2023-12-01	2	114
114	water	1970-01-01	2023-12-02	2	114
114	water	1970-01-01	2023-12-03	2	114
114	water	1970-01-01	2023-12-04	2	114
114	water	1970-01-01	2023-12-05	2	114
114	water	1970-01-01	2023-12-06	2	114
114	water	1970-01-01	2023-12-07	2	114
114	water	1970-01-01	2023-12-08	2	114
114	water	1970-01-01	2023-12-09	2	114
114	water	1970-01-01	2023-12-10	2	114
114	water	1970-01-01	2023-12-11	2	114
114	water	1970-01-01	2023-12-12	2	114
114	water	1970-01-01	2023-12-13	2	114
114	water	1970-01-01	2023-12-14	2	114
115	water	1970-01-01	2023-12-01	3	115
115	water	1970-01-01	2023-12-02	3	115
115	water	1970-01-01	2023-12-03	3	115
115	water	1970-01-01	2023-12-04	3	115
115	water	1970-01-01	2023-12-05	3	115
115	water	1970-01-01	2023-12-06	3	115
115	water	1970-01-01	2023-12-07	3	115
115	water	1970-01-01	2023-12-08	3	115
115	water	1970-01-01	2023-12-09	3	115
115	water	1970-01-01	2023-12-10	3	115
115	water	1970-01-01	2023-12-11	3	115
115	water	1970-01-01	2023-12-12	3	115
115	water	1970-01-01	2023-12-13	3	115
115	water	1970-01-01	2023-12-14	3	115
116	water	1970-01-01	2023-12-01	3	116
116	water	1970-01-01	2023-12-02	3	116
116	water	1970-01-01	2023-12-03	3	116
116	water	1970-01-01	2023-12-04	3	116
116	water	1970-01-01	2023-12-05	3	116
116	water	1970-01-01	2023-12-06	3	116
116	water	1970-01-01	2023-12-07	3	116
116	water	1970-01-01	2023-12-08	3	116
116	water	1970-01-01	2023-12-09	3	116
116	water	1970-01-01	2023-12-10	3	116
116	water	1970-01-01	2023-12-11	3	116
116	water	1970-01-01	2023-12-12	3	116
116	water	1970-01-01	2023-12-13	3	116
116	water	1970-01-01	2023-12-14	3	116
117	water	1970-01-01	2023-12-01	3	117
117	water	1970-01-01	2023-12-02	3	117
117	water	1970-01-01	2023-12-03	3	117
117	water	1970-01-01	2023-12-04	3	117
117	water	1970-01-01	2023-12-05	3	117
117	water	1970-01-01	2023-12-06	3	117
117	water	1970-01-01	2023-12-07	3	117
117	water	1970-01-01	2023-12-08	3	117
117	water	1970-01-01	2023-12-09	3	117
117	water	1970-01-01	2023-12-10	3	117
117	water	1970-01-01	2023-12-11	3	117
117	water	1970-01-01	2023-12-12	3	117
117	water	1970-01-01	2023-12-13	3	117
117	water	1970-01-01	2023-12-14	3	117
118	water	1970-01-01	2023-12-01	2	118
118	water	1970-01-01	2023-12-02	2	118
118	water	1970-01-01	2023-12-03	2	118
118	water	1970-01-01	2023-12-04	2	118
118	water	1970-01-01	2023-12-05	2	118
118	water	1970-01-01	2023-12-06	2	118
118	water	1970-01-01	2023-12-07	2	118
118	water	1970-01-01	2023-12-08	2	118
118	water	1970-01-01	2023-12-09	2	118
118	water	1970-01-01	2023-12-10	2	118
118	water	1970-01-01	2023-12-11	2	118
118	water	1970-01-01	2023-12-12	2	118
118	water	1970-01-01	2023-12-13	2	118
118	water	1970-01-01	2023-12-14	2	118
119	water	1970-01-01	2023-12-01	1	119
119	water	1970-01-01	2023-12-02	1	119
119	water	1970-01-01	2023-12-03	1	119
119	water	1970-01-01	2023-12-04	1	119
119	water	1970-01-01	2023-12-05	1	119
119	water	1970-01-01	2023-12-06	1	119
119	water	1970-01-01	2023-12-07	1	119
119	water	1970-01-01	2023-12-08	1	119
119	water	1970-01-01	2023-12-09	1	119
119	water	1970-01-01	2023-12-10	1	119
119	water	1970-01-01	2023-12-11	1	119
119	water	1970-01-01	2023-12-12	1	119
119	water	1970-01-01	2023-12-13	1	119
119	water	1970-01-01	2023-12-14	1	119
120	water	1970-01-01	2023-12-01	1	120
120	water	1970-01-01	2023-12-02	1	120
120	water	1970-01-01	2023-12-03	1	120
120	water	1970-01-01	2023-12-04	1	120
120	water	1970-01-01	2023-12-05	1	120
120	water	1970-01-01	2023-12-06	1	120
120	water	1970-01-01	2023-12-07	1	120
120	water	1970-01-01	2023-12-08	1	120
120	water	1970-01-01	2023-12-09	1	120
120	water	1970-01-01	2023-12-10	1	120
120	water	1970-01-01	2023-12-11	1	120
120	water	1970-01-01	2023-12-12	1	120
120	water	1970-01-01	2023-12-13	1	120
120	water	1970-01-01	2023-12-14	1	120
121	water	1970-01-01	2023-12-01	1	121
121	water	1970-01-01	2023-12-02	1	121
121	water	1970-01-01	2023-12-03	1	121
121	water	1970-01-01	2023-12-04	1	121
121	water	1970-01-01	2023-12-05	1	121
121	water	1970-01-01	2023-12-06	1	121
121	water	1970-01-01	2023-12-07	1	121
121	water	1970-01-01	2023-12-08	1	121
121	water	1970-01-01	2023-12-09	1	121
121	water	1970-01-01	2023-12-10	1	121
121	water	1970-01-01	2023-12-11	1	121
121	water	1970-01-01	2023-12-12	1	121
121	water	1970-01-01	2023-12-13	1	121
121	water	1970-01-01	2023-12-14	1	121
122	water	1970-01-01	2023-12-01	3	122
122	water	1970-01-01	2023-12-02	3	122
122	water	1970-01-01	2023-12-03	3	122
122	water	1970-01-01	2023-12-04	3	122
122	water	1970-01-01	2023-12-05	3	122
122	water	1970-01-01	2023-12-06	3	122
122	water	1970-01-01	2023-12-07	3	122
122	water	1970-01-01	2023-12-08	3	122
122	water	1970-01-01	2023-12-09	3	122
122	water	1970-01-01	2023-12-10	3	122
122	water	1970-01-01	2023-12-11	3	122
122	water	1970-01-01	2023-12-12	3	122
122	water	1970-01-01	2023-12-13	3	122
122	water	1970-01-01	2023-12-14	3	122
123	water	1970-01-01	2023-12-01	3	123
123	water	1970-01-01	2023-12-02	3	123
123	water	1970-01-01	2023-12-03	3	123
123	water	1970-01-01	2023-12-04	3	123
123	water	1970-01-01	2023-12-05	3	123
123	water	1970-01-01	2023-12-06	3	123
123	water	1970-01-01	2023-12-07	3	123
123	water	1970-01-01	2023-12-08	3	123
123	water	1970-01-01	2023-12-09	3	123
123	water	1970-01-01	2023-12-10	3	123
123	water	1970-01-01	2023-12-11	3	123
123	water	1970-01-01	2023-12-12	3	123
123	water	1970-01-01	2023-12-13	3	123
123	water	1970-01-01	2023-12-14	3	123
124	water	1970-01-01	2023-12-01	3	124
124	water	1970-01-01	2023-12-02	3	124
124	water	1970-01-01	2023-12-03	3	124
124	water	1970-01-01	2023-12-04	3	124
124	water	1970-01-01	2023-12-05	3	124
124	water	1970-01-01	2023-12-06	3	124
124	water	1970-01-01	2023-12-07	3	124
124	water	1970-01-01	2023-12-08	3	124
124	water	1970-01-01	2023-12-09	3	124
124	water	1970-01-01	2023-12-10	3	124
124	water	1970-01-01	2023-12-11	3	124
124	water	1970-01-01	2023-12-12	3	124
124	water	1970-01-01	2023-12-13	3	124
124	water	1970-01-01	2023-12-14	3	124
125	water	1970-01-01	2023-12-01	3	125
125	water	1970-01-01	2023-12-02	3	125
125	water	1970-01-01	2023-12-03	3	125
125	water	1970-01-01	2023-12-04	3	125
125	water	1970-01-01	2023-12-05	3	125
125	water	1970-01-01	2023-12-06	3	125
125	water	1970-01-01	2023-12-07	3	125
125	water	1970-01-01	2023-12-08	3	125
125	water	1970-01-01	2023-12-09	3	125
125	water	1970-01-01	2023-12-10	3	125
125	water	1970-01-01	2023-12-11	3	125
125	water	1970-01-01	2023-12-12	3	125
125	water	1970-01-01	2023-12-13	3	125
125	water	1970-01-01	2023-12-14	3	125
126	water	1970-01-01	2023-12-01	2	126
126	water	1970-01-01	2023-12-02	2	126
126	water	1970-01-01	2023-12-03	2	126
126	water	1970-01-01	2023-12-04	2	126
126	water	1970-01-01	2023-12-05	2	126
126	water	1970-01-01	2023-12-06	2	126
126	water	1970-01-01	2023-12-07	2	126
126	water	1970-01-01	2023-12-08	2	126
126	water	1970-01-01	2023-12-09	2	126
126	water	1970-01-01	2023-12-10	2	126
126	water	1970-01-01	2023-12-11	2	126
126	water	1970-01-01	2023-12-12	2	126
126	water	1970-01-01	2023-12-13	2	126
126	water	1970-01-01	2023-12-14	2	126
127	water	1970-01-01	2023-12-01	1	127
127	water	1970-01-01	2023-12-02	1	127
127	water	1970-01-01	2023-12-03	1	127
127	water	1970-01-01	2023-12-04	1	127
127	water	1970-01-01	2023-12-05	1	127
127	water	1970-01-01	2023-12-06	1	127
127	water	1970-01-01	2023-12-07	1	127
127	water	1970-01-01	2023-12-08	1	127
127	water	1970-01-01	2023-12-09	1	127
127	water	1970-01-01	2023-12-10	1	127
127	water	1970-01-01	2023-12-11	1	127
127	water	1970-01-01	2023-12-12	1	127
127	water	1970-01-01	2023-12-13	1	127
127	water	1970-01-01	2023-12-14	1	127
128	water	1970-01-01	2023-12-01	3	128
128	water	1970-01-01	2023-12-02	3	128
128	water	1970-01-01	2023-12-03	3	128
128	water	1970-01-01	2023-12-04	3	128
128	water	1970-01-01	2023-12-05	3	128
128	water	1970-01-01	2023-12-06	3	128
128	water	1970-01-01	2023-12-07	3	128
128	water	1970-01-01	2023-12-08	3	128
128	water	1970-01-01	2023-12-09	3	128
128	water	1970-01-01	2023-12-10	3	128
128	water	1970-01-01	2023-12-11	3	128
128	water	1970-01-01	2023-12-12	3	128
128	water	1970-01-01	2023-12-13	3	128
128	water	1970-01-01	2023-12-14	3	128
129	water	1970-01-01	2023-12-01	1	129
129	water	1970-01-01	2023-12-02	1	129
129	water	1970-01-01	2023-12-03	1	129
129	water	1970-01-01	2023-12-04	1	129
129	water	1970-01-01	2023-12-05	1	129
129	water	1970-01-01	2023-12-06	1	129
129	water	1970-01-01	2023-12-07	1	129
129	water	1970-01-01	2023-12-08	1	129
129	water	1970-01-01	2023-12-09	1	129
129	water	1970-01-01	2023-12-10	1	129
129	water	1970-01-01	2023-12-11	1	129
129	water	1970-01-01	2023-12-12	1	129
129	water	1970-01-01	2023-12-13	1	129
129	water	1970-01-01	2023-12-14	1	129
130	water	1970-01-01	2023-12-01	1	130
130	water	1970-01-01	2023-12-02	1	130
130	water	1970-01-01	2023-12-03	1	130
130	water	1970-01-01	2023-12-04	1	130
130	water	1970-01-01	2023-12-05	1	130
130	water	1970-01-01	2023-12-06	1	130
130	water	1970-01-01	2023-12-07	1	130
130	water	1970-01-01	2023-12-08	1	130
130	water	1970-01-01	2023-12-09	1	130
130	water	1970-01-01	2023-12-10	1	130
130	water	1970-01-01	2023-12-11	1	130
130	water	1970-01-01	2023-12-12	1	130
130	water	1970-01-01	2023-12-13	1	130
130	water	1970-01-01	2023-12-14	1	130
131	water	1970-01-01	2023-12-01	3	131
131	water	1970-01-01	2023-12-02	3	131
131	water	1970-01-01	2023-12-03	3	131
131	water	1970-01-01	2023-12-04	3	131
131	water	1970-01-01	2023-12-05	3	131
131	water	1970-01-01	2023-12-06	3	131
131	water	1970-01-01	2023-12-07	3	131
131	water	1970-01-01	2023-12-08	3	131
131	water	1970-01-01	2023-12-09	3	131
131	water	1970-01-01	2023-12-10	3	131
131	water	1970-01-01	2023-12-11	3	131
131	water	1970-01-01	2023-12-12	3	131
131	water	1970-01-01	2023-12-13	3	131
131	water	1970-01-01	2023-12-14	3	131
132	water	1970-01-01	2023-12-01	1	132
132	water	1970-01-01	2023-12-02	1	132
132	water	1970-01-01	2023-12-03	1	132
132	water	1970-01-01	2023-12-04	1	132
132	water	1970-01-01	2023-12-05	1	132
132	water	1970-01-01	2023-12-06	1	132
132	water	1970-01-01	2023-12-07	1	132
132	water	1970-01-01	2023-12-08	1	132
132	water	1970-01-01	2023-12-09	1	132
132	water	1970-01-01	2023-12-10	1	132
132	water	1970-01-01	2023-12-11	1	132
132	water	1970-01-01	2023-12-12	1	132
132	water	1970-01-01	2023-12-13	1	132
132	water	1970-01-01	2023-12-14	1	132
133	water	1970-01-01	2023-12-01	1	133
133	water	1970-01-01	2023-12-02	1	133
133	water	1970-01-01	2023-12-03	1	133
133	water	1970-01-01	2023-12-04	1	133
133	water	1970-01-01	2023-12-05	1	133
133	water	1970-01-01	2023-12-06	1	133
133	water	1970-01-01	2023-12-07	1	133
133	water	1970-01-01	2023-12-08	1	133
133	water	1970-01-01	2023-12-09	1	133
133	water	1970-01-01	2023-12-10	1	133
133	water	1970-01-01	2023-12-11	1	133
133	water	1970-01-01	2023-12-12	1	133
133	water	1970-01-01	2023-12-13	1	133
133	water	1970-01-01	2023-12-14	1	133
134	water	1970-01-01	2023-12-01	3	134
134	water	1970-01-01	2023-12-02	3	134
134	water	1970-01-01	2023-12-03	3	134
134	water	1970-01-01	2023-12-04	3	134
134	water	1970-01-01	2023-12-05	3	134
134	water	1970-01-01	2023-12-06	3	134
134	water	1970-01-01	2023-12-07	3	134
134	water	1970-01-01	2023-12-08	3	134
134	water	1970-01-01	2023-12-09	3	134
134	water	1970-01-01	2023-12-10	3	134
134	water	1970-01-01	2023-12-11	3	134
134	water	1970-01-01	2023-12-12	3	134
134	water	1970-01-01	2023-12-13	3	134
134	water	1970-01-01	2023-12-14	3	134
135	water	1970-01-01	2023-12-01	3	135
135	water	1970-01-01	2023-12-02	3	135
135	water	1970-01-01	2023-12-03	3	135
135	water	1970-01-01	2023-12-04	3	135
135	water	1970-01-01	2023-12-05	3	135
135	water	1970-01-01	2023-12-06	3	135
135	water	1970-01-01	2023-12-07	3	135
135	water	1970-01-01	2023-12-08	3	135
135	water	1970-01-01	2023-12-09	3	135
135	water	1970-01-01	2023-12-10	3	135
135	water	1970-01-01	2023-12-11	3	135
135	water	1970-01-01	2023-12-12	3	135
135	water	1970-01-01	2023-12-13	3	135
135	water	1970-01-01	2023-12-14	3	135
136	water	1970-01-01	2023-12-01	2	136
136	water	1970-01-01	2023-12-02	2	136
136	water	1970-01-01	2023-12-03	2	136
136	water	1970-01-01	2023-12-04	2	136
136	water	1970-01-01	2023-12-05	2	136
136	water	1970-01-01	2023-12-06	2	136
136	water	1970-01-01	2023-12-07	2	136
136	water	1970-01-01	2023-12-08	2	136
136	water	1970-01-01	2023-12-09	2	136
136	water	1970-01-01	2023-12-10	2	136
136	water	1970-01-01	2023-12-11	2	136
136	water	1970-01-01	2023-12-12	2	136
136	water	1970-01-01	2023-12-13	2	136
136	water	1970-01-01	2023-12-14	2	136
137	water	1970-01-01	2023-12-01	1	137
137	water	1970-01-01	2023-12-02	1	137
137	water	1970-01-01	2023-12-03	1	137
137	water	1970-01-01	2023-12-04	1	137
137	water	1970-01-01	2023-12-05	1	137
137	water	1970-01-01	2023-12-06	1	137
137	water	1970-01-01	2023-12-07	1	137
137	water	1970-01-01	2023-12-08	1	137
137	water	1970-01-01	2023-12-09	1	137
137	water	1970-01-01	2023-12-10	1	137
137	water	1970-01-01	2023-12-11	1	137
137	water	1970-01-01	2023-12-12	1	137
137	water	1970-01-01	2023-12-13	1	137
137	water	1970-01-01	2023-12-14	1	137
138	water	1970-01-01	2023-12-01	1	138
138	water	1970-01-01	2023-12-02	1	138
138	water	1970-01-01	2023-12-03	1	138
138	water	1970-01-01	2023-12-04	1	138
138	water	1970-01-01	2023-12-05	1	138
138	water	1970-01-01	2023-12-06	1	138
138	water	1970-01-01	2023-12-07	1	138
138	water	1970-01-01	2023-12-08	1	138
138	water	1970-01-01	2023-12-09	1	138
138	water	1970-01-01	2023-12-10	1	138
138	water	1970-01-01	2023-12-11	1	138
138	water	1970-01-01	2023-12-12	1	138
138	water	1970-01-01	2023-12-13	1	138
138	water	1970-01-01	2023-12-14	1	138
139	water	1970-01-01	2023-12-01	3	139
139	water	1970-01-01	2023-12-02	3	139
139	water	1970-01-01	2023-12-03	3	139
139	water	1970-01-01	2023-12-04	3	139
139	water	1970-01-01	2023-12-05	3	139
139	water	1970-01-01	2023-12-06	3	139
139	water	1970-01-01	2023-12-07	3	139
139	water	1970-01-01	2023-12-08	3	139
139	water	1970-01-01	2023-12-09	3	139
139	water	1970-01-01	2023-12-10	3	139
139	water	1970-01-01	2023-12-11	3	139
139	water	1970-01-01	2023-12-12	3	139
139	water	1970-01-01	2023-12-13	3	139
139	water	1970-01-01	2023-12-14	3	139
140	water	1970-01-01	2023-12-01	2	140
140	water	1970-01-01	2023-12-02	2	140
140	water	1970-01-01	2023-12-03	2	140
140	water	1970-01-01	2023-12-04	2	140
140	water	1970-01-01	2023-12-05	2	140
140	water	1970-01-01	2023-12-06	2	140
140	water	1970-01-01	2023-12-07	2	140
140	water	1970-01-01	2023-12-08	2	140
140	water	1970-01-01	2023-12-09	2	140
140	water	1970-01-01	2023-12-10	2	140
140	water	1970-01-01	2023-12-11	2	140
140	water	1970-01-01	2023-12-12	2	140
140	water	1970-01-01	2023-12-13	2	140
140	water	1970-01-01	2023-12-14	2	140
141	water	1970-01-01	2023-12-01	2	141
141	water	1970-01-01	2023-12-02	2	141
141	water	1970-01-01	2023-12-03	2	141
141	water	1970-01-01	2023-12-04	2	141
141	water	1970-01-01	2023-12-05	2	141
141	water	1970-01-01	2023-12-06	2	141
141	water	1970-01-01	2023-12-07	2	141
141	water	1970-01-01	2023-12-08	2	141
141	water	1970-01-01	2023-12-09	2	141
141	water	1970-01-01	2023-12-10	2	141
141	water	1970-01-01	2023-12-11	2	141
141	water	1970-01-01	2023-12-12	2	141
141	water	1970-01-01	2023-12-13	2	141
141	water	1970-01-01	2023-12-14	2	141
142	water	1970-01-01	2023-12-01	3	142
142	water	1970-01-01	2023-12-02	3	142
142	water	1970-01-01	2023-12-03	3	142
142	water	1970-01-01	2023-12-04	3	142
142	water	1970-01-01	2023-12-05	3	142
142	water	1970-01-01	2023-12-06	3	142
142	water	1970-01-01	2023-12-07	3	142
142	water	1970-01-01	2023-12-08	3	142
142	water	1970-01-01	2023-12-09	3	142
142	water	1970-01-01	2023-12-10	3	142
142	water	1970-01-01	2023-12-11	3	142
142	water	1970-01-01	2023-12-12	3	142
142	water	1970-01-01	2023-12-13	3	142
142	water	1970-01-01	2023-12-14	3	142
143	water	1970-01-01	2023-12-01	3	143
143	water	1970-01-01	2023-12-02	3	143
143	water	1970-01-01	2023-12-03	3	143
143	water	1970-01-01	2023-12-04	3	143
143	water	1970-01-01	2023-12-05	3	143
143	water	1970-01-01	2023-12-06	3	143
143	water	1970-01-01	2023-12-07	3	143
143	water	1970-01-01	2023-12-08	3	143
143	water	1970-01-01	2023-12-09	3	143
143	water	1970-01-01	2023-12-10	3	143
143	water	1970-01-01	2023-12-11	3	143
143	water	1970-01-01	2023-12-12	3	143
143	water	1970-01-01	2023-12-13	3	143
143	water	1970-01-01	2023-12-14	3	143
144	water	1970-01-01	2023-12-01	2	144
144	water	1970-01-01	2023-12-02	2	144
144	water	1970-01-01	2023-12-03	2	144
144	water	1970-01-01	2023-12-04	2	144
144	water	1970-01-01	2023-12-05	2	144
144	water	1970-01-01	2023-12-06	2	144
144	water	1970-01-01	2023-12-07	2	144
144	water	1970-01-01	2023-12-08	2	144
144	water	1970-01-01	2023-12-09	2	144
144	water	1970-01-01	2023-12-10	2	144
144	water	1970-01-01	2023-12-11	2	144
144	water	1970-01-01	2023-12-12	2	144
144	water	1970-01-01	2023-12-13	2	144
144	water	1970-01-01	2023-12-14	2	144
145	water	1970-01-01	2023-12-01	3	145
145	water	1970-01-01	2023-12-02	3	145
145	water	1970-01-01	2023-12-03	3	145
145	water	1970-01-01	2023-12-04	3	145
145	water	1970-01-01	2023-12-05	3	145
145	water	1970-01-01	2023-12-06	3	145
145	water	1970-01-01	2023-12-07	3	145
145	water	1970-01-01	2023-12-08	3	145
145	water	1970-01-01	2023-12-09	3	145
145	water	1970-01-01	2023-12-10	3	145
145	water	1970-01-01	2023-12-11	3	145
145	water	1970-01-01	2023-12-12	3	145
145	water	1970-01-01	2023-12-13	3	145
145	water	1970-01-01	2023-12-14	3	145
146	water	1970-01-01	2023-12-01	1	146
146	water	1970-01-01	2023-12-02	1	146
146	water	1970-01-01	2023-12-03	1	146
146	water	1970-01-01	2023-12-04	1	146
146	water	1970-01-01	2023-12-05	1	146
146	water	1970-01-01	2023-12-06	1	146
146	water	1970-01-01	2023-12-07	1	146
146	water	1970-01-01	2023-12-08	1	146
146	water	1970-01-01	2023-12-09	1	146
146	water	1970-01-01	2023-12-10	1	146
146	water	1970-01-01	2023-12-11	1	146
146	water	1970-01-01	2023-12-12	1	146
146	water	1970-01-01	2023-12-13	1	146
146	water	1970-01-01	2023-12-14	1	146
147	water	1970-01-01	2023-12-01	1	147
147	water	1970-01-01	2023-12-02	1	147
147	water	1970-01-01	2023-12-03	1	147
147	water	1970-01-01	2023-12-04	1	147
147	water	1970-01-01	2023-12-05	1	147
147	water	1970-01-01	2023-12-06	1	147
147	water	1970-01-01	2023-12-07	1	147
147	water	1970-01-01	2023-12-08	1	147
147	water	1970-01-01	2023-12-09	1	147
147	water	1970-01-01	2023-12-10	1	147
147	water	1970-01-01	2023-12-11	1	147
147	water	1970-01-01	2023-12-12	1	147
147	water	1970-01-01	2023-12-13	1	147
147	water	1970-01-01	2023-12-14	1	147
148	water	1970-01-01	2023-12-01	1	148
148	water	1970-01-01	2023-12-02	1	148
148	water	1970-01-01	2023-12-03	1	148
148	water	1970-01-01	2023-12-04	1	148
148	water	1970-01-01	2023-12-05	1	148
148	water	1970-01-01	2023-12-06	1	148
148	water	1970-01-01	2023-12-07	1	148
148	water	1970-01-01	2023-12-08	1	148
148	water	1970-01-01	2023-12-09	1	148
148	water	1970-01-01	2023-12-10	1	148
148	water	1970-01-01	2023-12-11	1	148
148	water	1970-01-01	2023-12-12	1	148
148	water	1970-01-01	2023-12-13	1	148
148	water	1970-01-01	2023-12-14	1	148
149	water	1970-01-01	2023-12-01	2	149
149	water	1970-01-01	2023-12-02	2	149
149	water	1970-01-01	2023-12-03	2	149
149	water	1970-01-01	2023-12-04	2	149
149	water	1970-01-01	2023-12-05	2	149
149	water	1970-01-01	2023-12-06	2	149
149	water	1970-01-01	2023-12-07	2	149
149	water	1970-01-01	2023-12-08	2	149
149	water	1970-01-01	2023-12-09	2	149
149	water	1970-01-01	2023-12-10	2	149
149	water	1970-01-01	2023-12-11	2	149
149	water	1970-01-01	2023-12-12	2	149
149	water	1970-01-01	2023-12-13	2	149
149	water	1970-01-01	2023-12-14	2	149
150	water	1970-01-01	2023-12-01	2	150
150	water	1970-01-01	2023-12-02	2	150
150	water	1970-01-01	2023-12-03	2	150
150	water	1970-01-01	2023-12-04	2	150
150	water	1970-01-01	2023-12-05	2	150
150	water	1970-01-01	2023-12-06	2	150
150	water	1970-01-01	2023-12-07	2	150
150	water	1970-01-01	2023-12-08	2	150
150	water	1970-01-01	2023-12-09	2	150
150	water	1970-01-01	2023-12-10	2	150
150	water	1970-01-01	2023-12-11	2	150
150	water	1970-01-01	2023-12-12	2	150
150	water	1970-01-01	2023-12-13	2	150
150	water	1970-01-01	2023-12-14	2	150
151	water	1970-01-01	2023-12-01	3	151
151	water	1970-01-01	2023-12-02	3	151
151	water	1970-01-01	2023-12-03	3	151
151	water	1970-01-01	2023-12-04	3	151
151	water	1970-01-01	2023-12-05	3	151
151	water	1970-01-01	2023-12-06	3	151
151	water	1970-01-01	2023-12-07	3	151
151	water	1970-01-01	2023-12-08	3	151
151	water	1970-01-01	2023-12-09	3	151
151	water	1970-01-01	2023-12-10	3	151
151	water	1970-01-01	2023-12-11	3	151
151	water	1970-01-01	2023-12-12	3	151
151	water	1970-01-01	2023-12-13	3	151
151	water	1970-01-01	2023-12-14	3	151
152	water	1970-01-01	2023-12-01	2	152
152	water	1970-01-01	2023-12-02	2	152
152	water	1970-01-01	2023-12-03	2	152
152	water	1970-01-01	2023-12-04	2	152
152	water	1970-01-01	2023-12-05	2	152
152	water	1970-01-01	2023-12-06	2	152
152	water	1970-01-01	2023-12-07	2	152
152	water	1970-01-01	2023-12-08	2	152
152	water	1970-01-01	2023-12-09	2	152
152	water	1970-01-01	2023-12-10	2	152
152	water	1970-01-01	2023-12-11	2	152
152	water	1970-01-01	2023-12-12	2	152
152	water	1970-01-01	2023-12-13	2	152
152	water	1970-01-01	2023-12-14	2	152
153	water	1970-01-01	2023-12-01	1	153
153	water	1970-01-01	2023-12-02	1	153
153	water	1970-01-01	2023-12-03	1	153
153	water	1970-01-01	2023-12-04	1	153
153	water	1970-01-01	2023-12-05	1	153
153	water	1970-01-01	2023-12-06	1	153
153	water	1970-01-01	2023-12-07	1	153
153	water	1970-01-01	2023-12-08	1	153
153	water	1970-01-01	2023-12-09	1	153
153	water	1970-01-01	2023-12-10	1	153
153	water	1970-01-01	2023-12-11	1	153
153	water	1970-01-01	2023-12-12	1	153
153	water	1970-01-01	2023-12-13	1	153
153	water	1970-01-01	2023-12-14	1	153
154	water	1970-01-01	2023-12-01	2	154
154	water	1970-01-01	2023-12-02	2	154
154	water	1970-01-01	2023-12-03	2	154
154	water	1970-01-01	2023-12-04	2	154
154	water	1970-01-01	2023-12-05	2	154
154	water	1970-01-01	2023-12-06	2	154
154	water	1970-01-01	2023-12-07	2	154
154	water	1970-01-01	2023-12-08	2	154
154	water	1970-01-01	2023-12-09	2	154
154	water	1970-01-01	2023-12-10	2	154
154	water	1970-01-01	2023-12-11	2	154
154	water	1970-01-01	2023-12-12	2	154
154	water	1970-01-01	2023-12-13	2	154
154	water	1970-01-01	2023-12-14	2	154
155	water	1970-01-01	2023-12-01	1	155
155	water	1970-01-01	2023-12-02	1	155
155	water	1970-01-01	2023-12-03	1	155
155	water	1970-01-01	2023-12-04	1	155
155	water	1970-01-01	2023-12-05	1	155
155	water	1970-01-01	2023-12-06	1	155
155	water	1970-01-01	2023-12-07	1	155
155	water	1970-01-01	2023-12-08	1	155
155	water	1970-01-01	2023-12-09	1	155
155	water	1970-01-01	2023-12-10	1	155
155	water	1970-01-01	2023-12-11	1	155
155	water	1970-01-01	2023-12-12	1	155
155	water	1970-01-01	2023-12-13	1	155
155	water	1970-01-01	2023-12-14	1	155
156	water	1970-01-01	2023-12-01	3	156
156	water	1970-01-01	2023-12-02	3	156
156	water	1970-01-01	2023-12-03	3	156
156	water	1970-01-01	2023-12-04	3	156
156	water	1970-01-01	2023-12-05	3	156
156	water	1970-01-01	2023-12-06	3	156
156	water	1970-01-01	2023-12-07	3	156
156	water	1970-01-01	2023-12-08	3	156
156	water	1970-01-01	2023-12-09	3	156
156	water	1970-01-01	2023-12-10	3	156
156	water	1970-01-01	2023-12-11	3	156
156	water	1970-01-01	2023-12-12	3	156
156	water	1970-01-01	2023-12-13	3	156
156	water	1970-01-01	2023-12-14	3	156
157	water	1970-01-01	2023-12-01	2	157
157	water	1970-01-01	2023-12-02	2	157
157	water	1970-01-01	2023-12-03	2	157
157	water	1970-01-01	2023-12-04	2	157
157	water	1970-01-01	2023-12-05	2	157
157	water	1970-01-01	2023-12-06	2	157
157	water	1970-01-01	2023-12-07	2	157
157	water	1970-01-01	2023-12-08	2	157
157	water	1970-01-01	2023-12-09	2	157
157	water	1970-01-01	2023-12-10	2	157
157	water	1970-01-01	2023-12-11	2	157
157	water	1970-01-01	2023-12-12	2	157
157	water	1970-01-01	2023-12-13	2	157
157	water	1970-01-01	2023-12-14	2	157
158	water	1970-01-01	2023-12-01	1	158
158	water	1970-01-01	2023-12-02	1	158
158	water	1970-01-01	2023-12-03	1	158
158	water	1970-01-01	2023-12-04	1	158
158	water	1970-01-01	2023-12-05	1	158
158	water	1970-01-01	2023-12-06	1	158
158	water	1970-01-01	2023-12-07	1	158
158	water	1970-01-01	2023-12-08	1	158
158	water	1970-01-01	2023-12-09	1	158
158	water	1970-01-01	2023-12-10	1	158
158	water	1970-01-01	2023-12-11	1	158
158	water	1970-01-01	2023-12-12	1	158
158	water	1970-01-01	2023-12-13	1	158
158	water	1970-01-01	2023-12-14	1	158
159	water	1970-01-01	2023-12-01	3	159
159	water	1970-01-01	2023-12-02	3	159
159	water	1970-01-01	2023-12-03	3	159
159	water	1970-01-01	2023-12-04	3	159
159	water	1970-01-01	2023-12-05	3	159
159	water	1970-01-01	2023-12-06	3	159
159	water	1970-01-01	2023-12-07	3	159
159	water	1970-01-01	2023-12-08	3	159
159	water	1970-01-01	2023-12-09	3	159
159	water	1970-01-01	2023-12-10	3	159
159	water	1970-01-01	2023-12-11	3	159
159	water	1970-01-01	2023-12-12	3	159
159	water	1970-01-01	2023-12-13	3	159
159	water	1970-01-01	2023-12-14	3	159
160	water	1970-01-01	2023-12-01	3	160
160	water	1970-01-01	2023-12-02	3	160
160	water	1970-01-01	2023-12-03	3	160
160	water	1970-01-01	2023-12-04	3	160
160	water	1970-01-01	2023-12-05	3	160
160	water	1970-01-01	2023-12-06	3	160
160	water	1970-01-01	2023-12-07	3	160
160	water	1970-01-01	2023-12-08	3	160
160	water	1970-01-01	2023-12-09	3	160
160	water	1970-01-01	2023-12-10	3	160
160	water	1970-01-01	2023-12-11	3	160
160	water	1970-01-01	2023-12-12	3	160
160	water	1970-01-01	2023-12-13	3	160
160	water	1970-01-01	2023-12-14	3	160
161	water	1970-01-01	2023-12-01	3	161
161	water	1970-01-01	2023-12-02	3	161
161	water	1970-01-01	2023-12-03	3	161
161	water	1970-01-01	2023-12-04	3	161
161	water	1970-01-01	2023-12-05	3	161
161	water	1970-01-01	2023-12-06	3	161
161	water	1970-01-01	2023-12-07	3	161
161	water	1970-01-01	2023-12-08	3	161
161	water	1970-01-01	2023-12-09	3	161
161	water	1970-01-01	2023-12-10	3	161
161	water	1970-01-01	2023-12-11	3	161
161	water	1970-01-01	2023-12-12	3	161
161	water	1970-01-01	2023-12-13	3	161
161	water	1970-01-01	2023-12-14	3	161
162	water	1970-01-01	2023-12-01	1	162
162	water	1970-01-01	2023-12-02	1	162
162	water	1970-01-01	2023-12-03	1	162
162	water	1970-01-01	2023-12-04	1	162
162	water	1970-01-01	2023-12-05	1	162
162	water	1970-01-01	2023-12-06	1	162
162	water	1970-01-01	2023-12-07	1	162
162	water	1970-01-01	2023-12-08	1	162
162	water	1970-01-01	2023-12-09	1	162
162	water	1970-01-01	2023-12-10	1	162
162	water	1970-01-01	2023-12-11	1	162
162	water	1970-01-01	2023-12-12	1	162
162	water	1970-01-01	2023-12-13	1	162
162	water	1970-01-01	2023-12-14	1	162
163	water	1970-01-01	2023-12-01	2	163
163	water	1970-01-01	2023-12-02	2	163
163	water	1970-01-01	2023-12-03	2	163
163	water	1970-01-01	2023-12-04	2	163
163	water	1970-01-01	2023-12-05	2	163
163	water	1970-01-01	2023-12-06	2	163
163	water	1970-01-01	2023-12-07	2	163
163	water	1970-01-01	2023-12-08	2	163
163	water	1970-01-01	2023-12-09	2	163
163	water	1970-01-01	2023-12-10	2	163
163	water	1970-01-01	2023-12-11	2	163
163	water	1970-01-01	2023-12-12	2	163
163	water	1970-01-01	2023-12-13	2	163
163	water	1970-01-01	2023-12-14	2	163
164	water	1970-01-01	2023-12-01	1	164
164	water	1970-01-01	2023-12-02	1	164
164	water	1970-01-01	2023-12-03	1	164
164	water	1970-01-01	2023-12-04	1	164
164	water	1970-01-01	2023-12-05	1	164
164	water	1970-01-01	2023-12-06	1	164
164	water	1970-01-01	2023-12-07	1	164
164	water	1970-01-01	2023-12-08	1	164
164	water	1970-01-01	2023-12-09	1	164
164	water	1970-01-01	2023-12-10	1	164
164	water	1970-01-01	2023-12-11	1	164
164	water	1970-01-01	2023-12-12	1	164
164	water	1970-01-01	2023-12-13	1	164
164	water	1970-01-01	2023-12-14	1	164
165	water	1970-01-01	2023-12-01	2	165
165	water	1970-01-01	2023-12-02	2	165
165	water	1970-01-01	2023-12-03	2	165
165	water	1970-01-01	2023-12-04	2	165
165	water	1970-01-01	2023-12-05	2	165
165	water	1970-01-01	2023-12-06	2	165
165	water	1970-01-01	2023-12-07	2	165
165	water	1970-01-01	2023-12-08	2	165
165	water	1970-01-01	2023-12-09	2	165
165	water	1970-01-01	2023-12-10	2	165
165	water	1970-01-01	2023-12-11	2	165
165	water	1970-01-01	2023-12-12	2	165
165	water	1970-01-01	2023-12-13	2	165
165	water	1970-01-01	2023-12-14	2	165
166	water	1970-01-01	2023-12-01	3	166
166	water	1970-01-01	2023-12-02	3	166
166	water	1970-01-01	2023-12-03	3	166
166	water	1970-01-01	2023-12-04	3	166
166	water	1970-01-01	2023-12-05	3	166
166	water	1970-01-01	2023-12-06	3	166
166	water	1970-01-01	2023-12-07	3	166
166	water	1970-01-01	2023-12-08	3	166
166	water	1970-01-01	2023-12-09	3	166
166	water	1970-01-01	2023-12-10	3	166
166	water	1970-01-01	2023-12-11	3	166
166	water	1970-01-01	2023-12-12	3	166
166	water	1970-01-01	2023-12-13	3	166
166	water	1970-01-01	2023-12-14	3	166
167	water	1970-01-01	2023-12-01	1	167
167	water	1970-01-01	2023-12-02	1	167
167	water	1970-01-01	2023-12-03	1	167
167	water	1970-01-01	2023-12-04	1	167
167	water	1970-01-01	2023-12-05	1	167
167	water	1970-01-01	2023-12-06	1	167
167	water	1970-01-01	2023-12-07	1	167
167	water	1970-01-01	2023-12-08	1	167
167	water	1970-01-01	2023-12-09	1	167
167	water	1970-01-01	2023-12-10	1	167
167	water	1970-01-01	2023-12-11	1	167
167	water	1970-01-01	2023-12-12	1	167
167	water	1970-01-01	2023-12-13	1	167
167	water	1970-01-01	2023-12-14	1	167
168	water	1970-01-01	2023-12-01	2	168
168	water	1970-01-01	2023-12-02	2	168
168	water	1970-01-01	2023-12-03	2	168
168	water	1970-01-01	2023-12-04	2	168
168	water	1970-01-01	2023-12-05	2	168
168	water	1970-01-01	2023-12-06	2	168
168	water	1970-01-01	2023-12-07	2	168
168	water	1970-01-01	2023-12-08	2	168
168	water	1970-01-01	2023-12-09	2	168
168	water	1970-01-01	2023-12-10	2	168
168	water	1970-01-01	2023-12-11	2	168
168	water	1970-01-01	2023-12-12	2	168
168	water	1970-01-01	2023-12-13	2	168
168	water	1970-01-01	2023-12-14	2	168
169	water	1970-01-01	2023-12-01	3	169
169	water	1970-01-01	2023-12-02	3	169
169	water	1970-01-01	2023-12-03	3	169
169	water	1970-01-01	2023-12-04	3	169
169	water	1970-01-01	2023-12-05	3	169
169	water	1970-01-01	2023-12-06	3	169
169	water	1970-01-01	2023-12-07	3	169
169	water	1970-01-01	2023-12-08	3	169
169	water	1970-01-01	2023-12-09	3	169
169	water	1970-01-01	2023-12-10	3	169
169	water	1970-01-01	2023-12-11	3	169
169	water	1970-01-01	2023-12-12	3	169
169	water	1970-01-01	2023-12-13	3	169
169	water	1970-01-01	2023-12-14	3	169
170	water	1970-01-01	2023-12-01	3	170
170	water	1970-01-01	2023-12-02	3	170
170	water	1970-01-01	2023-12-03	3	170
170	water	1970-01-01	2023-12-04	3	170
170	water	1970-01-01	2023-12-05	3	170
170	water	1970-01-01	2023-12-06	3	170
170	water	1970-01-01	2023-12-07	3	170
170	water	1970-01-01	2023-12-08	3	170
170	water	1970-01-01	2023-12-09	3	170
170	water	1970-01-01	2023-12-10	3	170
170	water	1970-01-01	2023-12-11	3	170
170	water	1970-01-01	2023-12-12	3	170
170	water	1970-01-01	2023-12-13	3	170
170	water	1970-01-01	2023-12-14	3	170
171	water	1970-01-01	2023-12-01	1	171
171	water	1970-01-01	2023-12-02	1	171
171	water	1970-01-01	2023-12-03	1	171
171	water	1970-01-01	2023-12-04	1	171
171	water	1970-01-01	2023-12-05	1	171
171	water	1970-01-01	2023-12-06	1	171
171	water	1970-01-01	2023-12-07	1	171
171	water	1970-01-01	2023-12-08	1	171
171	water	1970-01-01	2023-12-09	1	171
171	water	1970-01-01	2023-12-10	1	171
171	water	1970-01-01	2023-12-11	1	171
171	water	1970-01-01	2023-12-12	1	171
171	water	1970-01-01	2023-12-13	1	171
171	water	1970-01-01	2023-12-14	1	171
172	water	1970-01-01	2023-12-01	1	172
172	water	1970-01-01	2023-12-02	1	172
172	water	1970-01-01	2023-12-03	1	172
172	water	1970-01-01	2023-12-04	1	172
172	water	1970-01-01	2023-12-05	1	172
172	water	1970-01-01	2023-12-06	1	172
172	water	1970-01-01	2023-12-07	1	172
172	water	1970-01-01	2023-12-08	1	172
172	water	1970-01-01	2023-12-09	1	172
172	water	1970-01-01	2023-12-10	1	172
172	water	1970-01-01	2023-12-11	1	172
172	water	1970-01-01	2023-12-12	1	172
172	water	1970-01-01	2023-12-13	1	172
172	water	1970-01-01	2023-12-14	1	172
173	water	1970-01-01	2023-12-01	1	173
173	water	1970-01-01	2023-12-02	1	173
173	water	1970-01-01	2023-12-03	1	173
173	water	1970-01-01	2023-12-04	1	173
173	water	1970-01-01	2023-12-05	1	173
173	water	1970-01-01	2023-12-06	1	173
173	water	1970-01-01	2023-12-07	1	173
173	water	1970-01-01	2023-12-08	1	173
173	water	1970-01-01	2023-12-09	1	173
173	water	1970-01-01	2023-12-10	1	173
173	water	1970-01-01	2023-12-11	1	173
173	water	1970-01-01	2023-12-12	1	173
173	water	1970-01-01	2023-12-13	1	173
173	water	1970-01-01	2023-12-14	1	173
174	water	1970-01-01	2023-12-01	3	174
174	water	1970-01-01	2023-12-02	3	174
174	water	1970-01-01	2023-12-03	3	174
174	water	1970-01-01	2023-12-04	3	174
174	water	1970-01-01	2023-12-05	3	174
174	water	1970-01-01	2023-12-06	3	174
174	water	1970-01-01	2023-12-07	3	174
174	water	1970-01-01	2023-12-08	3	174
174	water	1970-01-01	2023-12-09	3	174
174	water	1970-01-01	2023-12-10	3	174
174	water	1970-01-01	2023-12-11	3	174
174	water	1970-01-01	2023-12-12	3	174
174	water	1970-01-01	2023-12-13	3	174
174	water	1970-01-01	2023-12-14	3	174
175	water	1970-01-01	2023-12-01	1	175
175	water	1970-01-01	2023-12-02	1	175
175	water	1970-01-01	2023-12-03	1	175
175	water	1970-01-01	2023-12-04	1	175
175	water	1970-01-01	2023-12-05	1	175
175	water	1970-01-01	2023-12-06	1	175
175	water	1970-01-01	2023-12-07	1	175
175	water	1970-01-01	2023-12-08	1	175
175	water	1970-01-01	2023-12-09	1	175
175	water	1970-01-01	2023-12-10	1	175
175	water	1970-01-01	2023-12-11	1	175
175	water	1970-01-01	2023-12-12	1	175
175	water	1970-01-01	2023-12-13	1	175
175	water	1970-01-01	2023-12-14	1	175
176	water	1970-01-01	2023-12-01	3	176
176	water	1970-01-01	2023-12-02	3	176
176	water	1970-01-01	2023-12-03	3	176
176	water	1970-01-01	2023-12-04	3	176
176	water	1970-01-01	2023-12-05	3	176
176	water	1970-01-01	2023-12-06	3	176
176	water	1970-01-01	2023-12-07	3	176
176	water	1970-01-01	2023-12-08	3	176
176	water	1970-01-01	2023-12-09	3	176
176	water	1970-01-01	2023-12-10	3	176
176	water	1970-01-01	2023-12-11	3	176
176	water	1970-01-01	2023-12-12	3	176
176	water	1970-01-01	2023-12-13	3	176
176	water	1970-01-01	2023-12-14	3	176
177	water	1970-01-01	2023-12-01	3	177
177	water	1970-01-01	2023-12-02	3	177
177	water	1970-01-01	2023-12-03	3	177
177	water	1970-01-01	2023-12-04	3	177
177	water	1970-01-01	2023-12-05	3	177
177	water	1970-01-01	2023-12-06	3	177
177	water	1970-01-01	2023-12-07	3	177
177	water	1970-01-01	2023-12-08	3	177
177	water	1970-01-01	2023-12-09	3	177
177	water	1970-01-01	2023-12-10	3	177
177	water	1970-01-01	2023-12-11	3	177
177	water	1970-01-01	2023-12-12	3	177
177	water	1970-01-01	2023-12-13	3	177
177	water	1970-01-01	2023-12-14	3	177
178	water	1970-01-01	2023-12-01	2	178
178	water	1970-01-01	2023-12-02	2	178
178	water	1970-01-01	2023-12-03	2	178
178	water	1970-01-01	2023-12-04	2	178
178	water	1970-01-01	2023-12-05	2	178
178	water	1970-01-01	2023-12-06	2	178
178	water	1970-01-01	2023-12-07	2	178
178	water	1970-01-01	2023-12-08	2	178
178	water	1970-01-01	2023-12-09	2	178
178	water	1970-01-01	2023-12-10	2	178
178	water	1970-01-01	2023-12-11	2	178
178	water	1970-01-01	2023-12-12	2	178
178	water	1970-01-01	2023-12-13	2	178
178	water	1970-01-01	2023-12-14	2	178
179	water	1970-01-01	2023-12-01	2	179
179	water	1970-01-01	2023-12-02	2	179
179	water	1970-01-01	2023-12-03	2	179
179	water	1970-01-01	2023-12-04	2	179
179	water	1970-01-01	2023-12-05	2	179
179	water	1970-01-01	2023-12-06	2	179
179	water	1970-01-01	2023-12-07	2	179
179	water	1970-01-01	2023-12-08	2	179
179	water	1970-01-01	2023-12-09	2	179
179	water	1970-01-01	2023-12-10	2	179
179	water	1970-01-01	2023-12-11	2	179
179	water	1970-01-01	2023-12-12	2	179
179	water	1970-01-01	2023-12-13	2	179
179	water	1970-01-01	2023-12-14	2	179
180	water	1970-01-01	2023-12-01	1	180
180	water	1970-01-01	2023-12-02	1	180
180	water	1970-01-01	2023-12-03	1	180
180	water	1970-01-01	2023-12-04	1	180
180	water	1970-01-01	2023-12-05	1	180
180	water	1970-01-01	2023-12-06	1	180
180	water	1970-01-01	2023-12-07	1	180
180	water	1970-01-01	2023-12-08	1	180
180	water	1970-01-01	2023-12-09	1	180
180	water	1970-01-01	2023-12-10	1	180
180	water	1970-01-01	2023-12-11	1	180
180	water	1970-01-01	2023-12-12	1	180
180	water	1970-01-01	2023-12-13	1	180
180	water	1970-01-01	2023-12-14	1	180
181	water	1970-01-01	2023-12-01	3	181
181	water	1970-01-01	2023-12-02	3	181
181	water	1970-01-01	2023-12-03	3	181
181	water	1970-01-01	2023-12-04	3	181
181	water	1970-01-01	2023-12-05	3	181
181	water	1970-01-01	2023-12-06	3	181
181	water	1970-01-01	2023-12-07	3	181
181	water	1970-01-01	2023-12-08	3	181
181	water	1970-01-01	2023-12-09	3	181
181	water	1970-01-01	2023-12-10	3	181
181	water	1970-01-01	2023-12-11	3	181
181	water	1970-01-01	2023-12-12	3	181
181	water	1970-01-01	2023-12-13	3	181
181	water	1970-01-01	2023-12-14	3	181
182	water	1970-01-01	2023-12-01	1	182
182	water	1970-01-01	2023-12-02	1	182
182	water	1970-01-01	2023-12-03	1	182
182	water	1970-01-01	2023-12-04	1	182
182	water	1970-01-01	2023-12-05	1	182
182	water	1970-01-01	2023-12-06	1	182
182	water	1970-01-01	2023-12-07	1	182
182	water	1970-01-01	2023-12-08	1	182
182	water	1970-01-01	2023-12-09	1	182
182	water	1970-01-01	2023-12-10	1	182
182	water	1970-01-01	2023-12-11	1	182
182	water	1970-01-01	2023-12-12	1	182
182	water	1970-01-01	2023-12-13	1	182
182	water	1970-01-01	2023-12-14	1	182
183	water	1970-01-01	2023-12-01	2	183
183	water	1970-01-01	2023-12-02	2	183
183	water	1970-01-01	2023-12-03	2	183
183	water	1970-01-01	2023-12-04	2	183
183	water	1970-01-01	2023-12-05	2	183
183	water	1970-01-01	2023-12-06	2	183
183	water	1970-01-01	2023-12-07	2	183
183	water	1970-01-01	2023-12-08	2	183
183	water	1970-01-01	2023-12-09	2	183
183	water	1970-01-01	2023-12-10	2	183
183	water	1970-01-01	2023-12-11	2	183
183	water	1970-01-01	2023-12-12	2	183
183	water	1970-01-01	2023-12-13	2	183
183	water	1970-01-01	2023-12-14	2	183
184	water	1970-01-01	2023-12-01	1	184
184	water	1970-01-01	2023-12-02	1	184
184	water	1970-01-01	2023-12-03	1	184
184	water	1970-01-01	2023-12-04	1	184
184	water	1970-01-01	2023-12-05	1	184
184	water	1970-01-01	2023-12-06	1	184
184	water	1970-01-01	2023-12-07	1	184
184	water	1970-01-01	2023-12-08	1	184
184	water	1970-01-01	2023-12-09	1	184
184	water	1970-01-01	2023-12-10	1	184
184	water	1970-01-01	2023-12-11	1	184
184	water	1970-01-01	2023-12-12	1	184
184	water	1970-01-01	2023-12-13	1	184
184	water	1970-01-01	2023-12-14	1	184
185	water	1970-01-01	2023-12-01	2	185
185	water	1970-01-01	2023-12-02	2	185
185	water	1970-01-01	2023-12-03	2	185
185	water	1970-01-01	2023-12-04	2	185
185	water	1970-01-01	2023-12-05	2	185
185	water	1970-01-01	2023-12-06	2	185
185	water	1970-01-01	2023-12-07	2	185
185	water	1970-01-01	2023-12-08	2	185
185	water	1970-01-01	2023-12-09	2	185
185	water	1970-01-01	2023-12-10	2	185
185	water	1970-01-01	2023-12-11	2	185
185	water	1970-01-01	2023-12-12	2	185
185	water	1970-01-01	2023-12-13	2	185
185	water	1970-01-01	2023-12-14	2	185
186	water	1970-01-01	2023-12-01	2	186
186	water	1970-01-01	2023-12-02	2	186
186	water	1970-01-01	2023-12-03	2	186
186	water	1970-01-01	2023-12-04	2	186
186	water	1970-01-01	2023-12-05	2	186
186	water	1970-01-01	2023-12-06	2	186
186	water	1970-01-01	2023-12-07	2	186
186	water	1970-01-01	2023-12-08	2	186
186	water	1970-01-01	2023-12-09	2	186
186	water	1970-01-01	2023-12-10	2	186
186	water	1970-01-01	2023-12-11	2	186
186	water	1970-01-01	2023-12-12	2	186
186	water	1970-01-01	2023-12-13	2	186
186	water	1970-01-01	2023-12-14	2	186
187	water	1970-01-01	2023-12-01	1	187
187	water	1970-01-01	2023-12-02	1	187
187	water	1970-01-01	2023-12-03	1	187
187	water	1970-01-01	2023-12-04	1	187
187	water	1970-01-01	2023-12-05	1	187
187	water	1970-01-01	2023-12-06	1	187
187	water	1970-01-01	2023-12-07	1	187
187	water	1970-01-01	2023-12-08	1	187
187	water	1970-01-01	2023-12-09	1	187
187	water	1970-01-01	2023-12-10	1	187
187	water	1970-01-01	2023-12-11	1	187
187	water	1970-01-01	2023-12-12	1	187
187	water	1970-01-01	2023-12-13	1	187
187	water	1970-01-01	2023-12-14	1	187
188	water	1970-01-01	2023-12-01	1	188
188	water	1970-01-01	2023-12-02	1	188
188	water	1970-01-01	2023-12-03	1	188
188	water	1970-01-01	2023-12-04	1	188
188	water	1970-01-01	2023-12-05	1	188
188	water	1970-01-01	2023-12-06	1	188
188	water	1970-01-01	2023-12-07	1	188
188	water	1970-01-01	2023-12-08	1	188
188	water	1970-01-01	2023-12-09	1	188
188	water	1970-01-01	2023-12-10	1	188
188	water	1970-01-01	2023-12-11	1	188
188	water	1970-01-01	2023-12-12	1	188
188	water	1970-01-01	2023-12-13	1	188
188	water	1970-01-01	2023-12-14	1	188
189	water	1970-01-01	2023-12-01	1	189
189	water	1970-01-01	2023-12-02	1	189
189	water	1970-01-01	2023-12-03	1	189
189	water	1970-01-01	2023-12-04	1	189
189	water	1970-01-01	2023-12-05	1	189
189	water	1970-01-01	2023-12-06	1	189
189	water	1970-01-01	2023-12-07	1	189
189	water	1970-01-01	2023-12-08	1	189
189	water	1970-01-01	2023-12-09	1	189
189	water	1970-01-01	2023-12-10	1	189
189	water	1970-01-01	2023-12-11	1	189
189	water	1970-01-01	2023-12-12	1	189
189	water	1970-01-01	2023-12-13	1	189
189	water	1970-01-01	2023-12-14	1	189
190	water	1970-01-01	2023-12-01	3	190
190	water	1970-01-01	2023-12-02	3	190
190	water	1970-01-01	2023-12-03	3	190
190	water	1970-01-01	2023-12-04	3	190
190	water	1970-01-01	2023-12-05	3	190
190	water	1970-01-01	2023-12-06	3	190
190	water	1970-01-01	2023-12-07	3	190
190	water	1970-01-01	2023-12-08	3	190
190	water	1970-01-01	2023-12-09	3	190
190	water	1970-01-01	2023-12-10	3	190
190	water	1970-01-01	2023-12-11	3	190
190	water	1970-01-01	2023-12-12	3	190
190	water	1970-01-01	2023-12-13	3	190
190	water	1970-01-01	2023-12-14	3	190
191	water	1970-01-01	2023-12-01	3	191
191	water	1970-01-01	2023-12-02	3	191
191	water	1970-01-01	2023-12-03	3	191
191	water	1970-01-01	2023-12-04	3	191
191	water	1970-01-01	2023-12-05	3	191
191	water	1970-01-01	2023-12-06	3	191
191	water	1970-01-01	2023-12-07	3	191
191	water	1970-01-01	2023-12-08	3	191
191	water	1970-01-01	2023-12-09	3	191
191	water	1970-01-01	2023-12-10	3	191
191	water	1970-01-01	2023-12-11	3	191
191	water	1970-01-01	2023-12-12	3	191
191	water	1970-01-01	2023-12-13	3	191
191	water	1970-01-01	2023-12-14	3	191
192	water	1970-01-01	2023-12-01	3	192
192	water	1970-01-01	2023-12-02	3	192
192	water	1970-01-01	2023-12-03	3	192
192	water	1970-01-01	2023-12-04	3	192
192	water	1970-01-01	2023-12-05	3	192
192	water	1970-01-01	2023-12-06	3	192
192	water	1970-01-01	2023-12-07	3	192
192	water	1970-01-01	2023-12-08	3	192
192	water	1970-01-01	2023-12-09	3	192
192	water	1970-01-01	2023-12-10	3	192
192	water	1970-01-01	2023-12-11	3	192
192	water	1970-01-01	2023-12-12	3	192
192	water	1970-01-01	2023-12-13	3	192
192	water	1970-01-01	2023-12-14	3	192
193	water	1970-01-01	2023-12-01	1	193
193	water	1970-01-01	2023-12-02	1	193
193	water	1970-01-01	2023-12-03	1	193
193	water	1970-01-01	2023-12-04	1	193
193	water	1970-01-01	2023-12-05	1	193
193	water	1970-01-01	2023-12-06	1	193
193	water	1970-01-01	2023-12-07	1	193
193	water	1970-01-01	2023-12-08	1	193
193	water	1970-01-01	2023-12-09	1	193
193	water	1970-01-01	2023-12-10	1	193
193	water	1970-01-01	2023-12-11	1	193
193	water	1970-01-01	2023-12-12	1	193
193	water	1970-01-01	2023-12-13	1	193
193	water	1970-01-01	2023-12-14	1	193
194	water	1970-01-01	2023-12-01	2	194
194	water	1970-01-01	2023-12-02	2	194
194	water	1970-01-01	2023-12-03	2	194
194	water	1970-01-01	2023-12-04	2	194
194	water	1970-01-01	2023-12-05	2	194
194	water	1970-01-01	2023-12-06	2	194
194	water	1970-01-01	2023-12-07	2	194
194	water	1970-01-01	2023-12-08	2	194
194	water	1970-01-01	2023-12-09	2	194
194	water	1970-01-01	2023-12-10	2	194
194	water	1970-01-01	2023-12-11	2	194
194	water	1970-01-01	2023-12-12	2	194
194	water	1970-01-01	2023-12-13	2	194
194	water	1970-01-01	2023-12-14	2	194
195	water	1970-01-01	2023-12-01	3	195
195	water	1970-01-01	2023-12-02	3	195
195	water	1970-01-01	2023-12-03	3	195
195	water	1970-01-01	2023-12-04	3	195
195	water	1970-01-01	2023-12-05	3	195
195	water	1970-01-01	2023-12-06	3	195
195	water	1970-01-01	2023-12-07	3	195
195	water	1970-01-01	2023-12-08	3	195
195	water	1970-01-01	2023-12-09	3	195
195	water	1970-01-01	2023-12-10	3	195
195	water	1970-01-01	2023-12-11	3	195
195	water	1970-01-01	2023-12-12	3	195
195	water	1970-01-01	2023-12-13	3	195
195	water	1970-01-01	2023-12-14	3	195
196	water	1970-01-01	2023-12-01	2	196
196	water	1970-01-01	2023-12-02	2	196
196	water	1970-01-01	2023-12-03	2	196
196	water	1970-01-01	2023-12-04	2	196
196	water	1970-01-01	2023-12-05	2	196
196	water	1970-01-01	2023-12-06	2	196
196	water	1970-01-01	2023-12-07	2	196
196	water	1970-01-01	2023-12-08	2	196
196	water	1970-01-01	2023-12-09	2	196
196	water	1970-01-01	2023-12-10	2	196
196	water	1970-01-01	2023-12-11	2	196
196	water	1970-01-01	2023-12-12	2	196
196	water	1970-01-01	2023-12-13	2	196
196	water	1970-01-01	2023-12-14	2	196
197	water	1970-01-01	2023-12-01	2	197
197	water	1970-01-01	2023-12-02	2	197
197	water	1970-01-01	2023-12-03	2	197
197	water	1970-01-01	2023-12-04	2	197
197	water	1970-01-01	2023-12-05	2	197
197	water	1970-01-01	2023-12-06	2	197
197	water	1970-01-01	2023-12-07	2	197
197	water	1970-01-01	2023-12-08	2	197
197	water	1970-01-01	2023-12-09	2	197
197	water	1970-01-01	2023-12-10	2	197
197	water	1970-01-01	2023-12-11	2	197
197	water	1970-01-01	2023-12-12	2	197
197	water	1970-01-01	2023-12-13	2	197
197	water	1970-01-01	2023-12-14	2	197
198	water	1970-01-01	2023-12-01	2	198
198	water	1970-01-01	2023-12-02	2	198
198	water	1970-01-01	2023-12-03	2	198
198	water	1970-01-01	2023-12-04	2	198
198	water	1970-01-01	2023-12-05	2	198
198	water	1970-01-01	2023-12-06	2	198
198	water	1970-01-01	2023-12-07	2	198
198	water	1970-01-01	2023-12-08	2	198
198	water	1970-01-01	2023-12-09	2	198
198	water	1970-01-01	2023-12-10	2	198
198	water	1970-01-01	2023-12-11	2	198
198	water	1970-01-01	2023-12-12	2	198
198	water	1970-01-01	2023-12-13	2	198
198	water	1970-01-01	2023-12-14	2	198
199	water	1970-01-01	2023-12-01	2	199
199	water	1970-01-01	2023-12-02	2	199
199	water	1970-01-01	2023-12-03	2	199
199	water	1970-01-01	2023-12-04	2	199
199	water	1970-01-01	2023-12-05	2	199
199	water	1970-01-01	2023-12-06	2	199
199	water	1970-01-01	2023-12-07	2	199
199	water	1970-01-01	2023-12-08	2	199
199	water	1970-01-01	2023-12-09	2	199
199	water	1970-01-01	2023-12-10	2	199
199	water	1970-01-01	2023-12-11	2	199
199	water	1970-01-01	2023-12-12	2	199
199	water	1970-01-01	2023-12-13	2	199
199	water	1970-01-01	2023-12-14	2	199
200	water	1970-01-01	2023-12-01	1	200
200	water	1970-01-01	2023-12-02	1	200
200	water	1970-01-01	2023-12-03	1	200
200	water	1970-01-01	2023-12-04	1	200
200	water	1970-01-01	2023-12-05	1	200
200	water	1970-01-01	2023-12-06	1	200
200	water	1970-01-01	2023-12-07	1	200
200	water	1970-01-01	2023-12-08	1	200
200	water	1970-01-01	2023-12-09	1	200
200	water	1970-01-01	2023-12-10	1	200
200	water	1970-01-01	2023-12-11	1	200
200	water	1970-01-01	2023-12-12	1	200
200	water	1970-01-01	2023-12-13	1	200
200	water	1970-01-01	2023-12-14	1	200
\.


--
-- TOC entry 4987 (class 0 OID 17242)
-- Dependencies: 233
-- Data for Name: edge_in_path; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.edge_in_path (path_id, start_station, end_station, estimated_time_minute, distance_km) FROM stdin;
1	1	2	20	2
1	2	3	23	1
1	3	4	29	2
1	4	5	16	1
1	5	6	20	2
2	6	7	25	1
2	7	8	18	2
2	8	9	29	1
2	9	10	15	2
2	10	11	30	1
3	11	12	25	2
3	12	13	15	1
3	13	14	11	2
3	14	15	18	1
3	15	16	28	2
4	16	17	30	1
4	17	18	15	2
4	18	19	11	1
4	19	20	17	2
4	20	21	14	1
5	21	22	30	2
5	22	23	20	1
5	23	24	12	2
5	24	25	22	1
5	25	26	10	2
6	26	27	13	1
6	27	28	20	2
6	28	29	30	1
6	29	30	30	2
6	30	1	25	1
\.


--
-- TOC entry 4971 (class 0 OID 17099)
-- Dependencies: 217
-- Data for Name: house; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.house (house_id, owner, street, alley, postal_code, location) FROM stdin;
1	1	mjykernox	bhlncodq	114760398210	(559,509)
2	2	bgham	yaiyx	249032542462	(23,82)
3	3	ggezypvjau	toodjbquyz	858033563554	(799,22)
4	4	qnhoe	ipwbmjpm	453137297403	(366,690)
5	5	ewujacpgd	gpfjlj	995859800672	(741,75)
6	6	rsktbqhnrn	manlvf	395274222409	(599,815)
7	7	ixsck	wkuhqmt	705531644915	(997,861)
8	8	qfovzhn	cbmkjk	912651346973	(473,673)
9	9	ylfpg	hvuamdsx	514845788487	(16,616)
10	10	ksjtqj	mdwbr	550981820165	(564,409)
11	11	fhcygomgi	cjgli	152215636000	(419,764)
12	12	cdplsl	nmommq	935534504501	(659,437)
13	13	jyuetxmghv	nfqni	996968819106	(658,811)
14	14	dhnfc	qyzzb	171380620326	(852,508)
15	15	stadkhuz	efrjoo	587420279340	(84,418)
16	16	ukwhebcoeu	kwvqoo	654889371912	(864,106)
17	17	rlaytbynk	axunkl	995130786538	(278,202)
18	18	ovrseg	evrza	637491240660	(532,328)
19	19	aggzl	zvpanujhl	610358673343	(994,492)
20	20	sifehgl	srwfgppcr	276969593356	(503,362)
21	21	igdmjdemb	evoueszci	892918906156	(67,61)
22	22	tfrhoa	klexodby	103895919468	(328,996)
23	23	hawxiujw	uvkqmpkf	663890816460	(383,361)
24	24	rjmdgvau	jbycwxkvf	291511162103	(484,859)
25	25	tgugz	bhhuf	973215129956	(170,103)
26	26	cccaht	aabwqcvr	204450041532	(983,482)
27	27	djcujlnrxy	nrxajrbjvb	322237371474	(154,826)
28	28	rfmdgpqde	ecfxxbcx	778663254817	(434,170)
29	29	mqcno	kukkvimvw	741453665824	(878,239)
30	30	hhxlz	btgfuyhrjp	102414925372	(695,221)
31	31	dcgtoi	ktlngcp	218573438296	(44,827)
32	32	cfjvxfjld	mofcvwnsc	870966060068	(539,737)
33	33	shwyuoyz	zksdp	512014191398	(42,326)
34	34	qbeulhweph	ipwzyw	482698212890	(112,430)
35	35	nesteiyk	ahxzbf	199590975016	(545,297)
36	36	fqxrrxbz	xicwmljm	523315526436	(76,475)
37	37	ruzlpxxbo	qnnwkn	211014810022	(293,189)
38	38	fgogkcnv	kropwhqrgc	542564366936	(88,352)
39	39	ketbwp	uuwpb	178009708127	(6,839)
40	40	xdyxfu	pzfnb	552217777591	(18,665)
41	41	kybrrer	ampbrs	146026902222	(150,303)
42	42	tarteyoyrc	yuvts	746006172089	(765,522)
43	43	qgtibae	aigaoh	577336735247	(273,66)
44	44	lvpase	yroctjb	395659439585	(956,600)
45	45	rlyao	ofsvjznh	865617477840	(943,549)
46	46	jeoanxd	bxqgnedx	725842767142	(142,940)
47	47	mlchutijl	hdpgpybyn	466279754466	(212,49)
48	48	fasla	mriyojuif	533837967380	(137,522)
49	49	utmwrobrfj	rbvzabxsr	444442441035	(518,982)
50	50	zgfvnyl	baqmg	413224896115	(717,575)
51	51	qixudkxkr	vddilbwmn	851391081173	(732,321)
52	52	pbwbdh	dfqoansin	958016460912	(879,47)
53	53	oizwvdzcxq	mfgsgr	610878504922	(211,101)
54	54	hcxbtif	picfbyzryt	503366010776	(832,723)
55	55	pkphcpf	nqgzonvr	686809036734	(74,580)
56	56	otvshnv	jwzehtli	756428707255	(297,277)
57	57	iwfqjuqpch	lezxq	545979070779	(922,777)
58	58	wfjcktbzu	mwlnajgup	617692489449	(609,760)
59	59	kkjwiiuze	wfvnzqtiaf	706398691806	(30,407)
60	60	fqqbzeaxom	tutyhadg	570452004183	(34,88)
61	61	czybxsciqk	ncmcoewsc	361187953960	(679,287)
62	62	ntnkjiw	sfoykedur	472732454589	(903,401)
63	63	fainqqctos	bmgjq	960343590898	(551,816)
64	64	afufg	ezuyxawk	202093462704	(44,826)
65	65	rhymy	fmuotn	400429867090	(655,300)
66	66	gdrpwmsgcs	oqncxl	211798219673	(656,426)
67	67	cfocwh	wvcvrpu	277547869722	(224,808)
68	68	twusqfehgr	ylypvexup	912781272980	(219,634)
69	69	jwftfwuey	xznamhwqnx	109297240061	(679,49)
70	70	xxfesoy	mfebqtvo	611813131266	(489,932)
71	71	tbnxsdik	vwngrtrya	604666865842	(50,520)
72	72	lgdoi	ukuac	378660626921	(815,335)
73	73	lufzynsn	bbjyqrklu	573097252135	(623,265)
74	74	ldkbgg	nhhcneoxfy	759390133968	(664,706)
75	75	gbsenr	bhdfgqbxy	650064193611	(297,787)
76	76	ufvwcafm	yimcj	236312067687	(882,59)
77	77	jkrmyho	bdgenhby	916529892857	(176,234)
78	78	ykeln	rluhr	143540018611	(378,956)
79	79	quoxqbvuld	oledaw	415501156192	(111,489)
80	80	vlnacfuacc	ckgaeoniq	971519205299	(352,964)
81	81	mtvoxoch	tbgrsxyo	924053288446	(890,180)
82	82	uuxxg	evngegt	945383630508	(928,900)
83	83	jauyno	bpmdtub	424362044325	(270,683)
84	84	ltwqcbyye	skeuzmr	859495130296	(357,852)
85	85	elfyt	ukupg	226412009323	(537,693)
86	86	bfgqzbdm	ioplnje	914480261889	(48,624)
87	87	yebozgha	hyxijg	842924448854	(525,288)
88	88	nsjqcdiic	orbyvfmnnd	653304733559	(800,278)
89	89	kneeuvakyn	lcucrrq	675026366840	(296,432)
90	90	qmxerrfjk	qyxvt	844600309680	(222,764)
91	91	sdokrsondb	eqrbmlxpa	935719852863	(891,849)
92	92	ycpkmulnm	vniwpup	798583350203	(790,31)
93	93	vzrbzd	xoytimfltz	659174963450	(543,402)
94	94	jpmfhe	gquqmbohz	531628852951	(471,408)
95	95	gjogyejssm	cvvzt	391339529046	(262,47)
96	96	turhcjr	pfdtnspgi	978653264471	(647,648)
97	97	ltnezwuy	qqusapr	161822557996	(299,338)
98	98	trexxd	bbrtnzjbml	658203291811	(293,572)
99	99	nydmcxxfu	eknlpktovp	820598259408	(0,355)
100	100	ddxpd	dkazkhofq	862784139175	(301,764)
101	101	bolvse	qqjcenkthm	979512542601	(783,412)
102	102	izwmkhti	vkkkyfxcqa	620347130714	(777,655)
103	103	kumsdvfn	aflxh	710505874394	(305,820)
104	104	cdlocvwb	yuahdgy	596686345342	(11,518)
105	105	yzqiw	mtjihbvna	554584466804	(178,356)
106	106	mnuddwnd	owzvutdl	195721986659	(217,926)
107	107	klzykdb	qfjsjqgmkq	275919664087	(179,500)
108	108	svbeoi	vgfhg	444423920323	(297,233)
109	109	bzybxqlw	upyaqocv	560926409594	(704,149)
110	110	amvwb	cbcmuiij	497977427566	(150,860)
111	111	wpvtmhs	vzvpmgngjo	512465459995	(716,503)
112	112	qsbmtnz	qodnb	794326180309	(123,849)
113	113	btjcltmjbg	oezdpfubz	500000980027	(557,862)
114	114	ksgnlog	ukknhralc	853383022543	(676,191)
115	115	kohwb	bhbve	890199695956	(618,134)
116	116	mzmwzahamm	bmckxzmum	115052690995	(121,33)
117	117	wbsnhx	jbcuvrqz	249460599472	(72,616)
118	118	lggatwfmlm	dytqyw	778804863138	(41,19)
119	119	ijzbspjdxc	ocrywod	344991990214	(257,456)
120	120	zrggr	uooyaqsbpt	932150931454	(842,632)
121	121	lpjupyqzs	uzbzrimcq	532136942718	(422,276)
122	122	pujgcskzdw	iwbmilbt	475171866937	(955,468)
123	123	rilat	dkepxec	813127735490	(997,168)
124	124	bxouroj	rfzzpxh	403220205540	(966,239)
125	125	qgfbwo	nvxgpcmwv	183188565371	(214,356)
126	126	xrlpi	egjkdgp	205383098891	(716,230)
127	127	tmxbefmjdy	pahyhzjm	411597815090	(731,369)
128	128	bhkrircb	hmwwjyk	717144141539	(524,60)
129	129	sllzlojxyu	xftradjzta	816726868938	(865,194)
130	130	sscaghrqrq	rcoorc	514413236170	(515,981)
131	131	qemyavonk	blaezr	749810315055	(682,197)
132	132	hjkjxp	qrmukdwx	121185225293	(217,332)
133	133	tomswg	durswzkjub	331089457105	(207,178)
134	134	dkybpswojd	nohgt	817479613234	(658,905)
135	135	nhczzyqqwm	fhwyyj	694206280978	(284,267)
136	136	ekenzhxb	jrdnouqot	749820954900	(389,457)
137	137	usucabnbw	msozkt	743817992704	(350,21)
138	138	ocnuxe	sdpeso	306980095631	(521,628)
139	139	skjtjrckg	uizyghch	880771544496	(250,321)
140	140	kcdsqen	xspgx	868211356639	(716,104)
141	141	cdhzuldfj	bicmhdqkc	497166244941	(13,280)
142	142	ykifwng	cvyao	599366439452	(559,394)
143	143	oancbxds	gubaazmpv	366349249072	(435,512)
144	144	vibzg	xnjozk	294893951189	(584,696)
145	145	gyhkgsuoa	gqfvaiac	409956419363	(630,470)
146	146	hufzxxxi	ubnocgk	851355779529	(865,709)
147	147	qsjubtug	kasxvfngb	431440446055	(607,932)
148	148	knefwzdps	qblcdmtgv	872754298885	(174,700)
149	149	rmtjm	tjsrsco	749235104528	(683,797)
150	150	ptfbz	ahtvuxo	308855258442	(764,956)
151	151	vwsemgtogu	wxxmbbxqs	558440749047	(341,825)
152	152	etaefu	bpilu	228411952291	(7,816)
153	153	avfepfcyto	qtsbxu	409072472440	(286,789)
154	154	rlkfje	jnnxrefjex	553652065131	(809,625)
155	155	ayhwwcfuku	oevfpmdbo	862148731649	(78,522)
156	156	nzpapsm	xuzkli	279110279324	(171,14)
157	157	apzlp	fvvlf	218201039743	(386,7)
158	158	fdkokuxmur	okmhamhy	619741919232	(751,631)
159	159	urtsfixnu	ronnlts	799773884671	(274,558)
160	160	cjzjx	sykwawaz	526120723845	(440,22)
161	161	vnjqlr	lvnbtvkyc	485311521669	(456,974)
162	162	kkvzsqcka	baiqk	237661179262	(682,712)
163	163	ysqjqr	fcuui	915892447573	(514,540)
164	164	chjdgigg	ndzcoywqw	586875995785	(906,659)
165	165	votaqv	melohw	229775067885	(657,873)
166	166	nqmtqc	etyrkdf	494156189454	(494,551)
167	167	yvudc	gatuagoh	544953057911	(598,613)
168	168	lgbbynp	gjwtxsr	612802792948	(110,554)
169	169	fbsuum	rstzryebq	562099403542	(805,373)
170	170	ebazet	auyiivb	350341256628	(5,545)
171	171	wgcyeleg	mgqjf	861165358780	(313,586)
172	172	haffxw	yqfkebbg	288042493625	(643,718)
173	173	orazqvnw	gqedb	605925212502	(18,113)
174	174	jaytpv	skghbggg	503390329500	(200,86)
175	175	sdwtrc	gulhcp	784323262532	(333,985)
176	176	spdccnnn	snafl	446239568889	(372,349)
177	177	dxvhkkaobb	rqoqztxa	894425918469	(656,594)
178	178	xkyuut	wnkexf	925661845281	(484,661)
179	179	ughkrw	lempey	395256599800	(152,912)
180	180	hrejx	oyxoox	160929086506	(181,860)
181	181	gyxbkv	uhzkeyzve	772792362459	(312,947)
182	182	vstlxnd	aiwfpixuo	975819386326	(204,535)
183	183	flpiempis	qorqq	612386078185	(968,256)
184	184	itrlgfee	lmymv	195453903737	(664,173)
185	185	fdpdnlh	txjsiyvdg	522587721071	(814,353)
186	186	npbvirnvvv	fytgs	904232412979	(487,734)
187	187	gufmloexoq	oxffgih	982238938696	(282,190)
188	188	wiboaedcme	mmtgbz	876604097182	(546,92)
189	189	mrdaqjbtio	fazishj	638284049868	(444,900)
190	190	vzlqcrtw	dqrqrsmb	392405595613	(944,346)
191	191	wyugwz	ftwyfe	667934834024	(646,105)
192	192	zwbytf	ugplb	598736829808	(298,579)
193	193	loydl	fvlchmeqdf	906738087233	(997,613)
194	194	cjejutufmp	tuawa	931284011619	(744,922)
195	195	iqxxsrfznu	fueok	589609985540	(848,789)
196	196	fpmikrsue	ehvvzfdxnq	418640864475	(108,10)
197	197	umfrrmner	izueb	654459306567	(967,866)
198	198	tfndcod	qkrdgc	755463831785	(951,778)
199	199	gbpjttso	abzzwdgzgd	685882605286	(618,531)
200	200	ykpzbqztk	dbbfvz	432513112102	(425,214)
201	201	ergtpnt	cqalilz	419776208565	(399,868)
202	202	tbpmkulji	rqdegqbp	226038593429	(522,921)
203	203	gekupsowp	eqljl	199753749815	(556,920)
204	204	htntac	mugnt	706111295033	(369,36)
205	205	hncckq	drprl	920254487246	(463,737)
206	206	bvefzn	focbin	140552032959	(341,501)
207	207	kytxw	elnpoz	989904891949	(718,879)
208	208	bopwljvz	ykukwgkesq	170211583539	(633,28)
209	209	yrckwbjxz	zhvsnul	995732348469	(996,170)
210	210	pskqhcv	jbopbq	114096558040	(470,849)
211	211	zjonf	ajwgudet	107758149570	(321,807)
212	212	jolkxskjd	jbbbhvxok	631546139106	(321,421)
213	213	gvqgdncez	knintijp	629730419111	(177,391)
214	214	iccyzsdwo	bksuuzsqi	470367269716	(71,856)
215	215	wjogpzejb	hqkhoxnxo	388600421886	(347,326)
216	216	gkdeqoxr	lkhhcccvr	515327087111	(477,911)
217	217	gtfplop	wqavsf	310465984103	(936,802)
218	218	tjwtmuujh	ncfnlmzh	194138060720	(80,417)
219	219	jvgbu	jsiur	527771686548	(768,83)
220	220	acllleirg	ibmtobcno	419070363204	(850,670)
221	221	tusnyk	bxgttdwm	649902859867	(539,126)
222	222	sdwbxtt	wbukdhxhtz	561925328433	(547,730)
223	223	qoxzl	umakmvic	483655385465	(38,863)
224	224	kquldkobv	zwbkxdgp	255097006705	(443,305)
225	225	gkttdmvy	czfrxha	680211090268	(42,368)
226	226	swvmb	shxbiq	680581848417	(152,908)
227	227	yepkzf	xhpggtzef	867224507180	(769,814)
228	228	ymbvepk	jnczcotfje	317015696825	(686,94)
229	229	fybepioy	wjhaccfg	572009146289	(190,537)
230	230	bcamqzeri	duspcjfhl	103095625833	(878,768)
231	231	mhjhu	ftogkkcqgv	622620621547	(590,356)
232	232	cpyqhhwbh	ymkekbnc	857809113392	(634,31)
233	233	luado	bpocpw	307901946255	(404,885)
234	234	ehjjkus	vhvgxt	372353305889	(589,82)
235	235	xkblb	owiewie	511800647495	(763,841)
236	236	fctpgnyjf	aeoxxcvcrl	921722601708	(234,623)
237	237	lxfkevnya	oqjjxxh	289872152467	(491,275)
238	238	rgesavbcc	yaienpnvd	800604685725	(200,500)
239	239	kurkjghxb	navvbexdx	644039223651	(242,572)
240	240	adnnf	hymekb	989329690857	(301,875)
241	241	ctnqvuh	gmlifjxwn	312008353122	(926,282)
242	242	nkrvwuqerl	olbjrtack	814688316516	(283,706)
243	243	zabfonhn	bdzefvl	529084428824	(761,39)
244	244	bwxhiv	ajoxhf	156229372238	(570,188)
245	245	kufit	smbyrbqtz	642222137833	(580,258)
246	246	ostltdhcic	nlvng	488921493691	(953,766)
247	247	wtqrdeiqno	loefvhnmu	279700322334	(444,315)
248	248	kebixvtsvm	szmpb	259523506484	(23,901)
249	249	zuxzrb	rphmkep	775871609777	(960,841)
250	250	tfpgo	owsnu	373259108595	(145,826)
251	251	tmgrcabp	xsaufijlv	230406326693	(201,148)
252	252	oophcmdy	kbbkrqzld	688607062963	(283,269)
253	253	dfofleckv	szdmsbjire	125275122118	(699,223)
254	254	bpdyg	mvpeob	569122962659	(785,420)
255	255	arurkmcdfh	dcbpxadcfk	544823809640	(816,481)
256	256	gbexibi	pyqbzumpb	802119398522	(320,535)
257	257	yaxsboa	jiixnzjxu	265355192397	(936,249)
258	258	gyouf	wyeekqz	109044321177	(939,533)
259	259	avofsfyw	hqxpaexw	100582945840	(566,566)
260	260	mwhlnax	grrxlfv	482220541929	(891,304)
261	261	azrji	wnhuqun	933764453361	(616,705)
262	262	tcyxmrho	cmgeyiovew	334886341528	(397,155)
263	263	oapvbaiu	ylufvlnj	347599389077	(983,18)
264	264	rbnzjxu	gkfgb	113925691973	(233,603)
265	265	ejfbal	nindzmmdgl	952904752530	(711,52)
266	266	ecpmthpri	auyqf	744448704587	(1,247)
267	267	beeafqdnfe	dramixydm	781463861099	(504,255)
268	268	ithhgznlm	brqoqitkp	469442407171	(129,471)
269	269	hlqeroj	hofedk	395885573485	(249,297)
270	270	pavczhmc	bdktonjrz	498213324362	(32,388)
271	271	imjtbpv	kxrgvqxm	270781690269	(471,879)
272	272	mhcpwmapm	qkjfvcruhs	162472902992	(140,46)
273	273	aewdcu	tsoigfwo	386535207732	(784,24)
274	274	pjsrkhn	zuxmipob	512537232865	(389,27)
275	275	hcwspma	pfnlyyrsgn	678718962042	(892,972)
276	276	iwrcfiice	pezeavrgm	373679775257	(8,848)
277	277	bduedgbqu	wavszwa	498631805883	(825,810)
278	278	wnkfpy	vmzljd	271384358573	(776,117)
279	279	ghdrlg	ybjyn	953524106576	(752,42)
280	280	uaegizqk	gidmwyye	935298390791	(208,279)
281	281	ojssg	gvagtke	142559645863	(319,891)
282	282	prhqboidmy	dwgryopug	866632066233	(144,954)
283	283	wnznjt	uoklc	197312634873	(301,94)
284	284	sjdthqged	lhsfayetl	365296674645	(689,220)
285	285	aotepvkvu	vgbmzglsct	479039273431	(148,253)
286	286	vxzeqgh	kokqcxlrlk	184255001020	(848,396)
287	287	lxyenz	mldfynmol	719547442319	(443,137)
288	288	jcsolaca	omvny	399784905402	(564,204)
289	289	evhzrzknw	uefin	187425878516	(968,616)
290	290	sxnycgnyu	ksudofcl	424010933070	(951,73)
291	291	xxnvmlexf	xomiieli	349150237570	(725,548)
292	292	jljnftu	jpahpawvr	300752606905	(956,341)
293	293	uylnrjz	doenoybu	119173711902	(547,755)
294	294	pewdux	wsbyx	232548974965	(584,275)
295	295	qnfegeab	ytuvizbeos	432161179715	(169,856)
296	296	pgzboce	nobjyf	727215525375	(717,961)
297	297	uypysot	kpcurrzllh	604761995631	(504,621)
298	298	rgykni	czyygr	167382114758	(375,295)
299	299	abcqhsue	drqmdwps	362422249473	(536,285)
300	300	wbwbvptx	rexjpu	239505942957	(243,103)
301	301	dhatikn	kidhn	487608257799	(246,485)
302	302	risyd	bibaroasq	836049472868	(723,217)
303	303	tvmbbov	folpx	833218809315	(422,662)
304	304	tnvsz	xtutyd	951270812604	(794,35)
305	305	uzbxf	ifuwoodcbt	672296463621	(729,178)
306	306	wehnareonc	pssyyttlzw	113030457944	(936,632)
307	307	dtxpjyf	vvcppbqrx	112198590069	(844,69)
308	308	tfezfrcmn	knwdrg	880960501545	(992,692)
309	309	jmhlobdwl	cwatwh	882858722567	(518,92)
310	310	ddikl	crwmd	738558861867	(116,464)
311	311	zjxflds	ephqads	709063375110	(666,870)
312	312	yxruosqhmw	lkhzunsnk	865678824637	(833,846)
313	313	nwcygi	soiycp	354679820406	(117,552)
314	314	gygzihtkeq	imyshkkpfo	929410744542	(339,188)
315	315	ffunq	jmbrdsu	397300641635	(477,323)
316	316	ngfnphkv	anfkoxpe	233248574995	(834,957)
317	317	jrcpub	ivyuaw	715126762530	(947,618)
318	318	vfaiflj	xrqpo	974271412009	(967,425)
319	319	tsyklxl	pnrimstkpn	285729227874	(678,178)
320	320	sxszty	pvmmm	815289114352	(452,798)
321	321	xnzjrfqo	xbijltyca	454400300164	(362,862)
322	322	dwvnoquur	gkaznmzpv	720786116155	(193,474)
323	323	ludhf	kdetrfvj	621646127912	(272,929)
324	324	icaaywz	mwcutspe	897142608445	(375,253)
325	325	ndwsddgipn	stlboovgjl	503250176438	(300,378)
326	326	bzzleajd	sjkkoxpjug	217650065703	(510,796)
327	327	trqat	qhzjmyebz	730245036303	(363,870)
328	328	mjekctkme	unkztkwttk	992806469686	(482,719)
329	329	uxknwwmye	soodqiwswp	118250575919	(277,718)
330	330	evatj	xrguujbnu	748253820618	(863,480)
331	331	gmujrtmfj	oovad	406188332143	(505,723)
332	332	klhmhkktob	adoxggkpi	250546798025	(587,997)
333	333	lpepf	hscboqgsbk	851339270714	(643,510)
334	334	wfjzt	ljlcpxtppi	279520044272	(652,897)
335	335	vrbmo	edodxcvop	513190588933	(474,115)
336	336	gjyjhub	pbhwjsvqk	745222273174	(523,975)
337	337	einlhu	rqwqovsoaa	102573312322	(797,927)
338	338	pncxz	spdglzdii	965400003062	(938,754)
339	339	cwkkjlmenu	mhvvxifknf	664808192708	(264,486)
340	340	vwnoydefvh	wjcdsbd	459500990335	(106,29)
341	341	barhbg	csfhhk	404375046875	(184,209)
342	342	qpjkwu	peqomwv	460975182843	(615,587)
343	343	xvrpofchnw	cvcia	595334781315	(241,104)
344	344	kdncemhya	flxzpejmqn	305654686458	(666,957)
345	345	zyookiqipx	uplxqqdbk	316294210925	(187,48)
346	346	mmlvbhdz	aphffwmfg	696622724566	(743,63)
347	347	zegmdx	hpwiopqyun	144237002860	(234,46)
348	348	fnlbd	ovhoshvmem	609477487294	(679,752)
349	349	fedbuvnwh	cdnpctt	451215694683	(996,716)
350	350	bqdpbih	apzbdov	203384505966	(409,34)
351	351	lztnh	vkyfnwk	329951228695	(210,339)
352	352	vezpyluc	bbwrknjdjw	801833708925	(213,676)
353	353	kgzjslwpts	jiukbk	496256816823	(478,861)
354	354	dpnovdjimt	dkolt	539302302013	(202,297)
355	355	hhogruhb	qopioup	310925101997	(551,550)
356	356	tfrfydncf	eorck	681494865862	(694,218)
357	357	xljyxwqk	kmllin	942579160955	(44,665)
358	358	xxrfeokd	qwtyyikvmu	737699363483	(390,816)
359	359	taenawz	jtzgj	419662466609	(765,57)
360	360	uvjqrdmuk	jvgjz	520772034582	(165,713)
361	361	vzjnegnzf	xltsxqntl	644244934190	(453,445)
362	362	hvfbajeeow	alujh	797315465164	(139,400)
363	363	qqdzznnnsi	wswuglcu	479706550431	(402,289)
364	364	xhymjr	fumiz	264850855158	(528,889)
365	365	goxnc	wupjen	390699571746	(172,148)
366	366	lhhiyxmuh	nxdtjusnq	310743979698	(184,223)
367	367	fjkprlobbm	iasipzsk	284795135118	(303,948)
368	368	vxtrelwr	qpcyiqjv	759032076438	(572,703)
369	369	pgmkwm	hfjhfilb	431251261304	(410,36)
370	370	rslid	zdghzbugqq	552703314632	(261,799)
371	371	eiptlqch	glbhnueaui	155301437536	(777,182)
372	372	tvisvxdqz	ldfmh	585980819499	(125,600)
373	373	wzckjdq	wciop	350090848546	(996,584)
374	374	hshzcsaiax	fezaquqpyi	202762396874	(816,379)
375	375	uognbmjr	biaduqed	395540421521	(798,320)
376	376	huspxmxoit	bzvteyop	819446360172	(329,294)
377	377	pknsnfdjsc	rxkrwtptlv	224621665396	(861,555)
378	378	fczcmo	drotqud	773650934989	(284,588)
379	379	pfvpo	cabvgbymkj	217879906991	(971,133)
380	380	dhwdywabpa	ugqizkf	525892180384	(252,54)
381	381	amdbl	lailnksizs	720404002795	(986,577)
382	382	iuzufh	dsjksboe	747588543134	(920,828)
383	383	xgbjszd	zyzbluqw	376065579733	(955,80)
384	384	qozotf	dxzkl	655736829119	(178,815)
385	385	pjaubz	lrtshw	847471772877	(71,68)
386	386	ajaoikv	zpwtxoksax	852438575743	(23,133)
387	387	fmbodb	eiamffa	498813041579	(571,299)
388	388	xjygpkosdp	dixcoflhi	278845058510	(550,846)
389	389	qzlvljdu	yzyjvjg	455543911601	(70,554)
390	390	dhhipdwr	boigm	402260993937	(393,628)
391	391	glddsunzu	ubkcfuu	344625952759	(790,631)
392	392	lfnbyodr	fajgfht	812313329212	(99,396)
393	393	zjikna	yvhjlxluz	162574244247	(613,686)
394	394	xrscj	zlycjsez	404472878642	(840,294)
395	395	prhzhlca	wxwrxw	714823260146	(133,484)
396	396	vkxxf	xzrewnhzxk	328582287031	(840,862)
397	397	ecopvzoagv	fsdyktxmqc	144126168351	(127,111)
398	398	lrlsetkghn	qhmqxy	780709249650	(135,443)
399	399	fwdvojg	mwxksfquij	165848290999	(626,754)
400	400	ornlu	dzpyka	449022581451	(951,682)
401	401	ahjgbso	frrcji	790442886806	(665,405)
402	402	amwqaxyx	brjanxwce	651628746684	(369,519)
403	403	csfmtoqis	tfmtjdueo	766141023565	(943,952)
404	404	uhxowk	mnusmhnz	174260365556	(998,671)
405	405	smeym	tukhsickxy	314730202936	(802,848)
406	406	ahiqpx	lyatxkbdpv	767803144289	(325,158)
407	407	kmehiw	ukuzq	143299483913	(309,980)
408	408	tmpsufd	ldldcpoy	482928517437	(967,266)
409	409	ixbkka	aptcsr	706917865635	(287,440)
410	410	giuiispalc	rwkaxkinm	464921240198	(57,719)
411	411	fgpolmwula	sxvswqxoj	849738087329	(185,516)
412	412	yemzkknt	tbpfi	139499888864	(495,682)
413	413	shmiwd	cbmchrt	444809342376	(258,986)
414	414	bjwpsdv	canwoqqj	503207236513	(561,941)
415	415	iaqinzhgo	avaozaitne	542895223704	(202,500)
416	416	ehrjgcjv	nekuzk	653797983617	(318,675)
417	417	ntdfi	crxef	624398709258	(789,796)
418	418	xzbutsmr	llyfrc	955223687027	(372,418)
419	419	rkzwipuy	ijydtulyq	688284826939	(755,315)
420	420	liabquwsc	livfomcgjv	783516867811	(213,258)
421	421	txbcvfd	dokylgks	685132263382	(302,307)
422	422	bizaja	cijbo	862279414181	(236,39)
423	423	uykbyzcfwv	ibaffesna	989062212101	(910,400)
424	424	srzywfvikm	tdjhippf	107999336645	(766,172)
425	425	gufidrwyu	lfllwanav	302382440653	(86,974)
426	426	lbnwmrxd	xhcjmms	308764579276	(972,331)
427	427	bdtvrmo	rjlgibg	923656198956	(900,793)
428	428	uxyqfw	jnhaofhvw	745396144866	(124,446)
429	429	epuqkfgzt	glzmizumwf	327034854150	(384,884)
430	430	yqdymlca	lflux	451142713827	(966,225)
431	431	trnoumm	blbmchjf	843445592592	(658,308)
432	432	zunwhkzwxs	ruumh	207591497509	(596,366)
433	433	eidvay	tjxwuhuk	320545337511	(702,831)
434	434	vxyffkrs	edfktlb	322606453694	(470,285)
435	435	yfdkqvixp	sdbrlpull	611336929003	(278,790)
436	436	umwep	erwsfdzje	676376533217	(767,34)
437	437	fxgthfvls	jeutomvv	597100561144	(172,327)
438	438	fmvglpqvzi	tgaqktx	634651113342	(110,843)
439	439	tqiedruno	ksovhwso	365774533070	(879,834)
440	440	kgkkhjaqcd	frnealpt	324246658645	(725,280)
441	441	dzjukczhv	mahxs	504772492219	(888,581)
442	442	sglmbgbtu	mfyfhhfhf	357037772094	(663,390)
443	443	krdhvup	dhcjlcdigb	162562009302	(679,451)
444	444	stswlbkhsq	qcpvfdt	390104631718	(456,839)
445	445	ydddeuhlsa	fopktlfv	256897391149	(275,591)
446	446	insuf	stnqfj	646707188362	(797,804)
447	447	kcaqcbq	xswth	269547321205	(387,584)
448	448	jsygzhgpx	lrpkmll	810477188996	(350,218)
449	449	uwwtoolu	dsyofjei	870472949076	(193,885)
450	450	ygbxemwbo	pfttxxex	417501915988	(711,340)
451	451	ytqolfmrl	kdpszpgkhg	108411417340	(481,961)
452	452	ofvhc	apjumaox	799015612109	(930,141)
453	453	ycpogg	clwhrjbgi	446745167600	(387,25)
454	454	bffch	mrmgepgryo	588923077062	(728,509)
455	455	atohpmk	gltgka	938348696184	(164,912)
456	456	arabvqtm	yxvaiqr	393480279229	(516,738)
457	457	qafdgui	shpbnug	635776900926	(634,850)
458	458	qdufeko	qbvjdqehv	566832920677	(211,483)
459	459	bawufkltzx	yxrxriz	328658466267	(132,667)
460	460	hyvmasa	drihgv	639248560662	(279,15)
461	461	fyjhnrncqx	kjaksps	955342092110	(380,308)
462	462	wlijpxsj	vheozhn	375349139165	(287,620)
463	463	hyayzya	vchqbce	232456493837	(163,899)
464	464	rgxcuiwk	jamksix	573109537320	(7,477)
465	465	luydueoy	nvshk	696662115339	(264,382)
466	466	aptntibwv	kzfadte	673905500782	(518,962)
467	467	jizint	fxunj	879727833334	(327,970)
468	468	rmrpyyyeva	ogjjemyhz	530934508034	(813,370)
469	469	xnjhqas	iyxrfbwpk	746757318984	(778,175)
470	470	pjothai	iwvvluyvj	551986362648	(566,498)
471	471	phtzp	erksdz	247377555711	(799,109)
472	472	sngwg	ilqcth	933426288576	(897,451)
473	473	srqcvxogta	svofjk	712462342159	(642,789)
474	474	zhvms	cawsdivxxf	113675727272	(416,84)
475	475	rxnhhdmp	owgdi	602377397019	(99,31)
476	476	amcrjpsats	fgasznkm	544577207518	(295,265)
477	477	pkdatkti	oexmyhmanq	734030254883	(159,332)
478	478	yliqe	fpdnwv	873202916307	(719,230)
479	479	wzxysvhhz	buckndoi	159495868982	(151,821)
480	480	zyjkpioxbv	lazznth	623465030625	(729,523)
481	481	tynsjtcwuc	dbicbtuar	382657985060	(169,692)
482	482	jsyqcnn	xustukz	230262380870	(454,455)
483	483	oeyeah	keimevdz	854453227405	(543,238)
484	484	ofivrnp	mjynzt	307421778719	(11,195)
485	485	flfdrr	rrwuz	558198719118	(505,228)
486	486	xwirizvyoe	iugfntkxhx	193337270964	(25,601)
487	487	svofclocxm	wtqhi	620367137161	(531,64)
488	488	ouupld	lzovujz	698550331634	(240,340)
489	489	ffecdvkk	jlcuxubah	211618631506	(540,379)
490	490	nunkvxlvx	jwjxqc	289924523100	(777,853)
491	491	gqglrmr	rxpcpbqanp	842966682261	(425,113)
492	492	jzbmwils	pyhklkj	484301236262	(657,795)
493	493	voerafanu	zwtfr	736832876828	(949,821)
494	494	dzjmiao	xohfnr	741920115056	(48,617)
495	495	xnxusowuy	zwihrpbnsv	520526790843	(842,372)
496	496	wzcswkg	liicwldmma	750410778536	(844,821)
497	497	dnwgc	rcetmi	936012320180	(204,284)
498	498	dthpn	rpkqgqwcxi	750279406632	(757,29)
499	499	jeeqvvc	azplzgk	932585413746	(923,470)
500	500	klcqd	cwanwhukaz	991655611008	(752,540)
\.


--
-- TOC entry 4973 (class 0 OID 17123)
-- Dependencies: 219
-- Data for Name: house_bill; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.house_bill (bill_id, to_account, issue_date, price, start_date, finish_date) FROM stdin;
1	1	2020-01-15	7	2020-01-01	2020-01-08
2	2	2020-01-15	14	2020-01-01	2020-01-08
3	3	2020-01-15	14	2020-01-01	2020-01-08
4	4	2020-01-15	7	2020-01-01	2020-01-08
5	5	2020-01-15	14	2020-01-01	2020-01-08
6	6	2020-01-15	7	2020-01-01	2020-01-08
7	7	2020-01-15	14	2020-01-01	2020-01-08
8	8	2020-01-15	21	2020-01-01	2020-01-08
9	9	2020-01-15	7	2020-01-01	2020-01-08
10	10	2020-01-15	14	2020-01-01	2020-01-08
11	11	2020-01-15	21	2020-01-01	2020-01-08
12	12	2020-01-15	21	2020-01-01	2020-01-08
13	13	2020-01-15	21	2020-01-01	2020-01-08
14	14	2020-01-15	14	2020-01-01	2020-01-08
15	15	2020-01-15	14	2020-01-01	2020-01-08
16	16	2020-01-15	7	2020-01-01	2020-01-08
17	17	2020-01-15	21	2020-01-01	2020-01-08
18	18	2020-01-15	14	2020-01-01	2020-01-08
19	19	2020-01-15	14	2020-01-01	2020-01-08
20	20	2020-01-15	7	2020-01-01	2020-01-08
21	21	2020-01-15	21	2020-01-01	2020-01-08
22	22	2020-01-15	14	2020-01-01	2020-01-08
23	23	2020-01-15	14	2020-01-01	2020-01-08
24	24	2020-01-15	7	2020-01-01	2020-01-08
25	25	2020-01-15	21	2020-01-01	2020-01-08
26	26	2020-01-15	14	2020-01-01	2020-01-08
27	27	2020-01-15	7	2020-01-01	2020-01-08
28	28	2020-01-15	14	2020-01-01	2020-01-08
29	29	2020-01-15	7	2020-01-01	2020-01-08
30	30	2020-01-15	21	2020-01-01	2020-01-08
31	31	2020-01-15	14	2020-01-01	2020-01-08
32	32	2020-01-15	7	2020-01-01	2020-01-08
33	33	2020-01-15	14	2020-01-01	2020-01-08
34	34	2020-01-15	7	2020-01-01	2020-01-08
35	35	2020-01-15	7	2020-01-01	2020-01-08
36	36	2020-01-15	14	2020-01-01	2020-01-08
37	37	2020-01-15	21	2020-01-01	2020-01-08
38	38	2020-01-15	21	2020-01-01	2020-01-08
39	39	2020-01-15	21	2020-01-01	2020-01-08
40	40	2020-01-15	21	2020-01-01	2020-01-08
41	41	2020-01-15	21	2020-01-01	2020-01-08
42	42	2020-01-15	14	2020-01-01	2020-01-08
43	43	2020-01-15	21	2020-01-01	2020-01-08
44	44	2020-01-15	7	2020-01-01	2020-01-08
45	45	2020-01-15	7	2020-01-01	2020-01-08
46	46	2020-01-15	14	2020-01-01	2020-01-08
47	47	2020-01-15	14	2020-01-01	2020-01-08
48	48	2020-01-15	21	2020-01-01	2020-01-08
49	49	2020-01-15	7	2020-01-01	2020-01-08
50	50	2020-01-15	21	2020-01-01	2020-01-08
51	51	2020-01-15	21	2020-01-01	2020-01-08
52	52	2020-01-15	7	2020-01-01	2020-01-08
53	53	2020-01-15	7	2020-01-01	2020-01-08
54	54	2020-01-15	21	2020-01-01	2020-01-08
55	55	2020-01-15	7	2020-01-01	2020-01-08
56	56	2020-01-15	21	2020-01-01	2020-01-08
57	57	2020-01-15	7	2020-01-01	2020-01-08
58	58	2020-01-15	7	2020-01-01	2020-01-08
59	59	2020-01-15	21	2020-01-01	2020-01-08
60	60	2020-01-15	14	2020-01-01	2020-01-08
61	61	2020-01-15	7	2020-01-01	2020-01-08
62	62	2020-01-15	14	2020-01-01	2020-01-08
63	63	2020-01-15	14	2020-01-01	2020-01-08
64	64	2020-01-15	21	2020-01-01	2020-01-08
65	65	2020-01-15	7	2020-01-01	2020-01-08
66	66	2020-01-15	14	2020-01-01	2020-01-08
67	67	2020-01-15	7	2020-01-01	2020-01-08
68	68	2020-01-15	7	2020-01-01	2020-01-08
69	69	2020-01-15	7	2020-01-01	2020-01-08
70	70	2020-01-15	14	2020-01-01	2020-01-08
71	71	2020-01-15	7	2020-01-01	2020-01-08
72	72	2020-01-15	7	2020-01-01	2020-01-08
73	73	2020-01-15	14	2020-01-01	2020-01-08
74	74	2020-01-15	21	2020-01-01	2020-01-08
75	75	2020-01-15	14	2020-01-01	2020-01-08
76	76	2020-01-15	21	2020-01-01	2020-01-08
77	77	2020-01-15	21	2020-01-01	2020-01-08
78	78	2020-01-15	21	2020-01-01	2020-01-08
79	79	2020-01-15	21	2020-01-01	2020-01-08
80	80	2020-01-15	7	2020-01-01	2020-01-08
81	81	2020-01-15	14	2020-01-01	2020-01-08
82	82	2020-01-15	14	2020-01-01	2020-01-08
83	83	2020-01-15	21	2020-01-01	2020-01-08
84	84	2020-01-15	7	2020-01-01	2020-01-08
85	85	2020-01-15	14	2020-01-01	2020-01-08
86	86	2020-01-15	7	2020-01-01	2020-01-08
87	87	2020-01-15	7	2020-01-01	2020-01-08
88	88	2020-01-15	14	2020-01-01	2020-01-08
89	89	2020-01-15	21	2020-01-01	2020-01-08
90	90	2020-01-15	21	2020-01-01	2020-01-08
91	91	2020-01-15	7	2020-01-01	2020-01-08
92	92	2020-01-15	14	2020-01-01	2020-01-08
93	93	2020-01-15	14	2020-01-01	2020-01-08
94	94	2020-01-15	7	2020-01-01	2020-01-08
95	95	2020-01-15	7	2020-01-01	2020-01-08
96	96	2020-01-15	21	2020-01-01	2020-01-08
97	97	2020-01-15	14	2020-01-01	2020-01-08
98	98	2020-01-15	14	2020-01-01	2020-01-08
99	99	2020-01-15	21	2020-01-01	2020-01-08
100	100	2020-01-15	7	2020-01-01	2020-01-08
101	1	2020-01-23	7	2020-01-08	2020-01-15
102	2	2020-01-23	14	2020-01-08	2020-01-15
103	3	2020-01-23	14	2020-01-08	2020-01-15
104	4	2020-01-23	7	2020-01-08	2020-01-15
105	5	2020-01-23	14	2020-01-08	2020-01-15
106	6	2020-01-23	7	2020-01-08	2020-01-15
107	7	2020-01-23	14	2020-01-08	2020-01-15
108	8	2020-01-23	21	2020-01-08	2020-01-15
109	9	2020-01-23	7	2020-01-08	2020-01-15
110	10	2020-01-23	14	2020-01-08	2020-01-15
111	11	2020-01-23	21	2020-01-08	2020-01-15
112	12	2020-01-23	21	2020-01-08	2020-01-15
113	13	2020-01-23	21	2020-01-08	2020-01-15
114	14	2020-01-23	14	2020-01-08	2020-01-15
115	15	2020-01-23	14	2020-01-08	2020-01-15
116	16	2020-01-23	7	2020-01-08	2020-01-15
117	17	2020-01-23	21	2020-01-08	2020-01-15
118	18	2020-01-23	14	2020-01-08	2020-01-15
119	19	2020-01-23	14	2020-01-08	2020-01-15
120	20	2020-01-23	7	2020-01-08	2020-01-15
121	21	2020-01-23	21	2020-01-08	2020-01-15
122	22	2020-01-23	14	2020-01-08	2020-01-15
123	23	2020-01-23	14	2020-01-08	2020-01-15
124	24	2020-01-23	7	2020-01-08	2020-01-15
125	25	2020-01-23	21	2020-01-08	2020-01-15
126	26	2020-01-23	14	2020-01-08	2020-01-15
127	27	2020-01-23	7	2020-01-08	2020-01-15
128	28	2020-01-23	14	2020-01-08	2020-01-15
129	29	2020-01-23	7	2020-01-08	2020-01-15
130	30	2020-01-23	21	2020-01-08	2020-01-15
131	31	2020-01-23	14	2020-01-08	2020-01-15
132	32	2020-01-23	7	2020-01-08	2020-01-15
133	33	2020-01-23	14	2020-01-08	2020-01-15
134	34	2020-01-23	7	2020-01-08	2020-01-15
135	35	2020-01-23	7	2020-01-08	2020-01-15
136	36	2020-01-23	14	2020-01-08	2020-01-15
137	37	2020-01-23	21	2020-01-08	2020-01-15
138	38	2020-01-23	21	2020-01-08	2020-01-15
139	39	2020-01-23	21	2020-01-08	2020-01-15
140	40	2020-01-23	21	2020-01-08	2020-01-15
141	41	2020-01-23	21	2020-01-08	2020-01-15
142	42	2020-01-23	14	2020-01-08	2020-01-15
143	43	2020-01-23	21	2020-01-08	2020-01-15
144	44	2020-01-23	7	2020-01-08	2020-01-15
145	45	2020-01-23	7	2020-01-08	2020-01-15
146	46	2020-01-23	14	2020-01-08	2020-01-15
147	47	2020-01-23	14	2020-01-08	2020-01-15
148	48	2020-01-23	21	2020-01-08	2020-01-15
149	49	2020-01-23	7	2020-01-08	2020-01-15
150	50	2020-01-23	21	2020-01-08	2020-01-15
151	51	2020-01-23	21	2020-01-08	2020-01-15
152	52	2020-01-23	7	2020-01-08	2020-01-15
153	53	2020-01-23	7	2020-01-08	2020-01-15
154	54	2020-01-23	21	2020-01-08	2020-01-15
155	55	2020-01-23	7	2020-01-08	2020-01-15
156	56	2020-01-23	21	2020-01-08	2020-01-15
157	57	2020-01-23	7	2020-01-08	2020-01-15
158	58	2020-01-23	7	2020-01-08	2020-01-15
159	59	2020-01-23	21	2020-01-08	2020-01-15
160	60	2020-01-23	14	2020-01-08	2020-01-15
161	61	2020-01-23	7	2020-01-08	2020-01-15
162	62	2020-01-23	14	2020-01-08	2020-01-15
163	63	2020-01-23	14	2020-01-08	2020-01-15
164	64	2020-01-23	21	2020-01-08	2020-01-15
165	65	2020-01-23	7	2020-01-08	2020-01-15
166	66	2020-01-23	14	2020-01-08	2020-01-15
167	67	2020-01-23	7	2020-01-08	2020-01-15
168	68	2020-01-23	7	2020-01-08	2020-01-15
169	69	2020-01-23	7	2020-01-08	2020-01-15
170	70	2020-01-23	14	2020-01-08	2020-01-15
171	71	2020-01-23	7	2020-01-08	2020-01-15
172	72	2020-01-23	7	2020-01-08	2020-01-15
173	73	2020-01-23	14	2020-01-08	2020-01-15
174	74	2020-01-23	21	2020-01-08	2020-01-15
175	75	2020-01-23	14	2020-01-08	2020-01-15
176	76	2020-01-23	21	2020-01-08	2020-01-15
177	77	2020-01-23	21	2020-01-08	2020-01-15
178	78	2020-01-23	21	2020-01-08	2020-01-15
179	79	2020-01-23	21	2020-01-08	2020-01-15
180	80	2020-01-23	7	2020-01-08	2020-01-15
181	81	2020-01-23	14	2020-01-08	2020-01-15
182	82	2020-01-23	14	2020-01-08	2020-01-15
183	83	2020-01-23	21	2020-01-08	2020-01-15
184	84	2020-01-23	7	2020-01-08	2020-01-15
185	85	2020-01-23	14	2020-01-08	2020-01-15
186	86	2020-01-23	7	2020-01-08	2020-01-15
187	87	2020-01-23	7	2020-01-08	2020-01-15
188	88	2020-01-23	14	2020-01-08	2020-01-15
189	89	2020-01-23	21	2020-01-08	2020-01-15
190	90	2020-01-23	21	2020-01-08	2020-01-15
191	91	2020-01-23	7	2020-01-08	2020-01-15
192	92	2020-01-23	14	2020-01-08	2020-01-15
193	93	2020-01-23	14	2020-01-08	2020-01-15
194	94	2020-01-23	7	2020-01-08	2020-01-15
195	95	2020-01-23	7	2020-01-08	2020-01-15
196	96	2020-01-23	21	2020-01-08	2020-01-15
197	97	2020-01-23	14	2020-01-08	2020-01-15
198	98	2020-01-23	14	2020-01-08	2020-01-15
199	99	2020-01-23	21	2020-01-08	2020-01-15
200	100	2020-01-23	7	2020-01-08	2020-01-15
201	201	2023-12-15	21	2023-12-01	2023-12-08
202	202	2023-12-15	7	2023-12-01	2023-12-08
203	203	2023-12-15	21	2023-12-01	2023-12-08
204	204	2023-12-15	14	2023-12-01	2023-12-08
205	205	2023-12-15	21	2023-12-01	2023-12-08
206	206	2023-12-15	7	2023-12-01	2023-12-08
207	207	2023-12-15	21	2023-12-01	2023-12-08
208	208	2023-12-15	14	2023-12-01	2023-12-08
209	209	2023-12-15	14	2023-12-01	2023-12-08
210	210	2023-12-15	14	2023-12-01	2023-12-08
211	211	2023-12-15	21	2023-12-01	2023-12-08
212	212	2023-12-15	14	2023-12-01	2023-12-08
213	213	2023-12-15	7	2023-12-01	2023-12-08
214	214	2023-12-15	14	2023-12-01	2023-12-08
215	215	2023-12-15	21	2023-12-01	2023-12-08
216	216	2023-12-15	21	2023-12-01	2023-12-08
217	217	2023-12-15	21	2023-12-01	2023-12-08
218	218	2023-12-15	14	2023-12-01	2023-12-08
219	219	2023-12-15	7	2023-12-01	2023-12-08
220	220	2023-12-15	7	2023-12-01	2023-12-08
221	221	2023-12-15	7	2023-12-01	2023-12-08
222	222	2023-12-15	21	2023-12-01	2023-12-08
223	223	2023-12-15	21	2023-12-01	2023-12-08
224	224	2023-12-15	21	2023-12-01	2023-12-08
225	225	2023-12-15	21	2023-12-01	2023-12-08
226	226	2023-12-15	14	2023-12-01	2023-12-08
227	227	2023-12-15	7	2023-12-01	2023-12-08
228	228	2023-12-15	21	2023-12-01	2023-12-08
229	229	2023-12-15	7	2023-12-01	2023-12-08
230	230	2023-12-15	7	2023-12-01	2023-12-08
231	231	2023-12-15	21	2023-12-01	2023-12-08
232	232	2023-12-15	7	2023-12-01	2023-12-08
233	233	2023-12-15	7	2023-12-01	2023-12-08
234	234	2023-12-15	21	2023-12-01	2023-12-08
235	235	2023-12-15	21	2023-12-01	2023-12-08
236	236	2023-12-15	14	2023-12-01	2023-12-08
237	237	2023-12-15	7	2023-12-01	2023-12-08
238	238	2023-12-15	7	2023-12-01	2023-12-08
239	239	2023-12-15	21	2023-12-01	2023-12-08
240	240	2023-12-15	14	2023-12-01	2023-12-08
241	241	2023-12-15	14	2023-12-01	2023-12-08
242	242	2023-12-15	21	2023-12-01	2023-12-08
243	243	2023-12-15	21	2023-12-01	2023-12-08
244	244	2023-12-15	14	2023-12-01	2023-12-08
245	245	2023-12-15	21	2023-12-01	2023-12-08
246	246	2023-12-15	7	2023-12-01	2023-12-08
247	247	2023-12-15	7	2023-12-01	2023-12-08
248	248	2023-12-15	7	2023-12-01	2023-12-08
249	249	2023-12-15	14	2023-12-01	2023-12-08
250	250	2023-12-15	14	2023-12-01	2023-12-08
251	251	2023-12-15	21	2023-12-01	2023-12-08
252	252	2023-12-15	14	2023-12-01	2023-12-08
253	253	2023-12-15	7	2023-12-01	2023-12-08
254	254	2023-12-15	14	2023-12-01	2023-12-08
255	255	2023-12-15	7	2023-12-01	2023-12-08
256	256	2023-12-15	21	2023-12-01	2023-12-08
257	257	2023-12-15	14	2023-12-01	2023-12-08
258	258	2023-12-15	7	2023-12-01	2023-12-08
259	259	2023-12-15	21	2023-12-01	2023-12-08
260	260	2023-12-15	21	2023-12-01	2023-12-08
261	261	2023-12-15	21	2023-12-01	2023-12-08
262	262	2023-12-15	7	2023-12-01	2023-12-08
263	263	2023-12-15	14	2023-12-01	2023-12-08
264	264	2023-12-15	7	2023-12-01	2023-12-08
265	265	2023-12-15	14	2023-12-01	2023-12-08
266	266	2023-12-15	21	2023-12-01	2023-12-08
267	267	2023-12-15	7	2023-12-01	2023-12-08
268	268	2023-12-15	14	2023-12-01	2023-12-08
269	269	2023-12-15	21	2023-12-01	2023-12-08
270	270	2023-12-15	21	2023-12-01	2023-12-08
271	271	2023-12-15	7	2023-12-01	2023-12-08
272	272	2023-12-15	7	2023-12-01	2023-12-08
273	273	2023-12-15	7	2023-12-01	2023-12-08
274	274	2023-12-15	21	2023-12-01	2023-12-08
275	275	2023-12-15	7	2023-12-01	2023-12-08
276	276	2023-12-15	21	2023-12-01	2023-12-08
277	277	2023-12-15	21	2023-12-01	2023-12-08
278	278	2023-12-15	14	2023-12-01	2023-12-08
279	279	2023-12-15	14	2023-12-01	2023-12-08
280	280	2023-12-15	7	2023-12-01	2023-12-08
281	281	2023-12-15	21	2023-12-01	2023-12-08
282	282	2023-12-15	7	2023-12-01	2023-12-08
283	283	2023-12-15	14	2023-12-01	2023-12-08
284	284	2023-12-15	7	2023-12-01	2023-12-08
285	285	2023-12-15	14	2023-12-01	2023-12-08
286	286	2023-12-15	14	2023-12-01	2023-12-08
287	287	2023-12-15	7	2023-12-01	2023-12-08
288	288	2023-12-15	7	2023-12-01	2023-12-08
289	289	2023-12-15	7	2023-12-01	2023-12-08
290	290	2023-12-15	21	2023-12-01	2023-12-08
291	291	2023-12-15	21	2023-12-01	2023-12-08
292	292	2023-12-15	21	2023-12-01	2023-12-08
293	293	2023-12-15	7	2023-12-01	2023-12-08
294	294	2023-12-15	14	2023-12-01	2023-12-08
295	295	2023-12-15	21	2023-12-01	2023-12-08
296	296	2023-12-15	14	2023-12-01	2023-12-08
297	297	2023-12-15	14	2023-12-01	2023-12-08
298	298	2023-12-15	14	2023-12-01	2023-12-08
299	299	2023-12-15	14	2023-12-01	2023-12-08
300	300	2023-12-15	7	2023-12-01	2023-12-08
301	201	2020-01-16	21	2020-01-08	2020-01-15
302	202	2020-01-16	7	2020-01-08	2020-01-15
303	203	2020-01-16	21	2020-01-08	2020-01-15
304	204	2020-01-16	14	2020-01-08	2020-01-15
305	205	2020-01-16	21	2020-01-08	2020-01-15
306	206	2020-01-16	7	2020-01-08	2020-01-15
307	207	2020-01-16	21	2020-01-08	2020-01-15
308	208	2020-01-16	14	2020-01-08	2020-01-15
309	209	2020-01-16	14	2020-01-08	2020-01-15
310	210	2020-01-16	14	2020-01-08	2020-01-15
311	211	2020-01-16	21	2020-01-08	2020-01-15
312	212	2020-01-16	14	2020-01-08	2020-01-15
313	213	2020-01-16	7	2020-01-08	2020-01-15
314	214	2020-01-16	14	2020-01-08	2020-01-15
315	215	2020-01-16	21	2020-01-08	2020-01-15
316	216	2020-01-16	21	2020-01-08	2020-01-15
317	217	2020-01-16	21	2020-01-08	2020-01-15
318	218	2020-01-16	14	2020-01-08	2020-01-15
319	219	2020-01-16	7	2020-01-08	2020-01-15
320	220	2020-01-16	7	2020-01-08	2020-01-15
321	221	2020-01-16	7	2020-01-08	2020-01-15
322	222	2020-01-16	21	2020-01-08	2020-01-15
323	223	2020-01-16	21	2020-01-08	2020-01-15
324	224	2020-01-16	21	2020-01-08	2020-01-15
325	225	2020-01-16	21	2020-01-08	2020-01-15
326	226	2020-01-16	14	2020-01-08	2020-01-15
327	227	2020-01-16	7	2020-01-08	2020-01-15
328	228	2020-01-16	21	2020-01-08	2020-01-15
329	229	2020-01-16	7	2020-01-08	2020-01-15
330	230	2020-01-16	7	2020-01-08	2020-01-15
331	231	2020-01-16	21	2020-01-08	2020-01-15
332	232	2020-01-16	7	2020-01-08	2020-01-15
333	233	2020-01-16	7	2020-01-08	2020-01-15
334	234	2020-01-16	21	2020-01-08	2020-01-15
335	235	2020-01-16	21	2020-01-08	2020-01-15
336	236	2020-01-16	14	2020-01-08	2020-01-15
337	237	2020-01-16	7	2020-01-08	2020-01-15
338	238	2020-01-16	7	2020-01-08	2020-01-15
339	239	2020-01-16	21	2020-01-08	2020-01-15
340	240	2020-01-16	14	2020-01-08	2020-01-15
341	241	2020-01-16	14	2020-01-08	2020-01-15
342	242	2020-01-16	21	2020-01-08	2020-01-15
343	243	2020-01-16	21	2020-01-08	2020-01-15
344	244	2020-01-16	14	2020-01-08	2020-01-15
345	245	2020-01-16	21	2020-01-08	2020-01-15
346	246	2020-01-16	7	2020-01-08	2020-01-15
347	247	2020-01-16	7	2020-01-08	2020-01-15
348	248	2020-01-16	7	2020-01-08	2020-01-15
349	249	2020-01-16	14	2020-01-08	2020-01-15
350	250	2020-01-16	14	2020-01-08	2020-01-15
351	251	2020-01-16	21	2020-01-08	2020-01-15
352	252	2020-01-16	14	2020-01-08	2020-01-15
353	253	2020-01-16	7	2020-01-08	2020-01-15
354	254	2020-01-16	14	2020-01-08	2020-01-15
355	255	2020-01-16	7	2020-01-08	2020-01-15
356	256	2020-01-16	21	2020-01-08	2020-01-15
357	257	2020-01-16	14	2020-01-08	2020-01-15
358	258	2020-01-16	7	2020-01-08	2020-01-15
359	259	2020-01-16	21	2020-01-08	2020-01-15
360	260	2020-01-16	21	2020-01-08	2020-01-15
361	261	2020-01-16	21	2020-01-08	2020-01-15
362	262	2020-01-16	7	2020-01-08	2020-01-15
363	263	2020-01-16	14	2020-01-08	2020-01-15
364	264	2020-01-16	7	2020-01-08	2020-01-15
365	265	2020-01-16	14	2020-01-08	2020-01-15
366	266	2020-01-16	21	2020-01-08	2020-01-15
367	267	2020-01-16	7	2020-01-08	2020-01-15
368	268	2020-01-16	14	2020-01-08	2020-01-15
369	269	2020-01-16	21	2020-01-08	2020-01-15
370	270	2020-01-16	21	2020-01-08	2020-01-15
371	271	2020-01-16	7	2020-01-08	2020-01-15
372	272	2020-01-16	7	2020-01-08	2020-01-15
373	273	2020-01-16	7	2020-01-08	2020-01-15
374	274	2020-01-16	21	2020-01-08	2020-01-15
375	275	2020-01-16	7	2020-01-08	2020-01-15
376	276	2020-01-16	21	2020-01-08	2020-01-15
377	277	2020-01-16	21	2020-01-08	2020-01-15
378	278	2020-01-16	14	2020-01-08	2020-01-15
379	279	2020-01-16	14	2020-01-08	2020-01-15
380	280	2020-01-16	7	2020-01-08	2020-01-15
381	281	2020-01-16	21	2020-01-08	2020-01-15
382	282	2020-01-16	7	2020-01-08	2020-01-15
383	283	2020-01-16	14	2020-01-08	2020-01-15
384	284	2020-01-16	7	2020-01-08	2020-01-15
385	285	2020-01-16	14	2020-01-08	2020-01-15
386	286	2020-01-16	14	2020-01-08	2020-01-15
387	287	2020-01-16	7	2020-01-08	2020-01-15
388	288	2020-01-16	7	2020-01-08	2020-01-15
389	289	2020-01-16	7	2020-01-08	2020-01-15
390	290	2020-01-16	21	2020-01-08	2020-01-15
391	291	2020-01-16	21	2020-01-08	2020-01-15
392	292	2020-01-16	21	2020-01-08	2020-01-15
393	293	2020-01-16	7	2020-01-08	2020-01-15
394	294	2020-01-16	14	2020-01-08	2020-01-15
395	295	2020-01-16	21	2020-01-08	2020-01-15
396	296	2020-01-16	14	2020-01-08	2020-01-15
397	297	2020-01-16	14	2020-01-08	2020-01-15
398	298	2020-01-16	14	2020-01-08	2020-01-15
399	299	2020-01-16	14	2020-01-08	2020-01-15
400	300	2020-01-16	7	2020-01-08	2020-01-15
\.


--
-- TOC entry 4972 (class 0 OID 17111)
-- Dependencies: 218
-- Data for Name: house_service_request; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.house_service_request (house_id, request_type, request_date, price_per_unit, accepted) FROM stdin;
1	water	1970-01-01	1	t
2	water	1970-01-01	1	t
3	water	1970-01-01	1	t
4	water	1970-01-01	1	t
5	water	1970-01-01	1	t
6	water	1970-01-01	1	t
7	water	1970-01-01	1	t
8	water	1970-01-01	1	t
9	water	1970-01-01	1	t
10	water	1970-01-01	1	t
11	water	1970-01-01	1	t
12	water	1970-01-01	1	t
13	water	1970-01-01	1	t
14	water	1970-01-01	1	t
15	water	1970-01-01	1	t
16	water	1970-01-01	1	t
17	water	1970-01-01	1	t
18	water	1970-01-01	1	t
19	water	1970-01-01	1	t
20	water	1970-01-01	1	t
21	water	1970-01-01	1	t
22	water	1970-01-01	1	t
23	water	1970-01-01	1	t
24	water	1970-01-01	1	t
25	water	1970-01-01	1	t
26	water	1970-01-01	1	t
27	water	1970-01-01	1	t
28	water	1970-01-01	1	t
29	water	1970-01-01	1	t
30	water	1970-01-01	1	t
31	water	1970-01-01	1	t
32	water	1970-01-01	1	t
33	water	1970-01-01	1	t
34	water	1970-01-01	1	t
35	water	1970-01-01	1	t
36	water	1970-01-01	1	t
37	water	1970-01-01	1	t
38	water	1970-01-01	1	t
39	water	1970-01-01	1	t
40	water	1970-01-01	1	t
41	water	1970-01-01	1	t
42	water	1970-01-01	1	t
43	water	1970-01-01	1	t
44	water	1970-01-01	1	t
45	water	1970-01-01	1	t
46	water	1970-01-01	1	t
47	water	1970-01-01	1	t
48	water	1970-01-01	1	t
49	water	1970-01-01	1	t
50	water	1970-01-01	1	t
51	water	1970-01-01	1	t
52	water	1970-01-01	1	t
53	water	1970-01-01	1	t
54	water	1970-01-01	1	t
55	water	1970-01-01	1	t
56	water	1970-01-01	1	t
57	water	1970-01-01	1	t
58	water	1970-01-01	1	t
59	water	1970-01-01	1	t
60	water	1970-01-01	1	t
61	water	1970-01-01	1	t
62	water	1970-01-01	1	t
63	water	1970-01-01	1	t
64	water	1970-01-01	1	t
65	water	1970-01-01	1	t
66	water	1970-01-01	1	t
67	water	1970-01-01	1	t
68	water	1970-01-01	1	t
69	water	1970-01-01	1	t
70	water	1970-01-01	1	t
71	water	1970-01-01	1	t
72	water	1970-01-01	1	t
73	water	1970-01-01	1	t
74	water	1970-01-01	1	t
75	water	1970-01-01	1	t
76	water	1970-01-01	1	t
77	water	1970-01-01	1	t
78	water	1970-01-01	1	t
79	water	1970-01-01	1	t
80	water	1970-01-01	1	t
81	water	1970-01-01	1	t
82	water	1970-01-01	1	t
83	water	1970-01-01	1	t
84	water	1970-01-01	1	t
85	water	1970-01-01	1	t
86	water	1970-01-01	1	t
87	water	1970-01-01	1	t
88	water	1970-01-01	1	t
89	water	1970-01-01	1	t
90	water	1970-01-01	1	t
91	water	1970-01-01	1	t
92	water	1970-01-01	1	t
93	water	1970-01-01	1	t
94	water	1970-01-01	1	t
95	water	1970-01-01	1	t
96	water	1970-01-01	1	t
97	water	1970-01-01	1	t
98	water	1970-01-01	1	t
99	water	1970-01-01	1	t
100	water	1970-01-01	1	t
101	water	1970-01-01	1	t
102	water	1970-01-01	1	t
103	water	1970-01-01	1	t
104	water	1970-01-01	1	t
105	water	1970-01-01	1	t
106	water	1970-01-01	1	t
107	water	1970-01-01	1	t
108	water	1970-01-01	1	t
109	water	1970-01-01	1	t
110	water	1970-01-01	1	t
111	water	1970-01-01	1	t
112	water	1970-01-01	1	t
113	water	1970-01-01	1	t
114	water	1970-01-01	1	t
115	water	1970-01-01	1	t
116	water	1970-01-01	1	t
117	water	1970-01-01	1	t
118	water	1970-01-01	1	t
119	water	1970-01-01	1	t
120	water	1970-01-01	1	t
121	water	1970-01-01	1	t
122	water	1970-01-01	1	t
123	water	1970-01-01	1	t
124	water	1970-01-01	1	t
125	water	1970-01-01	1	t
126	water	1970-01-01	1	t
127	water	1970-01-01	1	t
128	water	1970-01-01	1	t
129	water	1970-01-01	1	t
130	water	1970-01-01	1	t
131	water	1970-01-01	1	t
132	water	1970-01-01	1	t
133	water	1970-01-01	1	t
134	water	1970-01-01	1	t
135	water	1970-01-01	1	t
136	water	1970-01-01	1	t
137	water	1970-01-01	1	t
138	water	1970-01-01	1	t
139	water	1970-01-01	1	t
140	water	1970-01-01	1	t
141	water	1970-01-01	1	t
142	water	1970-01-01	1	t
143	water	1970-01-01	1	t
144	water	1970-01-01	1	t
145	water	1970-01-01	1	t
146	water	1970-01-01	1	t
147	water	1970-01-01	1	t
148	water	1970-01-01	1	t
149	water	1970-01-01	1	t
150	water	1970-01-01	1	t
151	water	1970-01-01	1	t
152	water	1970-01-01	1	t
153	water	1970-01-01	1	t
154	water	1970-01-01	1	t
155	water	1970-01-01	1	t
156	water	1970-01-01	1	t
157	water	1970-01-01	1	t
158	water	1970-01-01	1	t
159	water	1970-01-01	1	t
160	water	1970-01-01	1	t
161	water	1970-01-01	1	t
162	water	1970-01-01	1	t
163	water	1970-01-01	1	t
164	water	1970-01-01	1	t
165	water	1970-01-01	1	t
166	water	1970-01-01	1	t
167	water	1970-01-01	1	t
168	water	1970-01-01	1	t
169	water	1970-01-01	1	t
170	water	1970-01-01	1	t
171	water	1970-01-01	1	t
172	water	1970-01-01	1	t
173	water	1970-01-01	1	t
174	water	1970-01-01	1	t
175	water	1970-01-01	1	t
176	water	1970-01-01	1	t
177	water	1970-01-01	1	t
178	water	1970-01-01	1	t
179	water	1970-01-01	1	t
180	water	1970-01-01	1	t
181	water	1970-01-01	1	t
182	water	1970-01-01	1	t
183	water	1970-01-01	1	t
184	water	1970-01-01	1	t
185	water	1970-01-01	1	t
186	water	1970-01-01	1	t
187	water	1970-01-01	1	t
188	water	1970-01-01	1	t
189	water	1970-01-01	1	t
190	water	1970-01-01	1	t
191	water	1970-01-01	1	t
192	water	1970-01-01	1	t
193	water	1970-01-01	1	t
194	water	1970-01-01	1	t
195	water	1970-01-01	1	t
196	water	1970-01-01	1	t
197	water	1970-01-01	1	t
198	water	1970-01-01	1	t
199	water	1970-01-01	1	t
200	water	1970-01-01	1	t
201	water	1970-01-01	1	t
202	water	1970-01-01	1	t
203	water	1970-01-01	1	t
204	water	1970-01-01	1	t
205	water	1970-01-01	1	t
206	water	1970-01-01	1	t
207	water	1970-01-01	1	t
208	water	1970-01-01	1	t
209	water	1970-01-01	1	t
210	water	1970-01-01	1	t
211	water	1970-01-01	1	t
212	water	1970-01-01	1	t
213	water	1970-01-01	1	t
214	water	1970-01-01	1	t
215	water	1970-01-01	1	t
216	water	1970-01-01	1	t
217	water	1970-01-01	1	t
218	water	1970-01-01	1	t
219	water	1970-01-01	1	t
220	water	1970-01-01	1	t
221	water	1970-01-01	1	t
222	water	1970-01-01	1	t
223	water	1970-01-01	1	t
224	water	1970-01-01	1	t
225	water	1970-01-01	1	t
226	water	1970-01-01	1	t
227	water	1970-01-01	1	t
228	water	1970-01-01	1	t
229	water	1970-01-01	1	t
230	water	1970-01-01	1	t
231	water	1970-01-01	1	t
232	water	1970-01-01	1	t
233	water	1970-01-01	1	t
234	water	1970-01-01	1	t
235	water	1970-01-01	1	t
236	water	1970-01-01	1	t
237	water	1970-01-01	1	t
238	water	1970-01-01	1	t
239	water	1970-01-01	1	t
240	water	1970-01-01	1	t
241	water	1970-01-01	1	t
242	water	1970-01-01	1	t
243	water	1970-01-01	1	t
244	water	1970-01-01	1	t
245	water	1970-01-01	1	t
246	water	1970-01-01	1	t
247	water	1970-01-01	1	t
248	water	1970-01-01	1	t
249	water	1970-01-01	1	t
250	water	1970-01-01	1	t
251	water	1970-01-01	1	t
252	water	1970-01-01	1	t
253	water	1970-01-01	1	t
254	water	1970-01-01	1	t
255	water	1970-01-01	1	t
256	water	1970-01-01	1	t
257	water	1970-01-01	1	t
258	water	1970-01-01	1	t
259	water	1970-01-01	1	t
260	water	1970-01-01	1	t
261	water	1970-01-01	1	t
262	water	1970-01-01	1	t
263	water	1970-01-01	1	t
264	water	1970-01-01	1	t
265	water	1970-01-01	1	t
266	water	1970-01-01	1	t
267	water	1970-01-01	1	t
268	water	1970-01-01	1	t
269	water	1970-01-01	1	t
270	water	1970-01-01	1	t
271	water	1970-01-01	1	t
272	water	1970-01-01	1	t
273	water	1970-01-01	1	t
274	water	1970-01-01	1	t
275	water	1970-01-01	1	t
276	water	1970-01-01	1	t
277	water	1970-01-01	1	t
278	water	1970-01-01	1	t
279	water	1970-01-01	1	t
280	water	1970-01-01	1	t
281	water	1970-01-01	1	t
282	water	1970-01-01	1	t
283	water	1970-01-01	1	t
284	water	1970-01-01	1	t
285	water	1970-01-01	1	t
286	water	1970-01-01	1	t
287	water	1970-01-01	1	t
288	water	1970-01-01	1	t
289	water	1970-01-01	1	t
290	water	1970-01-01	1	t
291	water	1970-01-01	1	t
292	water	1970-01-01	1	t
293	water	1970-01-01	1	t
294	water	1970-01-01	1	t
295	water	1970-01-01	1	t
296	water	1970-01-01	1	t
297	water	1970-01-01	1	t
298	water	1970-01-01	1	t
299	water	1970-01-01	1	t
300	water	1970-01-01	1	t
301	water	1970-01-01	1	t
302	water	1970-01-01	1	t
303	water	1970-01-01	1	t
304	water	1970-01-01	1	t
305	water	1970-01-01	1	t
306	water	1970-01-01	1	t
307	water	1970-01-01	1	t
308	water	1970-01-01	1	t
309	water	1970-01-01	1	t
310	water	1970-01-01	1	t
311	water	1970-01-01	1	t
312	water	1970-01-01	1	t
313	water	1970-01-01	1	t
314	water	1970-01-01	1	t
315	water	1970-01-01	1	t
316	water	1970-01-01	1	t
317	water	1970-01-01	1	t
318	water	1970-01-01	1	t
319	water	1970-01-01	1	t
320	water	1970-01-01	1	t
321	water	1970-01-01	1	t
322	water	1970-01-01	1	t
323	water	1970-01-01	1	t
324	water	1970-01-01	1	t
325	water	1970-01-01	1	t
326	water	1970-01-01	1	t
327	water	1970-01-01	1	t
328	water	1970-01-01	1	t
329	water	1970-01-01	1	t
330	water	1970-01-01	1	t
331	water	1970-01-01	1	t
332	water	1970-01-01	1	t
333	water	1970-01-01	1	t
334	water	1970-01-01	1	t
335	water	1970-01-01	1	t
336	water	1970-01-01	1	t
337	water	1970-01-01	1	t
338	water	1970-01-01	1	t
339	water	1970-01-01	1	t
340	water	1970-01-01	1	t
341	water	1970-01-01	1	t
342	water	1970-01-01	1	t
343	water	1970-01-01	1	t
344	water	1970-01-01	1	t
345	water	1970-01-01	1	t
346	water	1970-01-01	1	t
347	water	1970-01-01	1	t
348	water	1970-01-01	1	t
349	water	1970-01-01	1	t
350	water	1970-01-01	1	t
351	water	1970-01-01	1	t
352	water	1970-01-01	1	t
353	water	1970-01-01	1	t
354	water	1970-01-01	1	t
355	water	1970-01-01	1	t
356	water	1970-01-01	1	t
357	water	1970-01-01	1	t
358	water	1970-01-01	1	t
359	water	1970-01-01	1	t
360	water	1970-01-01	1	t
361	water	1970-01-01	1	t
362	water	1970-01-01	1	t
363	water	1970-01-01	1	t
364	water	1970-01-01	1	t
365	water	1970-01-01	1	t
366	water	1970-01-01	1	t
367	water	1970-01-01	1	t
368	water	1970-01-01	1	t
369	water	1970-01-01	1	t
370	water	1970-01-01	1	t
371	water	1970-01-01	1	t
372	water	1970-01-01	1	t
373	water	1970-01-01	1	t
374	water	1970-01-01	1	t
375	water	1970-01-01	1	t
376	water	1970-01-01	1	t
377	water	1970-01-01	1	t
378	water	1970-01-01	1	t
379	water	1970-01-01	1	t
380	water	1970-01-01	1	t
381	water	1970-01-01	1	t
382	water	1970-01-01	1	t
383	water	1970-01-01	1	t
384	water	1970-01-01	1	t
385	water	1970-01-01	1	t
386	water	1970-01-01	1	t
387	water	1970-01-01	1	t
388	water	1970-01-01	1	t
389	water	1970-01-01	1	t
390	water	1970-01-01	1	t
391	water	1970-01-01	1	t
392	water	1970-01-01	1	t
393	water	1970-01-01	1	t
394	water	1970-01-01	1	t
395	water	1970-01-01	1	t
396	water	1970-01-01	1	t
397	water	1970-01-01	1	t
398	water	1970-01-01	1	t
399	water	1970-01-01	1	t
400	water	1970-01-01	1	t
401	water	1970-01-01	1	t
402	water	1970-01-01	1	t
403	water	1970-01-01	1	t
404	water	1970-01-01	1	t
405	water	1970-01-01	1	t
406	water	1970-01-01	1	t
407	water	1970-01-01	1	t
408	water	1970-01-01	1	t
409	water	1970-01-01	1	t
410	water	1970-01-01	1	t
411	water	1970-01-01	1	t
412	water	1970-01-01	1	t
413	water	1970-01-01	1	t
414	water	1970-01-01	1	t
415	water	1970-01-01	1	t
416	water	1970-01-01	1	t
417	water	1970-01-01	1	t
418	water	1970-01-01	1	t
419	water	1970-01-01	1	t
420	water	1970-01-01	1	t
421	water	1970-01-01	1	t
422	water	1970-01-01	1	t
423	water	1970-01-01	1	t
424	water	1970-01-01	1	t
425	water	1970-01-01	1	t
426	water	1970-01-01	1	t
427	water	1970-01-01	1	t
428	water	1970-01-01	1	t
429	water	1970-01-01	1	t
430	water	1970-01-01	1	t
431	water	1970-01-01	1	t
432	water	1970-01-01	1	t
433	water	1970-01-01	1	t
434	water	1970-01-01	1	t
435	water	1970-01-01	1	t
436	water	1970-01-01	1	t
437	water	1970-01-01	1	t
438	water	1970-01-01	1	t
439	water	1970-01-01	1	t
440	water	1970-01-01	1	t
441	water	1970-01-01	1	t
442	water	1970-01-01	1	t
443	water	1970-01-01	1	t
444	water	1970-01-01	1	t
445	water	1970-01-01	1	t
446	water	1970-01-01	1	t
447	water	1970-01-01	1	t
448	water	1970-01-01	1	t
449	water	1970-01-01	1	t
450	water	1970-01-01	1	t
451	water	1970-01-01	1	t
452	water	1970-01-01	1	t
453	water	1970-01-01	1	t
454	water	1970-01-01	1	t
455	water	1970-01-01	1	t
456	water	1970-01-01	1	t
457	water	1970-01-01	1	t
458	water	1970-01-01	1	t
459	water	1970-01-01	1	t
460	water	1970-01-01	1	t
461	water	1970-01-01	1	t
462	water	1970-01-01	1	t
463	water	1970-01-01	1	t
464	water	1970-01-01	1	t
465	water	1970-01-01	1	t
466	water	1970-01-01	1	t
467	water	1970-01-01	1	t
468	water	1970-01-01	1	t
469	water	1970-01-01	1	t
470	water	1970-01-01	1	t
471	water	1970-01-01	1	t
472	water	1970-01-01	1	t
473	water	1970-01-01	1	t
474	water	1970-01-01	1	t
475	water	1970-01-01	1	t
476	water	1970-01-01	1	t
477	water	1970-01-01	1	t
478	water	1970-01-01	1	t
479	water	1970-01-01	1	t
480	water	1970-01-01	1	t
481	water	1970-01-01	1	t
482	water	1970-01-01	1	t
483	water	1970-01-01	1	t
484	water	1970-01-01	1	t
485	water	1970-01-01	1	t
486	water	1970-01-01	1	t
487	water	1970-01-01	1	t
488	water	1970-01-01	1	t
489	water	1970-01-01	1	t
490	water	1970-01-01	1	t
491	water	1970-01-01	1	t
492	water	1970-01-01	1	t
493	water	1970-01-01	1	t
494	water	1970-01-01	1	t
495	water	1970-01-01	1	t
496	water	1970-01-01	1	t
497	water	1970-01-01	1	t
498	water	1970-01-01	1	t
499	water	1970-01-01	1	t
500	water	1970-01-01	1	t
1	power	1965-12-08	2	t
2	power	1968-06-05	2	t
2	gas	1956-05-15	3	t
3	power	1900-10-18	2	f
4	power	1976-07-19	2	t
5	power	1910-05-02	2	t
6	gas	1902-06-03	3	f
8	gas	1991-07-26	3	t
9	power	1985-03-16	2	t
10	power	2001-10-21	2	t
10	gas	1929-07-14	3	f
11	gas	1981-01-02	3	t
12	gas	1975-05-18	3	t
13	power	1922-02-06	2	f
15	power	2019-06-10	2	f
15	gas	1978-11-03	3	f
17	gas	1909-08-17	3	f
20	power	2010-04-25	2	t
22	gas	2017-10-16	3	f
23	gas	1960-01-25	3	f
26	power	1971-05-07	2	f
29	power	1956-08-23	2	f
30	gas	1986-04-11	3	t
31	gas	1974-02-05	3	t
32	gas	2014-10-02	3	t
36	power	1900-11-27	2	f
36	gas	1933-12-27	3	t
40	power	2021-05-20	2	t
40	gas	1943-09-05	3	f
41	power	1908-03-11	2	f
42	gas	1948-07-13	3	f
45	gas	2011-04-09	3	f
46	gas	1951-12-15	3	f
48	gas	1909-02-27	3	f
50	gas	1974-12-02	3	f
51	power	2016-02-06	2	f
52	power	2009-05-18	2	f
52	gas	2019-12-24	3	f
53	power	1936-10-12	2	t
56	power	1961-11-12	2	f
56	gas	1922-06-20	3	t
62	power	2009-06-11	2	f
63	power	1956-12-19	2	t
67	power	1945-03-10	2	f
68	gas	1972-03-03	3	t
69	gas	1903-01-18	3	f
70	power	1990-01-02	2	t
72	power	1986-03-27	2	f
73	power	2002-07-01	2	t
74	gas	1951-02-28	3	t
75	power	1902-10-13	2	t
76	power	1942-07-06	2	f
77	power	1957-07-23	2	t
80	gas	2003-01-27	3	t
81	gas	2009-02-20	3	t
84	power	1953-05-16	2	t
84	gas	2000-11-13	3	f
85	power	1915-11-11	2	f
86	power	1919-08-23	2	t
86	gas	2014-11-25	3	t
90	power	1922-11-11	2	t
90	gas	1914-12-15	3	t
91	gas	1914-08-16	3	f
92	gas	1926-10-09	3	t
93	power	2021-04-07	2	f
94	power	2018-08-09	2	f
95	gas	1967-01-16	3	t
96	power	1909-11-24	2	f
102	power	1990-10-04	2	t
104	power	1930-12-24	2	f
104	gas	2002-07-02	3	f
105	gas	1993-04-11	3	t
106	power	1913-09-05	2	f
107	power	1956-11-10	2	t
108	gas	1942-01-02	3	t
109	power	1912-07-09	2	f
110	power	2005-12-21	2	t
110	gas	1965-10-24	3	t
112	gas	2010-07-16	3	f
113	gas	2003-01-02	3	f
116	gas	1902-11-01	3	f
117	power	1997-04-05	2	t
119	power	1950-01-17	2	f
119	gas	1900-01-15	3	f
120	power	1952-02-21	2	f
121	gas	1916-04-03	3	f
123	gas	2007-11-01	3	t
126	gas	1950-05-08	3	f
127	power	1964-01-20	2	f
131	gas	1938-08-25	3	t
132	power	1912-12-19	2	f
132	gas	2014-06-12	3	t
133	power	1996-02-04	2	t
134	power	1903-09-23	2	f
134	gas	1925-06-13	3	f
135	gas	1970-06-18	3	t
136	gas	2021-08-15	3	t
137	power	1930-03-18	2	t
137	gas	1907-09-13	3	t
138	gas	2004-12-15	3	t
140	power	1909-01-27	2	t
142	power	1941-12-28	2	t
143	power	2019-06-06	2	f
143	gas	1931-03-02	3	f
144	gas	1970-01-15	3	t
145	power	1954-06-12	2	t
147	gas	1919-03-21	3	f
148	gas	1912-09-15	3	t
149	gas	1907-10-12	3	t
150	gas	1937-04-01	3	f
151	gas	1970-11-25	3	f
154	gas	1977-01-02	3	f
155	power	1952-10-20	2	f
155	gas	1951-01-06	3	f
157	power	1902-11-01	2	f
158	power	1940-01-04	2	f
159	power	1928-08-20	2	f
159	gas	2015-10-13	3	t
160	power	1950-03-06	2	t
161	gas	2019-03-13	3	f
163	gas	1977-09-25	3	t
164	power	1931-04-06	2	t
166	power	1929-06-17	2	t
166	gas	1917-05-10	3	t
168	gas	1974-08-18	3	f
172	gas	1935-04-19	3	t
173	power	1913-08-07	2	f
175	power	1950-01-14	2	f
175	gas	2021-06-21	3	t
178	gas	2014-03-23	3	t
179	power	1927-03-10	2	t
179	gas	1979-04-06	3	f
182	gas	1980-08-11	3	f
183	gas	1940-11-24	3	f
184	power	1919-07-25	2	t
186	gas	1916-02-02	3	t
188	gas	1927-04-16	3	t
191	power	1900-12-21	2	f
192	power	2002-11-09	2	t
193	power	1944-05-05	2	f
193	gas	1915-05-09	3	t
194	power	1918-08-17	2	t
195	power	1907-10-20	2	t
195	gas	1915-07-23	3	f
197	power	1977-05-26	2	f
199	power	1989-08-01	2	t
201	power	2009-10-28	2	f
201	gas	1975-09-20	3	t
204	gas	1932-06-16	3	t
206	power	1954-02-06	2	f
206	gas	1934-09-25	3	f
207	gas	1977-11-25	3	t
208	power	1961-05-10	2	f
209	power	1944-06-17	2	t
209	gas	1964-12-24	3	t
211	gas	1975-01-24	3	f
214	power	1919-03-18	2	f
214	gas	1927-09-24	3	f
215	power	1961-02-28	2	f
215	gas	1961-01-03	3	f
216	power	1934-07-12	2	f
217	gas	1962-05-18	3	t
219	power	1918-08-07	2	t
219	gas	1940-07-05	3	t
221	gas	1968-09-09	3	t
222	gas	1944-03-04	3	f
224	power	2006-12-04	2	f
225	power	1983-12-22	2	t
227	gas	1986-12-20	3	f
228	power	1936-06-11	2	f
230	power	2020-06-11	2	f
230	gas	1976-02-17	3	f
231	power	1974-05-25	2	f
231	gas	1935-07-10	3	f
232	gas	2017-02-02	3	f
233	power	1984-03-05	2	t
234	power	1916-06-02	2	t
234	gas	1901-07-12	3	t
235	power	1900-07-05	2	f
236	gas	2001-10-08	3	t
237	power	2018-08-03	2	t
237	gas	1914-09-19	3	t
238	gas	1972-03-11	3	t
239	power	1902-01-27	2	f
239	gas	2007-01-05	3	f
240	power	1925-09-03	2	f
240	gas	1970-08-02	3	f
241	power	1981-04-01	2	f
243	power	1981-04-01	2	f
245	power	1912-12-10	2	t
249	gas	2006-05-12	3	f
251	gas	1906-10-19	3	t
252	power	1961-09-21	2	t
253	power	1944-08-23	2	f
255	gas	1953-10-20	3	f
257	gas	2020-05-06	3	t
258	power	1949-04-25	2	t
258	gas	1932-09-19	3	t
262	gas	2002-09-21	3	f
265	gas	1976-08-07	3	f
270	power	1982-01-23	2	f
270	gas	1962-12-21	3	t
272	gas	1921-06-11	3	f
273	power	2005-11-26	2	f
274	power	1958-10-25	2	f
274	gas	1972-03-05	3	f
275	power	2022-04-19	2	f
278	power	2004-09-23	2	f
278	gas	1980-02-25	3	t
279	power	1986-07-11	2	t
279	gas	1937-11-22	3	f
280	gas	1975-02-26	3	t
281	gas	1927-05-01	3	t
283	power	1929-07-16	2	t
283	gas	1914-09-09	3	f
284	power	1915-11-14	2	f
284	gas	1958-07-10	3	f
285	gas	2015-08-16	3	f
286	power	1999-02-02	2	t
287	power	1902-11-15	2	f
288	power	1994-08-11	2	t
288	gas	1928-09-13	3	f
291	gas	2017-02-19	3	t
292	power	1976-10-17	2	t
293	gas	2018-05-22	3	t
294	gas	1975-05-22	3	t
295	power	1989-09-11	2	f
295	gas	1942-04-24	3	f
298	power	1929-11-15	2	t
298	gas	1944-09-27	3	f
299	power	1905-04-17	2	f
299	gas	1979-12-01	3	t
300	power	1928-04-07	2	f
300	gas	1980-04-25	3	t
\.


--
-- TOC entry 4978 (class 0 OID 17184)
-- Dependencies: 224
-- Data for Name: network; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.network (type, cost_per_km) FROM stdin;
bus	1
metro	2
taxi	3
\.


--
-- TOC entry 4976 (class 0 OID 17159)
-- Dependencies: 222
-- Data for Name: parking; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.parking (parking_id, opening_time, closing_time, name, location, capacity, cost_per_hour) FROM stdin;
1	08:00:00	22:00:00	arinbs	(127,507)	106	1
2	08:00:00	22:00:00	dnacuc	(833,30)	137	2
3	08:00:00	22:00:00	hkkfgp	(111,846)	200	3
4	08:00:00	22:00:00	vtpbux	(888,285)	167	4
5	08:00:00	22:00:00	vsydpg	(951,875)	170	5
6	08:00:00	22:00:00	ivzeof	(850,980)	153	6
7	08:00:00	22:00:00	asovoy	(704,29)	196	7
8	08:00:00	22:00:00	uqaxjr	(790,317)	187	8
9	08:00:00	22:00:00	ciqppl	(164,431)	154	9
10	08:00:00	22:00:00	otzlsm	(593,482)	174	10
\.


--
-- TOC entry 4977 (class 0 OID 17164)
-- Dependencies: 223
-- Data for Name: parking_bill; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.parking_bill (bill_id, vehicle_id, parking_id, to_account, issue_date, price, start_time, end_time) FROM stdin;
1	1	2	1	2020-01-15	10	2022-01-01 12:00:00	2022-01-01 17:00:00
2	2	3	2	2020-01-15	15	2022-01-01 12:00:00	2022-01-01 17:00:00
3	3	4	3	2020-01-15	20	2022-01-01 12:00:00	2022-01-01 17:00:00
4	4	5	4	2020-01-15	25	2022-01-01 12:00:00	2022-01-01 17:00:00
5	5	6	5	2020-01-15	30	2022-01-01 12:00:00	2022-01-01 17:00:00
6	6	7	6	2020-01-15	35	2022-01-01 12:00:00	2022-01-01 17:00:00
7	7	8	7	2020-01-15	40	2022-01-01 12:00:00	2022-01-01 17:00:00
8	8	9	8	2020-01-15	45	2022-01-01 12:00:00	2022-01-01 17:00:00
9	9	10	9	2020-01-15	50	2022-01-01 12:00:00	2022-01-01 17:00:00
10	10	1	10	2020-01-15	5	2022-01-01 12:00:00	2022-01-01 17:00:00
11	11	2	11	2020-01-15	10	2022-01-01 12:00:00	2022-01-01 17:00:00
12	12	3	12	2020-01-15	15	2022-01-01 12:00:00	2022-01-01 17:00:00
13	13	4	13	2020-01-15	20	2022-01-01 12:00:00	2022-01-01 17:00:00
14	14	5	14	2020-01-15	25	2022-01-01 12:00:00	2022-01-01 17:00:00
15	15	6	15	2020-01-15	30	2022-01-01 12:00:00	2022-01-01 17:00:00
16	16	7	16	2020-01-15	35	2022-01-01 12:00:00	2022-01-01 17:00:00
17	17	8	17	2020-01-15	40	2022-01-01 12:00:00	2022-01-01 17:00:00
18	18	9	18	2020-01-15	45	2022-01-01 12:00:00	2022-01-01 17:00:00
19	19	10	19	2020-01-15	50	2022-01-01 12:00:00	2022-01-01 17:00:00
20	20	1	20	2020-01-15	5	2022-01-01 12:00:00	2022-01-01 17:00:00
21	21	2	21	2020-01-15	10	2022-01-01 12:00:00	2022-01-01 17:00:00
22	22	3	22	2020-01-15	15	2022-01-01 12:00:00	2022-01-01 17:00:00
23	23	4	23	2020-01-15	20	2022-01-01 12:00:00	2022-01-01 17:00:00
24	24	5	24	2020-01-15	25	2022-01-01 12:00:00	2022-01-01 17:00:00
25	25	6	25	2020-01-15	30	2022-01-01 12:00:00	2022-01-01 17:00:00
26	26	7	26	2020-01-15	35	2022-01-01 12:00:00	2022-01-01 17:00:00
27	27	8	27	2020-01-15	40	2022-01-01 12:00:00	2022-01-01 17:00:00
28	28	9	28	2020-01-15	45	2022-01-01 12:00:00	2022-01-01 17:00:00
29	29	10	29	2020-01-15	50	2022-01-01 12:00:00	2022-01-01 17:00:00
30	30	1	30	2020-01-15	5	2022-01-01 12:00:00	2022-01-01 17:00:00
31	31	2	31	2020-01-15	10	2022-01-01 12:00:00	2022-01-01 17:00:00
32	32	3	32	2020-01-15	15	2022-01-01 12:00:00	2022-01-01 17:00:00
33	33	4	33	2020-01-15	20	2022-01-01 12:00:00	2022-01-01 17:00:00
34	34	5	34	2020-01-15	25	2022-01-01 12:00:00	2022-01-01 17:00:00
35	35	6	35	2020-01-15	30	2022-01-01 12:00:00	2022-01-01 17:00:00
36	36	7	36	2020-01-15	35	2022-01-01 12:00:00	2022-01-01 17:00:00
37	37	8	37	2020-01-15	40	2022-01-01 12:00:00	2022-01-01 17:00:00
38	38	9	38	2020-01-15	45	2022-01-01 12:00:00	2022-01-01 17:00:00
39	39	10	39	2020-01-15	50	2022-01-01 12:00:00	2022-01-01 17:00:00
40	40	1	40	2020-01-15	5	2022-01-01 12:00:00	2022-01-01 17:00:00
41	41	2	41	2020-01-15	10	2022-01-01 12:00:00	2022-01-01 17:00:00
42	42	3	42	2020-01-15	15	2022-01-01 12:00:00	2022-01-01 17:00:00
43	43	4	43	2020-01-15	20	2022-01-01 12:00:00	2022-01-01 17:00:00
44	44	5	44	2020-01-15	25	2022-01-01 12:00:00	2022-01-01 17:00:00
45	45	6	45	2020-01-15	30	2022-01-01 12:00:00	2022-01-01 17:00:00
46	46	7	46	2020-01-15	35	2022-01-01 12:00:00	2022-01-01 17:00:00
47	47	8	47	2020-01-15	40	2022-01-01 12:00:00	2022-01-01 17:00:00
48	48	9	48	2020-01-15	45	2022-01-01 12:00:00	2022-01-01 17:00:00
49	49	10	49	2020-01-15	50	2022-01-01 12:00:00	2022-01-01 17:00:00
50	50	1	50	2020-01-15	5	2022-01-01 12:00:00	2022-01-01 17:00:00
51	51	2	51	2020-01-15	10	2022-01-01 12:00:00	2022-01-01 17:00:00
52	52	3	52	2020-01-15	15	2022-01-01 12:00:00	2022-01-01 17:00:00
53	53	4	53	2020-01-15	20	2022-01-01 12:00:00	2022-01-01 17:00:00
54	54	5	54	2020-01-15	25	2022-01-01 12:00:00	2022-01-01 17:00:00
55	55	6	55	2020-01-15	30	2022-01-01 12:00:00	2022-01-01 17:00:00
56	56	7	56	2020-01-15	35	2022-01-01 12:00:00	2022-01-01 17:00:00
57	57	8	57	2020-01-15	40	2022-01-01 12:00:00	2022-01-01 17:00:00
58	58	9	58	2020-01-15	45	2022-01-01 12:00:00	2022-01-01 17:00:00
59	59	10	59	2020-01-15	50	2022-01-01 12:00:00	2022-01-01 17:00:00
60	60	1	60	2020-01-15	5	2022-01-01 12:00:00	2022-01-01 17:00:00
61	61	2	61	2020-01-15	10	2022-01-01 12:00:00	2022-01-01 17:00:00
62	62	3	62	2020-01-15	15	2022-01-01 12:00:00	2022-01-01 17:00:00
63	63	4	63	2020-01-15	20	2022-01-01 12:00:00	2022-01-01 17:00:00
64	64	5	64	2020-01-15	25	2022-01-01 12:00:00	2022-01-01 17:00:00
65	65	6	65	2020-01-15	30	2022-01-01 12:00:00	2022-01-01 17:00:00
66	66	7	66	2020-01-15	35	2022-01-01 12:00:00	2022-01-01 17:00:00
67	67	8	67	2020-01-15	40	2022-01-01 12:00:00	2022-01-01 17:00:00
68	68	9	68	2020-01-15	45	2022-01-01 12:00:00	2022-01-01 17:00:00
69	69	10	69	2020-01-15	50	2022-01-01 12:00:00	2022-01-01 17:00:00
70	70	1	70	2020-01-15	5	2022-01-01 12:00:00	2022-01-01 17:00:00
71	71	2	71	2020-01-15	10	2022-01-01 12:00:00	2022-01-01 17:00:00
72	72	3	72	2020-01-15	15	2022-01-01 12:00:00	2022-01-01 17:00:00
73	73	4	73	2020-01-15	20	2022-01-01 12:00:00	2022-01-01 17:00:00
74	74	5	74	2020-01-15	25	2022-01-01 12:00:00	2022-01-01 17:00:00
75	75	6	75	2020-01-15	30	2022-01-01 12:00:00	2022-01-01 17:00:00
76	76	7	76	2020-01-15	35	2022-01-01 12:00:00	2022-01-01 17:00:00
77	77	8	77	2020-01-15	40	2022-01-01 12:00:00	2022-01-01 17:00:00
78	78	9	78	2020-01-15	45	2022-01-01 12:00:00	2022-01-01 17:00:00
79	79	10	79	2020-01-15	50	2022-01-01 12:00:00	2022-01-01 17:00:00
80	80	1	80	2020-01-15	5	2022-01-01 12:00:00	2022-01-01 17:00:00
81	81	2	81	2020-01-15	10	2022-01-01 12:00:00	2022-01-01 17:00:00
82	82	3	82	2020-01-15	15	2022-01-01 12:00:00	2022-01-01 17:00:00
83	83	4	83	2020-01-15	20	2022-01-01 12:00:00	2022-01-01 17:00:00
84	84	5	84	2020-01-15	25	2022-01-01 12:00:00	2022-01-01 17:00:00
85	85	6	85	2020-01-15	30	2022-01-01 12:00:00	2022-01-01 17:00:00
86	86	7	86	2020-01-15	35	2022-01-01 12:00:00	2022-01-01 17:00:00
87	87	8	87	2020-01-15	40	2022-01-01 12:00:00	2022-01-01 17:00:00
88	88	9	88	2020-01-15	45	2022-01-01 12:00:00	2022-01-01 17:00:00
89	89	10	89	2020-01-15	50	2022-01-01 12:00:00	2022-01-01 17:00:00
90	90	1	90	2020-01-15	5	2022-01-01 12:00:00	2022-01-01 17:00:00
91	91	2	91	2020-01-15	10	2022-01-01 12:00:00	2022-01-01 17:00:00
92	92	3	92	2020-01-15	15	2022-01-01 12:00:00	2022-01-01 17:00:00
93	93	4	93	2020-01-15	20	2022-01-01 12:00:00	2022-01-01 17:00:00
94	94	5	94	2020-01-15	25	2022-01-01 12:00:00	2022-01-01 17:00:00
95	95	6	95	2020-01-15	30	2022-01-01 12:00:00	2022-01-01 17:00:00
96	96	7	96	2020-01-15	35	2022-01-01 12:00:00	2022-01-01 17:00:00
97	97	8	97	2020-01-15	40	2022-01-01 12:00:00	2022-01-01 17:00:00
98	98	9	98	2020-01-15	45	2022-01-01 12:00:00	2022-01-01 17:00:00
99	99	10	99	2020-01-15	50	2022-01-01 12:00:00	2022-01-01 17:00:00
100	100	1	100	2020-01-15	5	2022-01-01 12:00:00	2022-01-01 17:00:00
1000	10	2	2	2023-12-18	10	2022-01-01 13:00:00	2022-01-01 15:00:00
\.


--
-- TOC entry 4980 (class 0 OID 17206)
-- Dependencies: 226
-- Data for Name: path; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.path (path_id, type, name) FROM stdin;
1	metro	khat-1
2	taxi	khat-2
3	bus	khat-0
4	metro	khat-1
5	taxi	khat-2
6	bus	khat-0
\.


--
-- TOC entry 4975 (class 0 OID 17149)
-- Dependencies: 221
-- Data for Name: personal_vehicle; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.personal_vehicle (vehicle_id, owner, brand, color) FROM stdin;
1	1	pydht	iskniw
2	2	savsa	myqapk
3	3	baclw	iczqdr
4	4	xykwg	gqztbw
5	5	rhfuz	atbqid
6	6	wazsq	flqcvf
7	7	pmhom	zvgram
8	8	frivs	zgfmms
9	9	mvwnz	offngl
10	10	cjyof	jvtrqc
11	11	rirse	ncjbbg
12	12	soyyu	uboumg
13	13	qqoak	woaoah
14	14	gijte	nsqres
15	15	yybck	ruhasf
16	16	ipzso	dgcrht
17	17	gjvlk	dlchcc
18	18	pvpwy	csohnq
19	19	ffhqp	ifarqc
20	20	wgrwh	okorkp
21	21	coqpz	lcynur
22	22	ufgfh	cibbyb
23	23	coezr	tsyesr
24	24	jnxau	dfehjk
25	25	ugyjr	btomst
26	26	fwotw	ssyvoi
27	27	kmnuc	rmvkxu
28	28	jvvjh	drjpnr
29	29	znnvp	veiwop
30	30	addcw	tzldee
31	31	txvtw	czxlcs
32	32	nwfhd	ifyzbz
33	33	unxjx	xwmpbm
34	34	vtgys	unvydv
35	35	fxfaa	ehvekt
36	36	ntglk	pxyiwk
37	37	gykgy	hxrqoy
38	38	mbnub	luyldx
39	39	zfvpx	oljyum
40	40	jxgsw	xjtuoc
41	41	gdzos	kiuiyn
42	42	cgmur	loldok
43	43	ndexv	bncnep
44	44	gthff	qdrsfl
45	45	arrem	snpbnu
46	46	apdwd	qxnkeu
47	47	ahlkn	phuqep
48	48	ckeam	ncfqiv
49	49	zwlqa	zyfsbj
50	50	broae	ahbzhu
51	51	ubyvk	qfevdi
52	52	hznnr	ecvrrv
53	53	mfjda	ofumnv
54	54	ekajt	nigdcl
55	55	llsst	brgtik
56	56	cywmt	lpsrpp
57	57	eylvs	ffyrwf
58	58	oqwrh	grdker
59	59	anain	hryboe
60	60	plhkl	gizakt
61	61	uymcp	idzgpd
62	62	hdqvn	jlsbmv
63	63	hjxpw	rhudgz
64	64	solku	wipdrg
65	65	ygfcj	fypolg
66	66	qfnbv	bramat
67	67	xuhmw	hsdylp
68	68	yuyjs	phacjy
69	69	vzqgv	vowfps
70	70	jaxgx	ttugzv
71	71	hesql	atmjpq
72	72	hzhcj	vajeng
73	73	ncnzm	rtncmd
74	74	dvonv	gonoqe
75	75	xoiek	jeqlvg
76	76	pqftx	yldxub
77	77	fzdmk	lubsad
78	78	iwfwp	mrehhv
79	79	dudwe	uvyzfu
80	80	fvzho	tgtsan
81	81	ibxyt	viwihi
82	82	maati	siwfkf
83	83	uaelv	gztjmf
84	84	sxlhn	cxhaqs
85	85	yefer	wawstb
86	86	tlipz	htzjoe
87	87	hocks	enajpf
88	88	ucwxe	ttlqyp
89	89	qpigl	vrxzgo
90	90	dqddj	vpvfjp
91	91	ygvnu	fzrygu
92	92	rzkfd	qnftka
93	93	syffk	tcfdzq
94	94	ebsoe	yfjwrf
95	95	ehame	ehbnwq
96	96	xehkg	fspmzi
97	97	crrkn	fwvcjd
98	98	jpcnq	ucmioj
99	99	vxiev	gskqiw
100	100	zxtfl	cnlwzd
\.


--
-- TOC entry 4979 (class 0 OID 17189)
-- Dependencies: 225
-- Data for Name: public_vehicle; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.public_vehicle (vehicle_id, driver, network, brand, color) FROM stdin;
1	1	metro	gplrq	yxrhz
2	2	taxi	keoey	xdgdt
3	3	bus	lgozf	kcwow
4	4	metro	emlbn	owudn
5	5	taxi	xossi	qagfd
6	6	bus	cntwj	zfxuh
7	7	metro	tjwaj	eqxeq
8	8	taxi	umjoh	dbuhf
9	9	bus	jhazy	zywcz
10	10	metro	rrwmz	afxez
11	11	taxi	phqpc	fwyoh
12	12	bus	pttif	qylxa
13	13	metro	phfmb	pimou
14	14	taxi	cbqii	ayldk
15	15	bus	kwpbm	vybkh
16	16	metro	jwmdt	dytdp
17	17	taxi	ebdcx	qsgbl
18	18	bus	kidiu	ukjdm
19	19	metro	luzpv	jkymc
20	20	taxi	cbpbs	zspza
21	21	bus	bkrkd	baycg
22	22	metro	guzoq	ficuw
23	23	taxi	lhkkz	edxmc
24	24	bus	nplya	fesqr
25	25	metro	cazcr	hzkct
26	26	taxi	omhig	jdyyn
27	27	bus	cfbsz	qlooo
28	28	metro	hpnhs	crhol
29	29	taxi	doltg	hrnio
30	30	bus	vruiv	nisni
31	31	metro	wjhlu	cwpjc
32	32	taxi	blpnn	xqppi
33	33	bus	zznqx	rkucz
34	34	metro	hbitf	srefw
35	35	taxi	bwpqw	hehei
36	36	bus	adsbe	oekek
37	37	metro	lasro	ngyeg
38	38	taxi	kkrbc	lgidq
39	39	bus	wwvqc	jrhke
40	40	metro	gcvzs	aaqxq
41	41	taxi	nxish	eobos
42	42	bus	fdbvl	jpxkx
43	43	metro	mpbhk	sozti
44	44	taxi	ginyv	nvcfk
45	45	bus	wsyix	mojdm
46	46	metro	czzqw	vjftl
47	47	taxi	tbjch	ppejg
48	48	bus	ijtke	mazoz
49	49	metro	kskhx	hbyfs
50	50	taxi	htrmu	htlze
51	51	bus	vxlyh	lamml
52	52	metro	mfwnv	ccrfv
53	53	taxi	vnmax	yeska
54	54	bus	orqko	vzxnu
55	55	metro	ttnhf	trsec
56	56	taxi	dnjpb	rwnjo
57	57	bus	ezzvi	uuvjd
58	58	metro	vnpzn	nbmcq
59	59	taxi	zrbff	khozh
60	60	bus	wtdhm	abakp
61	61	metro	smeev	htrve
62	62	taxi	azmab	rmkqr
63	63	bus	ympev	dnkem
64	64	metro	ywyey	ltcoy
65	65	taxi	soxwc	fuiym
66	66	bus	cqllm	mfmeo
67	67	metro	jjytf	sninr
68	68	taxi	iyhox	edjti
69	69	bus	cmfwu	snxpp
70	70	metro	fmlxb	jpdxq
71	71	taxi	duwxg	uszhq
72	72	bus	suhbq	hebyb
73	73	metro	jtnqs	pdbrp
74	74	taxi	welvp	wrjev
75	75	bus	xpvxq	yptru
76	76	metro	bzdwm	zpgqd
77	77	taxi	yfhaq	zxqtu
78	78	bus	zttqv	onijh
79	79	metro	zodks	pruca
80	80	taxi	kqyow	gawny
81	81	bus	puvqz	qizkx
82	82	metro	vmqks	donvv
83	83	taxi	apsmc	vekpd
84	84	bus	rmxua	lygjj
85	85	metro	dqmsj	nfxfm
86	86	taxi	uaqev	mxqlb
87	87	bus	uywco	dagtd
88	88	metro	dbpxz	iswlt
89	89	taxi	umafd	pgbal
90	90	bus	nyklj	pwpht
\.


--
-- TOC entry 4982 (class 0 OID 17217)
-- Dependencies: 228
-- Data for Name: station; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.station (station_id, location, name) FROM stdin;
1	(942,36)	oatild
2	(263,215)	byldzv
3	(726,658)	iieanq
4	(734,399)	buligd
5	(372,963)	crryvm
6	(205,274)	hiefpg
7	(907,943)	segbhg
8	(443,41)	rtdgve
9	(31,465)	lqzopd
10	(124,10)	kxocnv
11	(329,405)	srubkq
12	(839,377)	ajivls
13	(121,937)	xrsjgx
14	(432,41)	anxthh
15	(778,116)	xnqapr
16	(907,162)	vyxcos
17	(60,800)	svhvno
18	(573,388)	vrhuxv
19	(72,186)	xbxeyz
20	(521,843)	kgdurk
21	(357,493)	sytdmq
22	(287,706)	mmkizp
23	(710,562)	bflnhe
24	(676,899)	ogdzci
25	(747,548)	snhmlk
26	(161,902)	fuenfe
27	(525,278)	fzmkdh
28	(474,102)	yzrcex
29	(369,786)	afwgyh
30	(36,130)	hgbgio
\.


--
-- TOC entry 4984 (class 0 OID 17224)
-- Dependencies: 230
-- Data for Name: station_path; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.station_path (path_id, station_id) FROM stdin;
1	1
1	2
1	3
1	4
1	5
1	6
2	6
2	7
2	8
2	9
2	10
2	11
3	11
3	12
3	13
3	14
3	15
3	16
4	16
4	17
4	18
4	19
4	20
4	21
5	21
5	22
5	23
5	24
5	25
5	26
6	26
6	27
6	28
6	29
6	30
6	1
\.


--
-- TOC entry 4993 (class 0 OID 17279)
-- Dependencies: 239
-- Data for Name: traversed_path; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.traversed_path (trip_id, path_id, start_station, end_station, entrance_time) FROM stdin;
1	1	1	2	2020-01-01 12:00:00
1	1	2	3	2020-01-01 12:00:10
1	1	3	4	2020-01-01 12:00:20
2	1	2	3	2020-01-01 12:00:10
2	1	3	4	2020-01-01 12:00:20
2	1	4	5	2020-01-01 12:00:30
3	2	1	2	2020-01-01 13:00:00
3	2	2	3	2020-01-01 13:00:10
3	2	3	4	2020-01-01 13:00:20
4	2	2	3	2020-01-01 13:00:10
5	1	1	2	2023-12-17 12:00:00
5	1	2	3	2023-12-17 12:00:10
5	1	3	4	2023-12-17 12:00:20
6	1	2	3	2023-12-17 12:00:10
6	1	3	4	2023-12-17 12:00:20
6	1	4	5	2023-12-17 12:00:30
7	2	1	2	2023-12-17 13:00:00
7	2	2	3	2023-12-17 13:00:10
7	2	3	4	2023-12-17 13:00:20
8	2	2	3	2023-12-17 13:00:10
9	1	1	2	2023-12-17 12:00:00
9	1	2	3	2023-12-17 12:00:10
9	1	3	4	2023-12-17 12:00:20
10	1	2	3	2023-12-17 12:00:10
10	1	3	4	2023-12-17 12:00:20
10	1	4	5	2023-12-17 12:00:30
11	2	6	7	2023-12-17 13:00:00
11	2	7	8	2023-12-17 13:00:10
11	2	8	9	2023-12-17 13:00:20
12	2	7	8	2023-12-17 13:00:10
\.


--
-- TOC entry 4989 (class 0 OID 17265)
-- Dependencies: 235
-- Data for Name: trip; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.trip (trip_id, vehicle_id, start_time, end_time, total_distance) FROM stdin;
1	1	2020-01-01 12:00:00	2020-01-01 12:00:30	5
2	1	2020-01-01 12:00:10	2020-01-01 12:00:40	4
3	2	2020-01-01 13:00:00	2020-01-01 13:00:30	5
4	2	2020-01-01 13:00:10	2020-01-01 13:00:20	1
5	1	2023-12-17 12:00:00	2023-12-17 12:00:30	5
6	1	2023-12-17 12:00:10	2023-12-17 12:00:40	4
7	2	2023-12-17 13:00:00	2023-12-17 13:00:30	5
8	2	2023-12-17 13:00:10	2023-12-17 13:00:20	1
9	3	2023-12-17 12:00:00	2023-12-17 12:00:30	5
10	3	2023-12-17 12:00:10	2023-12-17 12:00:40	4
11	4	2023-12-17 13:00:00	2023-12-17 13:00:30	5
12	4	2023-12-17 13:00:10	2023-12-17 13:00:20	1
\.


--
-- TOC entry 4995 (class 0 OID 17308)
-- Dependencies: 241
-- Data for Name: trip_bill; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.trip_bill (bill_id, trip_id, to_account, issue_date, price) FROM stdin;
1	1	1	2020-01-08	5
2	2	2	2020-01-09	4
3	3	1	2020-01-10	10
4	3	1	2020-01-10	2
5	5	1	2023-12-08	5
6	6	2	2023-12-09	4
7	7	1	2023-12-10	10
8	8	3	2023-12-10	2
9	9	1	2023-12-08	5
10	10	2	2023-12-09	4
11	11	1	2023-12-10	10
12	12	3	2023-12-10	2
\.


--
-- TOC entry 5010 (class 0 OID 0)
-- Dependencies: 232
-- Name: edge_in_path_end_station_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.edge_in_path_end_station_seq', 1, false);


--
-- TOC entry 5011 (class 0 OID 0)
-- Dependencies: 231
-- Name: edge_in_path_start_station_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.edge_in_path_start_station_seq', 1, false);


--
-- TOC entry 5012 (class 0 OID 0)
-- Dependencies: 229
-- Name: station_path_station_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.station_path_station_id_seq', 1, false);


--
-- TOC entry 5013 (class 0 OID 0)
-- Dependencies: 227
-- Name: station_station_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.station_station_id_seq', 1, false);


--
-- TOC entry 5014 (class 0 OID 0)
-- Dependencies: 238
-- Name: traversed_path_end_station_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.traversed_path_end_station_seq', 1, false);


--
-- TOC entry 5015 (class 0 OID 0)
-- Dependencies: 237
-- Name: traversed_path_start_station_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.traversed_path_start_station_seq', 1, false);


--
-- TOC entry 5016 (class 0 OID 0)
-- Dependencies: 236
-- Name: traversed_path_trip_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.traversed_path_trip_id_seq', 1, false);


--
-- TOC entry 5017 (class 0 OID 0)
-- Dependencies: 240
-- Name: trip_bill_trip_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.trip_bill_trip_id_seq', 1, false);


--
-- TOC entry 5018 (class 0 OID 0)
-- Dependencies: 234
-- Name: trip_trip_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.trip_trip_id_seq', 1, false);


--
-- TOC entry 4750 (class 2606 OID 17093)
-- Name: account account_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_pkey PRIMARY KEY (owner);


--
-- TOC entry 4748 (class 2606 OID 17083)
-- Name: citizen citizen_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.citizen
    ADD CONSTRAINT citizen_pkey PRIMARY KEY (national_id);


--
-- TOC entry 4760 (class 2606 OID 17138)
-- Name: daily_usage daily_usage_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.daily_usage
    ADD CONSTRAINT daily_usage_pkey PRIMARY KEY (request_type, request_date, house_id, usage_date);


--
-- TOC entry 4780 (class 2606 OID 17248)
-- Name: edge_in_path edge_in_path_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.edge_in_path
    ADD CONSTRAINT edge_in_path_pkey PRIMARY KEY (path_id, start_station, end_station);


--
-- TOC entry 4758 (class 2606 OID 17127)
-- Name: house_bill house_bill_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.house_bill
    ADD CONSTRAINT house_bill_pkey PRIMARY KEY (bill_id);


--
-- TOC entry 4752 (class 2606 OID 17103)
-- Name: house house_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.house
    ADD CONSTRAINT house_pkey PRIMARY KEY (house_id);


--
-- TOC entry 4754 (class 2606 OID 17105)
-- Name: house house_postal_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.house
    ADD CONSTRAINT house_postal_code_key UNIQUE (postal_code);


--
-- TOC entry 4756 (class 2606 OID 17117)
-- Name: house_service_request house_service_request_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.house_service_request
    ADD CONSTRAINT house_service_request_pkey PRIMARY KEY (request_type, request_date, house_id);


--
-- TOC entry 4768 (class 2606 OID 17188)
-- Name: network network_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.network
    ADD CONSTRAINT network_pkey PRIMARY KEY (type);


--
-- TOC entry 4766 (class 2606 OID 17168)
-- Name: parking_bill parking_bill_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parking_bill
    ADD CONSTRAINT parking_bill_pkey PRIMARY KEY (bill_id);


--
-- TOC entry 4764 (class 2606 OID 17163)
-- Name: parking parking_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parking
    ADD CONSTRAINT parking_pkey PRIMARY KEY (parking_id);


--
-- TOC entry 4774 (class 2606 OID 17210)
-- Name: path path_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.path
    ADD CONSTRAINT path_pkey PRIMARY KEY (path_id);


--
-- TOC entry 4762 (class 2606 OID 17153)
-- Name: personal_vehicle personal_vehicle_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal_vehicle
    ADD CONSTRAINT personal_vehicle_pkey PRIMARY KEY (vehicle_id);


--
-- TOC entry 4770 (class 2606 OID 17195)
-- Name: public_vehicle public_vehicle_driver_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.public_vehicle
    ADD CONSTRAINT public_vehicle_driver_key UNIQUE (driver);


--
-- TOC entry 4772 (class 2606 OID 17193)
-- Name: public_vehicle public_vehicle_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.public_vehicle
    ADD CONSTRAINT public_vehicle_pkey PRIMARY KEY (vehicle_id);


--
-- TOC entry 4778 (class 2606 OID 17229)
-- Name: station_path station_path_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.station_path
    ADD CONSTRAINT station_path_pkey PRIMARY KEY (path_id, station_id);


--
-- TOC entry 4776 (class 2606 OID 17222)
-- Name: station station_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.station
    ADD CONSTRAINT station_pkey PRIMARY KEY (station_id);


--
-- TOC entry 4784 (class 2606 OID 17286)
-- Name: traversed_path traversed_path_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.traversed_path
    ADD CONSTRAINT traversed_path_pkey PRIMARY KEY (trip_id, path_id, start_station, end_station);


--
-- TOC entry 4786 (class 2606 OID 17313)
-- Name: trip_bill trip_bill_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trip_bill
    ADD CONSTRAINT trip_bill_pkey PRIMARY KEY (bill_id);


--
-- TOC entry 4782 (class 2606 OID 17270)
-- Name: trip trip_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trip
    ADD CONSTRAINT trip_pkey PRIMARY KEY (trip_id);


--
-- TOC entry 4813 (class 2620 OID 17361)
-- Name: house_bill house_bill_time_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER house_bill_time_trigger BEFORE INSERT OR UPDATE ON public.house_bill FOR EACH ROW EXECUTE FUNCTION public.validate_start_date_before_finish_date();


--
-- TOC entry 4816 (class 2620 OID 17367)
-- Name: parking_bill parking_bill_create_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER parking_bill_create_trigger BEFORE UPDATE ON public.parking_bill FOR EACH ROW EXECUTE FUNCTION public.issue_parking_bill();


--
-- TOC entry 4817 (class 2620 OID 17364)
-- Name: parking_bill parking_bill_negetive_balance_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER parking_bill_negetive_balance_trigger BEFORE INSERT ON public.parking_bill FOR EACH ROW EXECUTE FUNCTION public.validate_parking_bill_negetive_balance();


--
-- TOC entry 4818 (class 2620 OID 17359)
-- Name: parking_bill parking_bill_time_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER parking_bill_time_trigger BEFORE INSERT OR UPDATE ON public.parking_bill FOR EACH ROW EXECUTE FUNCTION public.validate_start_time_before_end_time();


--
-- TOC entry 4815 (class 2620 OID 17357)
-- Name: parking parking_time_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER parking_time_trigger BEFORE INSERT OR UPDATE ON public.parking FOR EACH ROW EXECUTE FUNCTION public.validate_opening_time_before_closing_time();


--
-- TOC entry 4819 (class 2620 OID 17369)
-- Name: trip trip_bill_create_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trip_bill_create_trigger AFTER UPDATE ON public.trip FOR EACH ROW EXECUTE FUNCTION public.issue_trip_bill();


--
-- TOC entry 4821 (class 2620 OID 17365)
-- Name: trip_bill trip_bill_negetive_balance_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trip_bill_negetive_balance_trigger BEFORE INSERT ON public.trip_bill FOR EACH ROW EXECUTE FUNCTION public.validate_parking_bill_negetive_balance();


--
-- TOC entry 4820 (class 2620 OID 17362)
-- Name: trip trip_time_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trip_time_trigger BEFORE INSERT OR UPDATE ON public.trip FOR EACH ROW EXECUTE FUNCTION public.validate_start_time_before_end_time();


--
-- TOC entry 4814 (class 2620 OID 17371)
-- Name: house_bill withdraw_for_house_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER withdraw_for_house_trigger AFTER INSERT OR UPDATE ON public.house_bill FOR EACH ROW EXECUTE FUNCTION public.withdraw_for_house();


--
-- TOC entry 4788 (class 2606 OID 17094)
-- Name: account account_owner_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_owner_fkey FOREIGN KEY (owner) REFERENCES public.citizen(national_id);


--
-- TOC entry 4787 (class 2606 OID 17084)
-- Name: citizen citizen_headman_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.citizen
    ADD CONSTRAINT citizen_headman_fkey FOREIGN KEY (headman) REFERENCES public.citizen(national_id);


--
-- TOC entry 4792 (class 2606 OID 17144)
-- Name: daily_usage daily_usage_bill_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.daily_usage
    ADD CONSTRAINT daily_usage_bill_id_fkey FOREIGN KEY (bill_id) REFERENCES public.house_bill(bill_id);


--
-- TOC entry 4793 (class 2606 OID 17139)
-- Name: daily_usage daily_usage_house_id_request_type_request_date_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.daily_usage
    ADD CONSTRAINT daily_usage_house_id_request_type_request_date_fkey FOREIGN KEY (house_id, request_type, request_date) REFERENCES public.house_service_request(house_id, request_type, request_date);


--
-- TOC entry 4803 (class 2606 OID 17259)
-- Name: edge_in_path edge_in_path_end_station_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.edge_in_path
    ADD CONSTRAINT edge_in_path_end_station_fkey FOREIGN KEY (end_station) REFERENCES public.station(station_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4804 (class 2606 OID 17249)
-- Name: edge_in_path edge_in_path_path_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.edge_in_path
    ADD CONSTRAINT edge_in_path_path_id_fkey FOREIGN KEY (path_id) REFERENCES public.path(path_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4805 (class 2606 OID 17254)
-- Name: edge_in_path edge_in_path_start_station_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.edge_in_path
    ADD CONSTRAINT edge_in_path_start_station_fkey FOREIGN KEY (start_station) REFERENCES public.station(station_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4791 (class 2606 OID 17128)
-- Name: house_bill house_bill_to_account_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.house_bill
    ADD CONSTRAINT house_bill_to_account_fkey FOREIGN KEY (to_account) REFERENCES public.account(owner);


--
-- TOC entry 4789 (class 2606 OID 17106)
-- Name: house house_owner_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.house
    ADD CONSTRAINT house_owner_fkey FOREIGN KEY (owner) REFERENCES public.citizen(national_id);


--
-- TOC entry 4790 (class 2606 OID 17118)
-- Name: house_service_request house_service_request_house_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.house_service_request
    ADD CONSTRAINT house_service_request_house_id_fkey FOREIGN KEY (house_id) REFERENCES public.house(house_id);


--
-- TOC entry 4795 (class 2606 OID 17174)
-- Name: parking_bill parking_bill_parking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parking_bill
    ADD CONSTRAINT parking_bill_parking_id_fkey FOREIGN KEY (parking_id) REFERENCES public.parking(parking_id);


--
-- TOC entry 4796 (class 2606 OID 17179)
-- Name: parking_bill parking_bill_to_account_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parking_bill
    ADD CONSTRAINT parking_bill_to_account_fkey FOREIGN KEY (to_account) REFERENCES public.account(owner) ON DELETE CASCADE;


--
-- TOC entry 4797 (class 2606 OID 17169)
-- Name: parking_bill parking_bill_vehicle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parking_bill
    ADD CONSTRAINT parking_bill_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.personal_vehicle(vehicle_id);


--
-- TOC entry 4800 (class 2606 OID 17211)
-- Name: path path_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.path
    ADD CONSTRAINT path_type_fkey FOREIGN KEY (type) REFERENCES public.network(type) ON DELETE CASCADE;


--
-- TOC entry 4794 (class 2606 OID 17154)
-- Name: personal_vehicle personal_vehicle_owner_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.personal_vehicle
    ADD CONSTRAINT personal_vehicle_owner_fkey FOREIGN KEY (owner) REFERENCES public.citizen(national_id);


--
-- TOC entry 4798 (class 2606 OID 17201)
-- Name: public_vehicle public_vehicle_driver_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.public_vehicle
    ADD CONSTRAINT public_vehicle_driver_fkey FOREIGN KEY (driver) REFERENCES public.citizen(national_id);


--
-- TOC entry 4799 (class 2606 OID 17196)
-- Name: public_vehicle public_vehicle_network_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.public_vehicle
    ADD CONSTRAINT public_vehicle_network_fkey FOREIGN KEY (network) REFERENCES public.network(type) ON DELETE CASCADE;


--
-- TOC entry 4801 (class 2606 OID 17230)
-- Name: station_path station_path_path_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.station_path
    ADD CONSTRAINT station_path_path_id_fkey FOREIGN KEY (path_id) REFERENCES public.path(path_id) ON DELETE CASCADE;


--
-- TOC entry 4802 (class 2606 OID 17235)
-- Name: station_path station_path_station_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.station_path
    ADD CONSTRAINT station_path_station_id_fkey FOREIGN KEY (station_id) REFERENCES public.station(station_id) ON DELETE CASCADE;


--
-- TOC entry 4807 (class 2606 OID 17302)
-- Name: traversed_path traversed_path_end_station_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.traversed_path
    ADD CONSTRAINT traversed_path_end_station_fkey FOREIGN KEY (end_station) REFERENCES public.station(station_id);


--
-- TOC entry 4808 (class 2606 OID 17292)
-- Name: traversed_path traversed_path_path_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.traversed_path
    ADD CONSTRAINT traversed_path_path_id_fkey FOREIGN KEY (path_id) REFERENCES public.path(path_id);


--
-- TOC entry 4809 (class 2606 OID 17297)
-- Name: traversed_path traversed_path_start_station_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.traversed_path
    ADD CONSTRAINT traversed_path_start_station_fkey FOREIGN KEY (start_station) REFERENCES public.station(station_id);


--
-- TOC entry 4810 (class 2606 OID 17287)
-- Name: traversed_path traversed_path_trip_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.traversed_path
    ADD CONSTRAINT traversed_path_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.trip(trip_id);


--
-- TOC entry 4811 (class 2606 OID 17314)
-- Name: trip_bill trip_bill_to_account_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trip_bill
    ADD CONSTRAINT trip_bill_to_account_fkey FOREIGN KEY (to_account) REFERENCES public.account(owner);


--
-- TOC entry 4812 (class 2606 OID 17319)
-- Name: trip_bill trip_bill_trip_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trip_bill
    ADD CONSTRAINT trip_bill_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES public.trip(trip_id);


--
-- TOC entry 4806 (class 2606 OID 17271)
-- Name: trip trip_vehicle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trip
    ADD CONSTRAINT trip_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.public_vehicle(vehicle_id);


-- Completed on 2023-12-18 07:39:33

--
-- PostgreSQL database dump complete
--

