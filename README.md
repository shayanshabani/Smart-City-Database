# Smart City Database Project

This repository contains the **Smart City Database Project**, designed and implemented as part of the Database Design course at Sharif University of Technology under the supervision of **Dr. Morteza Amini**. The project entails creating a database for managing various services and functionalities of a smart city, progressively developed in three phases.

This documentation outlines the details of the project's requirements, implementation, and deliverables.

---

## Table of Contents

1. [Overview](#overview)  
2. [Phase 1: Initial Requirements and EER Diagram](#phase-1-initial-requirements-and-eer-diagram)  
3. [Phase 2: Database Construction and Query Design](#phase-2-database-construction-and-query-design)  
4. [Phase 3: Command-Line Interface Development](#phase-3-command-line-interface-development)  
5. [Deliverables](#deliverables)

---

## Overview

The Smart City Database Project focuses on designing and implementing a PostgreSQL database for a fictitious smart city. The project is divided into **three phases**:

- **Phase 1:** Identifying initial requirements and creating an Enhanced Entity-Relationship (EER) diagram.  
- **Phase 2:** Constructing and refining the database in PostgreSQL, including tables, queries, views, and triggers.  
- **Phase 3:** Developing a **Command-Line Interface (CLI)** using Python and the Peewee ORM for interacting with the database.

---

## Phase 1: Initial Requirements and EER Diagram

The first phase focused on gathering database requirements and organizing them into an EER diagram that served as the blueprint for the PostgreSQL schema.  

### Key Requirements:

1. **Citizen Information:**  
   Every citizen has a name, national ID, and date of birth stored.

2. **Housing Information:**  
   Houses are identified by a city-specific ID, address, and location. A house can be assigned to one citizen, but not all citizens own a house.

3. **Financial Accounts:**  
   Citizens have accounts that track their financial credits, used for conducting payments.

4. **Utility Services:**  
   Urban utility services, such as electricity, gas, and water, issue monthly bills based on a homeowner's usage.

5. **Public Transportation System:**  
   Transportation options include **metros**, **taxis**, and **buses**, each having predefined routes and stations.  
   - Citizens can board or alight at stations.  
   - Travel receipts are issued based on passenger journeys.

6. **Parking Facilities:**  
   The city hosts parking lots with details such as names, city IDs, geographic locations, capacity, hourly rates, and operating hours.

7. **Travel History Records:**  
   Each citizen’s history of travel-related activity (public transport, parking, utility services) is logged.

8. **Payment Receipts:**  
   Any payment made is recorded as a receipt with a unique code, amount due, type of service, and issuance timestamp.

The phase concluded with the creation of **EER diagrams**, defining the relationships between entities and structuring the design of the database.

---

## Phase 2: Database Construction and Query Design

In the second phase, the requirements were updated and the database was implemented in PostgreSQL, defining tables, relationships, and additional functionality.  

### Key Updates:
- **Gender Information:** Added gender details for citizens.  
- **Standardization:** Vehicle data for private and public transport was standardized.  
- **Head of Household:** Introduced the concept of a "head of household."  
- **Distance Costs:** Travel charges were replaced with distance-based metrics (e.g., cost per kilometer).  
- **Geographical Coordinates:** Replaced textual addresses with coordinates for locations.  
- **Event Logs:** Implementation of timestamps for major events like travel or payments.  
- **Utility Bills:** Bills are issued dynamically based on actual usage.

### Tables and Design:
The **EER diagrams** were translated into PostgreSQL tables, including **data types, constraints, and integrity rules**. Additional features like stored functions were implemented to simplify complex queries.

### Query Set:
A range of queries was developed, focusing on:
- Driver performance statistics.  
- Household utility cost analysis.  
- Public transport system usage.  

### Views and Triggers:
- **Views:** Created for commonly accessed information, such as lists of active drivers, station usage statistics, or citizen payment histories.  
- **Triggers:** Automated tasks like issuing payment receipts and updating user accounts in real time.  

### Backup:
A complete **SQL backup** was generated to maintain the project deliverables. A detailed report explaining tables, queries, views, and triggers was included.

---

## Phase 3: Command-Line Interface Development

The final phase involved developing a **Command-Line Interface (CLI)** in **Python**. Using the **Peewee ORM**, this interface allows seamless interaction with the PostgreSQL database for managing the smart city services.  

### Features of the CLI:

1. **Database Initialization:**  
   Automates the creation of tables and database schema.

2. **CRUD Operations:**  
   Supports the insertion, deletion, and update of data (e.g., citizens, vehicles, stations, parking facilities).

3. **Record Retrieval:**  
   - Fetch records by specific **IDs**.  
   - Search for citizens by their **names**.

4. **Account Management:**  
   Citizens can manage their financial accounts by:  
   - Adding funds (recharging credit).  
   - Tracking travel and parking expenses.

5. **Payment Receipt Management:**  
   Filter payment receipts based on type and issuance dates.

6. **Cost Analysis:**  
   Query for citizens with total expenses in user-defined ranges.

### Tools and Libraries:
- **Python**: Used to develop the CLI.  
- **Peewee ORM**: Simplifies database interactions.  
- **PostgreSQL**: A robust relational database engine.  

---

## Deliverables

This repository includes the following key files:

1. **[main.py](main.py):** The main codebase for the Python CLI.  
2. **[.env](.env):** Environment configuration for connecting to the PostgreSQL database.  
3. **[requirements.txt](requirements.txt):** Required dependencies for running the project.  
4. **`EER Diagram`:** Visual representation of the database design (in the `docs` folder).  
5. **Backup Files:** Full SQL backup files for the database available in the `backups/` directory.  

---

## How to Run the Project

Follow these steps to run the project locally:

1. **Set up PostgreSQL**:
   - Install PostgreSQL on your system.  
   - Create a database for the project.  

2. **Install Python Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

3. **Configure `.env` File**:
   Set up your database connection in the `.env` file:
   ```
   DATABASE_NAME=your_database_name
   USERNAME=your_user
   PASSWORD=your_password
   HOST=127.0.0.1
   PORT=5432
   ```

4. **Run the CLI**:
   ```bash
   python main.py
   ```

---

This repository provides a full-stack solution for managing smart city services, offering a scalable and optimized database design with user-friendly tools for interaction and expansion. For any questions or contributions, feel free to open an issue or submit a pull request!
