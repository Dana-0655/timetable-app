-- MySQL dump 10.13  Distrib 8.0.45, for Win64 (x86_64)
--
-- Host: localhost    Database: timetable_db
-- ------------------------------------------------------
-- Server version	8.0.45

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `admin`
--

DROP TABLE IF EXISTS `admin`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `admin` (
  `admin_id` int NOT NULL AUTO_INCREMENT,
  `college_id` int NOT NULL,
  `name` varchar(100) NOT NULL,
  `email` varchar(150) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `department_name` varchar(100) NOT NULL,
  `created_at` datetime DEFAULT (now()),
  PRIMARY KEY (`admin_id`),
  UNIQUE KEY `email` (`email`),
  KEY `college_id` (`college_id`),
  CONSTRAINT `admin_ibfk_1` FOREIGN KEY (`college_id`) REFERENCES `college` (`college_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `admin`
--

LOCK TABLES `admin` WRITE;
/*!40000 ALTER TABLE `admin` DISABLE KEYS */;
INSERT INTO `admin` VALUES (1,1,'Saravanan HOD','saravanan.hod@abc.edu','$2b$12$2nyAa9BbnY4iWHvKQpQhOOXp0v3ei6T1t7.DHp/O7yeK5Xpy2pN2G','AIML','2026-08-05 08:10:44'),(2,2,'saravanan','saravanan@gmail.com','$2b$12$WyxWgJf7tR3.sJu8/gc7zuXF3UJX/F5lmzUz2hGxyfMIaMl1q4wqK','AIML','2026-08-05 08:49:11');
/*!40000 ALTER TABLE `admin` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `cc_request`
--

DROP TABLE IF EXISTS `cc_request`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cc_request` (
  `cc_request_id` int NOT NULL AUTO_INCREMENT,
  `class_id` int NOT NULL,
  `faculty_id` int NOT NULL,
  `initiated_by` varchar(20) NOT NULL,
  `status` varchar(20) NOT NULL,
  `requested_at` datetime DEFAULT (now()),
  `resolved_at` datetime DEFAULT NULL,
  PRIMARY KEY (`cc_request_id`),
  KEY `class_id` (`class_id`),
  KEY `faculty_id` (`faculty_id`),
  CONSTRAINT `cc_request_ibfk_1` FOREIGN KEY (`class_id`) REFERENCES `class` (`class_id`),
  CONSTRAINT `cc_request_ibfk_2` FOREIGN KEY (`faculty_id`) REFERENCES `faculty` (`faculty_id`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cc_request`
--

LOCK TABLES `cc_request` WRITE;
/*!40000 ALTER TABLE `cc_request` DISABLE KEYS */;
INSERT INTO `cc_request` VALUES (1,4,2,'admin','pending','2026-08-05 15:01:16',NULL),(2,4,2,'faculty','pending','2026-08-05 15:02:25',NULL),(3,4,2,'admin','pending','2026-08-06 13:42:08',NULL),(4,5,2,'faculty','accepted','2026-08-06 13:44:41','2026-08-06 13:47:04'),(5,6,2,'faculty','pending','2026-08-06 13:44:45',NULL),(6,6,2,'faculty','pending','2026-08-06 13:44:46',NULL),(7,5,2,'admin','pending','2026-08-06 13:46:57',NULL),(8,6,3,'admin','pending','2026-08-09 18:12:36',NULL),(9,6,3,'admin','pending','2026-08-09 18:12:39',NULL),(10,6,3,'admin','pending','2026-08-09 21:46:46',NULL),(11,6,3,'admin','accepted','2026-08-09 22:42:07','2026-08-09 22:42:47'),(12,6,4,'admin','accepted','2026-08-09 22:42:14','2026-08-15 15:04:55');
/*!40000 ALTER TABLE `cc_request` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `class`
--

DROP TABLE IF EXISTS `class`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `class` (
  `class_id` int NOT NULL AUTO_INCREMENT,
  `college_id` int NOT NULL,
  `semester_id` int DEFAULT NULL,
  `year` varchar(20) NOT NULL,
  `section` varchar(10) NOT NULL,
  `department` varchar(100) NOT NULL,
  `cc_faculty_id` int DEFAULT NULL,
  `created_at` datetime DEFAULT (now()),
  PRIMARY KEY (`class_id`),
  KEY `college_id` (`college_id`),
  KEY `semester_id` (`semester_id`),
  KEY `cc_faculty_id` (`cc_faculty_id`),
  CONSTRAINT `class_ibfk_1` FOREIGN KEY (`college_id`) REFERENCES `college` (`college_id`),
  CONSTRAINT `class_ibfk_2` FOREIGN KEY (`semester_id`) REFERENCES `semester` (`semester_id`),
  CONSTRAINT `class_ibfk_3` FOREIGN KEY (`cc_faculty_id`) REFERENCES `faculty` (`faculty_id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `class`
--

LOCK TABLES `class` WRITE;
/*!40000 ALTER TABLE `class` DISABLE KEYS */;
INSERT INTO `class` VALUES (1,1,1,'2nd','A','AIML',NULL,'2026-08-05 08:40:52'),(3,2,NULL,'2nd','A','AIML',NULL,'2026-08-05 13:43:51'),(4,2,2,'2nd','A','AIML',NULL,'2026-08-05 14:44:07'),(5,2,3,'2nd','A','AIML',2,'2026-08-05 14:44:54'),(6,2,3,'2nd','A','CSE',4,'2026-08-05 14:45:14'),(8,3,4,'3rd Year','A','Computer Science',9,'2026-08-15 13:58:31'),(9,2,3,'3rd Year','A','CSE',15,'2026-08-15 15:14:44');
/*!40000 ALTER TABLE `class` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `college`
--

DROP TABLE IF EXISTS `college`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `college` (
  `college_id` int NOT NULL AUTO_INCREMENT,
  `college_name` varchar(150) NOT NULL,
  `college_code` varchar(20) NOT NULL,
  `created_at` datetime DEFAULT (now()),
  PRIMARY KEY (`college_id`),
  UNIQUE KEY `college_code` (`college_code`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `college`
--

LOCK TABLES `college` WRITE;
/*!40000 ALTER TABLE `college` DISABLE KEYS */;
INSERT INTO `college` VALUES (1,'ABC Engineering College','ABC123','2026-08-05 08:10:16'),(2,'ABC COLLEGE','ABC1234','2026-08-05 08:49:10'),(3,'Test Tech','TT2026','2026-08-15 13:58:31');
/*!40000 ALTER TABLE `college` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `course`
--

DROP TABLE IF EXISTS `course`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `course` (
  `course_id` int NOT NULL AUTO_INCREMENT,
  `class_id` int NOT NULL,
  `course_name` varchar(100) NOT NULL,
  `course_code` varchar(30) DEFAULT NULL,
  `faculty_id` int DEFAULT NULL,
  `created_at` datetime DEFAULT (now()),
  PRIMARY KEY (`course_id`),
  UNIQUE KEY `unique_course_per_class` (`class_id`,`course_name`),
  KEY `faculty_id` (`faculty_id`),
  CONSTRAINT `course_ibfk_1` FOREIGN KEY (`class_id`) REFERENCES `class` (`class_id`),
  CONSTRAINT `course_ibfk_2` FOREIGN KEY (`faculty_id`) REFERENCES `faculty` (`faculty_id`)
) ENGINE=InnoDB AUTO_INCREMENT=64 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `course`
--

LOCK TABLES `course` WRITE;
/*!40000 ALTER TABLE `course` DISABLE KEYS */;
INSERT INTO `course` VALUES (1,3,'maths','',NULL,'2026-08-05 13:44:59'),(2,4,'DSA','',NULL,'2026-08-06 13:40:49'),(18,5,'SOFTWARE ENGINEERING','',NULL,'2026-08-09 12:37:27'),(19,5,'MACHINE LEARNING','',NULL,'2026-08-09 12:37:58'),(20,5,'COUNSELLING','',NULL,'2026-08-09 12:39:42'),(21,5,'APTITUDE','',NULL,'2026-08-09 12:40:11'),(22,5,'LIBRARY','',NULL,'2026-08-09 12:40:56'),(23,5,'AGILE','',NULL,'2026-08-09 12:41:32'),(24,5,'NPTEL','',NULL,'2026-08-09 12:42:15'),(25,5,'TOC','',NULL,'2026-08-09 12:43:09'),(26,5,'COMPUTER NETWORKS','',NULL,'2026-08-09 12:45:02'),(27,5,'SE LAB','',NULL,'2026-08-09 12:45:50'),(28,8,'Data Structures','CS301',9,'2026-08-15 13:58:31'),(29,8,'Database Systems','CS302',10,'2026-08-15 13:58:31'),(30,8,'VLSI Design','EC301',11,'2026-08-15 13:58:31'),(31,8,'AI Systems','CS304',12,'2026-08-15 13:58:31'),(48,9,'Computer Networks *CN*','U23CS501',13,'2026-08-15 15:31:07'),(49,9,'Software Engineering *SE*','U23CSD502',14,'2026-08-15 15:31:07'),(50,9,'Theory of Computation *TOC*','U23CS503',15,'2026-08-15 15:31:07'),(51,9,'Machine Learning *ML*','U23CS504',16,'2026-08-15 15:31:07'),(52,9,'Design & Implementation of HCI (NPTEL) *NPTEL*','noc26_cs177',15,'2026-08-15 15:31:07'),(53,9,'Agile Methodologies *AGILE*','U23CS903',17,'2026-08-15 15:31:07'),(54,9,'Machine Learning Lab (E.F. Codd Lab) *ML LAB*','U23AML501',16,'2026-08-15 15:31:07'),(55,9,'Software Development Lab (SteveJobs Lab) *SD LAB*','U23CSD504',14,'2026-08-15 15:31:07'),(56,9,'Soft Skills and Aptitude (Aptitude) *APTI*','U23GE501_APTI',18,'2026-08-15 15:31:07'),(57,9,'Soft Skills and Aptitude (Soft Skills) *SS*','U23GE501_SS',19,'2026-08-15 15:31:07'),(58,9,'Soft Skills and Aptitude (Verbal) *VERBAL*','U23GE501_VERBAL',20,'2026-08-15 15:31:07'),(59,9,'Security in Computing (Honors) *H-SC*','U23CS2025',21,'2026-08-15 15:31:07'),(60,9,'Cyber Forensics (Honors) *H-CF*','U23CS2026',22,'2026-08-15 15:31:07'),(61,9,'Library *LIB*','GEN_LIB',15,'2026-08-15 15:31:07'),(62,9,'Seminar *SEM*','GEN_SEM',15,'2026-08-15 15:31:07'),(63,9,'Counseling *COUN*','GEN_COUN',15,'2026-08-15 15:31:07');
/*!40000 ALTER TABLE `course` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `course_faculty_request`
--

DROP TABLE IF EXISTS `course_faculty_request`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `course_faculty_request` (
  `cf_request_id` int NOT NULL AUTO_INCREMENT,
  `course_id` int NOT NULL,
  `faculty_id` int NOT NULL,
  `initiated_by` varchar(20) NOT NULL,
  `status` varchar(20) NOT NULL,
  `requested_at` datetime DEFAULT (now()),
  `resolved_at` datetime DEFAULT NULL,
  PRIMARY KEY (`cf_request_id`),
  KEY `course_id` (`course_id`),
  KEY `faculty_id` (`faculty_id`),
  CONSTRAINT `course_faculty_request_ibfk_1` FOREIGN KEY (`course_id`) REFERENCES `course` (`course_id`),
  CONSTRAINT `course_faculty_request_ibfk_2` FOREIGN KEY (`faculty_id`) REFERENCES `faculty` (`faculty_id`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `course_faculty_request`
--

LOCK TABLES `course_faculty_request` WRITE;
/*!40000 ALTER TABLE `course_faculty_request` DISABLE KEYS */;
INSERT INTO `course_faculty_request` VALUES (1,26,3,'admin','pending','2026-08-09 13:28:01',NULL),(2,18,4,'admin','pending','2026-08-09 13:28:07',NULL),(3,19,6,'admin','pending','2026-08-09 13:28:12',NULL),(4,21,5,'admin','pending','2026-08-09 13:28:15',NULL),(5,23,7,'admin','pending','2026-08-09 13:28:19',NULL),(6,25,8,'admin','pending','2026-08-09 13:28:24',NULL),(7,27,4,'admin','pending','2026-08-09 13:28:41',NULL),(8,26,3,'admin','pending','2026-08-09 18:12:46',NULL),(9,18,4,'admin','pending','2026-08-09 18:12:49',NULL),(10,19,5,'admin','pending','2026-08-09 18:12:54',NULL),(11,21,6,'admin','pending','2026-08-09 18:12:58',NULL),(12,23,7,'admin','pending','2026-08-09 18:13:00',NULL),(13,25,8,'admin','pending','2026-08-09 18:13:06',NULL);
/*!40000 ALTER TABLE `course_faculty_request` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `cover_request`
--

DROP TABLE IF EXISTS `cover_request`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cover_request` (
  `cover_req_id` int NOT NULL AUTO_INCREMENT,
  `leave_id` int NOT NULL,
  `requesting_faculty_id` int NOT NULL,
  `status` varchar(20) NOT NULL,
  `requested_at` datetime DEFAULT (now()),
  PRIMARY KEY (`cover_req_id`),
  KEY `leave_id` (`leave_id`),
  KEY `requesting_faculty_id` (`requesting_faculty_id`),
  CONSTRAINT `cover_request_ibfk_1` FOREIGN KEY (`leave_id`) REFERENCES `leave` (`leave_id`),
  CONSTRAINT `cover_request_ibfk_2` FOREIGN KEY (`requesting_faculty_id`) REFERENCES `faculty` (`faculty_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cover_request`
--

LOCK TABLES `cover_request` WRITE;
/*!40000 ALTER TABLE `cover_request` DISABLE KEYS */;
INSERT INTO `cover_request` VALUES (1,1,10,'accepted','2026-08-15 13:58:31');
/*!40000 ALTER TABLE `cover_request` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `faculty`
--

DROP TABLE IF EXISTS `faculty`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `faculty` (
  `faculty_id` int NOT NULL AUTO_INCREMENT,
  `college_id` int NOT NULL,
  `name` varchar(100) NOT NULL,
  `email` varchar(150) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `subject_expertise` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT (now()),
  `department` varchar(100) DEFAULT '',
  `max_daily_load` int DEFAULT '4',
  PRIMARY KEY (`faculty_id`),
  UNIQUE KEY `email` (`email`),
  KEY `college_id` (`college_id`),
  CONSTRAINT `faculty_ibfk_1` FOREIGN KEY (`college_id`) REFERENCES `college` (`college_id`)
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `faculty`
--

LOCK TABLES `faculty` WRITE;
/*!40000 ALTER TABLE `faculty` DISABLE KEYS */;
INSERT INTO `faculty` VALUES (1,1,'Priya Faculty','priya.faculty@abc.edu','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','Physics','2026-08-05 08:11:18','',4),(2,2,'john','john@gmail.com','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','social','2026-08-05 13:36:10','',4),(3,2,'hari','hari@gmail.com','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','','2026-08-09 13:14:57','',4),(4,2,'jox','jox@gmail.com','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','','2026-08-09 13:15:16','',4),(5,2,'ajay','ajay@gmail.com','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','','2026-08-09 13:15:34','',4),(6,2,'ram','ram@gmail.com','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','','2026-08-09 13:15:55','',4),(7,2,'zayn','zayn@gmail.com','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','','2026-08-09 13:16:16','',4),(8,2,'william','william@gmail.com','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','','2026-08-09 13:16:44','',4),(9,3,'Dr. John (CSE)','john@test.com','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','Data Structures','2026-08-15 13:58:31','Computer Science',4),(10,3,'Dr. Alice (CSE Teaches Class)','alice@test.com','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','DBMS','2026-08-15 13:58:31','Computer Science',4),(11,3,'Prof. Bob (ECE)','bob@test.com','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','VLSI','2026-08-15 13:58:31','ECE',4),(12,3,'Dr. Emma (CSE Overloaded)','emma@test.com','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','AI','2026-08-15 13:58:31','Computer Science',1),(13,2,'Dr.P.Thiyagarajan','thiyagarajan@abc.edu','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','Computer Networks','2026-08-15 15:14:44','CSE',4),(14,2,'Mr.M.Mohammed Ibrahim','ibrahim@abc.edu','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','Software Engineering & Labs','2026-08-15 15:14:44','CSE',4),(15,2,'Dr.T.K.Revathi','revathi@abc.edu','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','Theory of Computation & HCI','2026-08-15 15:14:44','CSE',4),(16,2,'Ms.P.Bhuvaneswari','bhuvaneswari@abc.edu','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','Machine Learning & Labs','2026-08-15 15:14:44','CSE',4),(17,2,'Dr.D.Vidyabharathi','vidyabharathi@abc.edu','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','Agile Methodologies','2026-08-15 15:14:44','CSE',4),(18,2,'Mr.C.Mohankumar','mohankumar@abc.edu','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','Aptitude','2026-08-15 15:14:44','Training',4),(19,2,'Mr.D.S.Mohanram','mohanram@abc.edu','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','Soft Skills','2026-08-15 15:14:44','Training',4),(20,2,'Ms.T.S.Dhaayasre','dhaayasre@abc.edu','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','Verbal Skills','2026-08-15 15:14:44','Training',4),(21,2,'Dr.D.Balamurugan','balamurugan@abc.edu','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','Security in Computing','2026-08-15 15:14:44','CSE',4),(22,2,'Dr.A.Prithiviraj','prithiviraj@abc.edu','$2b$12$yR8ZLpDEbnXad.dpIPWIIuUQLtM9U2ZYkm6iB26CAZyijD1F5tBPa','Cyber Forensics','2026-08-15 15:14:44','CSE',4);
/*!40000 ALTER TABLE `faculty` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `leave`
--

DROP TABLE IF EXISTS `leave`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `leave` (
  `leave_id` int NOT NULL AUTO_INCREMENT,
  `faculty_id` int NOT NULL,
  `entry_id` int NOT NULL,
  `leave_date` varchar(20) NOT NULL,
  `status` varchar(20) NOT NULL,
  `confirmed_faculty_id` int DEFAULT NULL,
  `confirmed_by_role` varchar(20) DEFAULT NULL,
  `created_at` datetime DEFAULT (now()),
  PRIMARY KEY (`leave_id`),
  KEY `faculty_id` (`faculty_id`),
  KEY `entry_id` (`entry_id`),
  KEY `confirmed_faculty_id` (`confirmed_faculty_id`),
  CONSTRAINT `leave_ibfk_1` FOREIGN KEY (`faculty_id`) REFERENCES `faculty` (`faculty_id`),
  CONSTRAINT `leave_ibfk_2` FOREIGN KEY (`entry_id`) REFERENCES `timetable_entry` (`entry_id`),
  CONSTRAINT `leave_ibfk_3` FOREIGN KEY (`confirmed_faculty_id`) REFERENCES `faculty` (`faculty_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `leave`
--

LOCK TABLES `leave` WRITE;
/*!40000 ALTER TABLE `leave` DISABLE KEYS */;
INSERT INTO `leave` VALUES (1,9,126,'2026-08-17','confirmed',10,'admin','2026-08-15 13:58:31');
/*!40000 ALTER TABLE `leave` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notification`
--

DROP TABLE IF EXISTS `notification`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notification` (
  `notification_id` int NOT NULL AUTO_INCREMENT,
  `leave_id` int NOT NULL,
  `sent_to_faculty` tinyint(1) DEFAULT NULL,
  `sent_to_cc` tinyint(1) DEFAULT NULL,
  `created_at` datetime DEFAULT (now()),
  PRIMARY KEY (`notification_id`),
  KEY `leave_id` (`leave_id`),
  CONSTRAINT `notification_ibfk_1` FOREIGN KEY (`leave_id`) REFERENCES `leave` (`leave_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notification`
--

LOCK TABLES `notification` WRITE;
/*!40000 ALTER TABLE `notification` DISABLE KEYS */;
/*!40000 ALTER TABLE `notification` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `semester`
--

DROP TABLE IF EXISTS `semester`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `semester` (
  `semester_id` int NOT NULL AUTO_INCREMENT,
  `college_id` int NOT NULL,
  `semester_name` varchar(50) NOT NULL,
  `is_active` tinyint(1) DEFAULT NULL,
  `is_deleted` tinyint(1) DEFAULT NULL,
  `created_at` datetime DEFAULT (now()),
  PRIMARY KEY (`semester_id`),
  KEY `college_id` (`college_id`),
  CONSTRAINT `semester_ibfk_1` FOREIGN KEY (`college_id`) REFERENCES `college` (`college_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `semester`
--

LOCK TABLES `semester` WRITE;
/*!40000 ALTER TABLE `semester` DISABLE KEYS */;
INSERT INTO `semester` VALUES (1,1,'3rd year odd semester',1,0,'2026-08-05 08:40:33'),(2,2,'ODD SEM',0,0,'2026-08-05 14:37:05'),(3,2,'EVEN SEM',1,0,'2026-08-05 14:37:18'),(4,3,'Fall 2026',1,0,'2026-08-15 13:58:31');
/*!40000 ALTER TABLE `semester` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `swap_request`
--

DROP TABLE IF EXISTS `swap_request`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `swap_request` (
  `swap_id` int NOT NULL AUTO_INCREMENT,
  `requester_faculty_id` int NOT NULL,
  `requester_entry_id` int NOT NULL,
  `target_faculty_id` int NOT NULL,
  `target_entry_id` int NOT NULL,
  `status` varchar(20) NOT NULL,
  `rejection_reason` varchar(255) DEFAULT NULL,
  `requested_at` datetime DEFAULT (now()),
  `resolved_at` datetime DEFAULT NULL,
  PRIMARY KEY (`swap_id`),
  KEY `requester_faculty_id` (`requester_faculty_id`),
  KEY `requester_entry_id` (`requester_entry_id`),
  KEY `target_faculty_id` (`target_faculty_id`),
  KEY `target_entry_id` (`target_entry_id`),
  CONSTRAINT `swap_request_ibfk_1` FOREIGN KEY (`requester_faculty_id`) REFERENCES `faculty` (`faculty_id`),
  CONSTRAINT `swap_request_ibfk_2` FOREIGN KEY (`requester_entry_id`) REFERENCES `timetable_entry` (`entry_id`),
  CONSTRAINT `swap_request_ibfk_3` FOREIGN KEY (`target_faculty_id`) REFERENCES `faculty` (`faculty_id`),
  CONSTRAINT `swap_request_ibfk_4` FOREIGN KEY (`target_entry_id`) REFERENCES `timetable_entry` (`entry_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `swap_request`
--

LOCK TABLES `swap_request` WRITE;
/*!40000 ALTER TABLE `swap_request` DISABLE KEYS */;
/*!40000 ALTER TABLE `swap_request` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `timetable_config`
--

DROP TABLE IF EXISTS `timetable_config`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `timetable_config` (
  `config_id` int NOT NULL AUTO_INCREMENT,
  `class_id` int NOT NULL,
  `periods_per_day` int NOT NULL,
  `period_duration_minutes` int NOT NULL,
  `start_time` varchar(10) NOT NULL,
  PRIMARY KEY (`config_id`),
  KEY `class_id` (`class_id`),
  CONSTRAINT `timetable_config_ibfk_1` FOREIGN KEY (`class_id`) REFERENCES `class` (`class_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `timetable_config`
--

LOCK TABLES `timetable_config` WRITE;
/*!40000 ALTER TABLE `timetable_config` DISABLE KEYS */;
INSERT INTO `timetable_config` VALUES (1,8,6,50,'09:00'),(2,9,8,55,'09:00');
/*!40000 ALTER TABLE `timetable_config` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `timetable_entry`
--

DROP TABLE IF EXISTS `timetable_entry`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `timetable_entry` (
  `entry_id` int NOT NULL AUTO_INCREMENT,
  `class_id` int NOT NULL,
  `day_of_week` varchar(10) NOT NULL,
  `period_no` int NOT NULL,
  `entry_type` varchar(10) NOT NULL,
  `label` varchar(50) DEFAULT NULL,
  `start_time` varchar(10) DEFAULT NULL,
  `end_time` varchar(10) DEFAULT NULL,
  `course_id` int DEFAULT NULL,
  `status_color` varchar(20) NOT NULL,
  PRIMARY KEY (`entry_id`),
  KEY `class_id` (`class_id`),
  KEY `course_id` (`course_id`),
  CONSTRAINT `timetable_entry_ibfk_1` FOREIGN KEY (`class_id`) REFERENCES `class` (`class_id`),
  CONSTRAINT `timetable_entry_ibfk_2` FOREIGN KEY (`course_id`) REFERENCES `course` (`course_id`)
) ENGINE=InnoDB AUTO_INCREMENT=217 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `timetable_entry`
--

LOCK TABLES `timetable_entry` WRITE;
/*!40000 ALTER TABLE `timetable_entry` DISABLE KEYS */;
INSERT INTO `timetable_entry` VALUES (1,1,'MON',1,'period',NULL,NULL,NULL,NULL,'normal'),(2,1,'MON',2,'period',NULL,NULL,NULL,NULL,'normal'),(3,1,'MON',3,'break',NULL,NULL,NULL,NULL,'normal'),(4,1,'MON',4,'period',NULL,NULL,NULL,NULL,'normal'),(5,1,'MON',5,'period',NULL,NULL,NULL,NULL,'normal'),(6,1,'MON',6,'break',NULL,NULL,NULL,NULL,'normal'),(7,1,'MON',7,'period',NULL,NULL,NULL,NULL,'normal'),(8,1,'MON',8,'period',NULL,NULL,NULL,NULL,'normal'),(9,1,'MON',9,'break',NULL,NULL,NULL,NULL,'normal'),(10,1,'MON',10,'period',NULL,NULL,NULL,NULL,'normal'),(11,1,'MON',11,'period',NULL,NULL,NULL,NULL,'normal'),(12,3,'MON',1,'period',NULL,'09:00','09:55',1,'normal'),(13,3,'MON',2,'period',NULL,NULL,NULL,NULL,'normal'),(14,3,'MON',3,'break','INTERVAL','10:55','11:05',NULL,'normal'),(15,3,'MON',4,'period',NULL,NULL,NULL,NULL,'normal'),(16,3,'MON',5,'period',NULL,NULL,NULL,NULL,'normal'),(17,3,'MON',6,'break',NULL,NULL,NULL,NULL,'normal'),(18,3,'MON',7,'period',NULL,NULL,NULL,NULL,'normal'),(19,3,'MON',8,'period',NULL,NULL,NULL,NULL,'normal'),(20,3,'MON',9,'break',NULL,NULL,NULL,NULL,'normal'),(21,3,'MON',10,'period',NULL,NULL,NULL,NULL,'normal'),(22,3,'MON',11,'period',NULL,NULL,NULL,NULL,'normal'),(23,4,'MON',1,'period',NULL,'10:40','11:55',2,'normal'),(24,4,'MON',2,'period',NULL,NULL,NULL,NULL,'normal'),(25,4,'MON',3,'break',NULL,NULL,NULL,NULL,'normal'),(26,4,'MON',4,'period',NULL,NULL,NULL,NULL,'normal'),(27,4,'MON',5,'period',NULL,NULL,NULL,NULL,'normal'),(28,4,'MON',6,'break',NULL,NULL,NULL,NULL,'normal'),(29,4,'MON',7,'period',NULL,NULL,NULL,NULL,'normal'),(30,4,'MON',8,'period',NULL,NULL,NULL,NULL,'normal'),(31,4,'MON',9,'break',NULL,NULL,NULL,NULL,'normal'),(32,4,'MON',10,'period',NULL,NULL,NULL,NULL,'normal'),(33,4,'MON',11,'period',NULL,NULL,NULL,NULL,'normal'),(55,5,'WED',1,'period',NULL,'9:00 AM','9:55 AM',26,'normal'),(56,5,'WED',2,'period',NULL,NULL,NULL,NULL,'normal'),(57,5,'WED',3,'break',NULL,NULL,NULL,NULL,'normal'),(58,5,'WED',4,'period',NULL,NULL,NULL,NULL,'normal'),(59,5,'WED',5,'period',NULL,NULL,NULL,NULL,'normal'),(60,5,'WED',6,'break',NULL,NULL,NULL,NULL,'normal'),(61,5,'WED',7,'period',NULL,NULL,NULL,NULL,'normal'),(62,5,'WED',8,'period',NULL,NULL,NULL,NULL,'normal'),(63,5,'WED',9,'break',NULL,NULL,NULL,NULL,'normal'),(64,5,'WED',10,'period',NULL,NULL,NULL,NULL,'normal'),(65,5,'THU',1,'period',NULL,NULL,NULL,NULL,'normal'),(66,5,'THU',2,'period',NULL,NULL,NULL,NULL,'normal'),(67,5,'THU',3,'break',NULL,NULL,NULL,NULL,'normal'),(68,5,'THU',4,'period',NULL,NULL,NULL,NULL,'normal'),(69,5,'THU',5,'period',NULL,NULL,NULL,NULL,'normal'),(70,5,'THU',6,'break',NULL,NULL,NULL,NULL,'normal'),(71,5,'THU',7,'period',NULL,NULL,NULL,NULL,'normal'),(72,5,'THU',8,'period',NULL,NULL,NULL,NULL,'normal'),(73,5,'THU',9,'break',NULL,NULL,NULL,NULL,'normal'),(74,5,'THU',10,'period',NULL,NULL,NULL,NULL,'normal'),(75,5,'FRI',1,'period',NULL,NULL,NULL,NULL,'normal'),(76,5,'FRI',2,'period',NULL,NULL,NULL,NULL,'normal'),(77,5,'FRI',3,'break',NULL,NULL,NULL,NULL,'normal'),(78,5,'FRI',4,'period',NULL,NULL,NULL,NULL,'normal'),(79,5,'FRI',5,'period',NULL,NULL,NULL,NULL,'normal'),(80,5,'FRI',6,'break',NULL,NULL,NULL,NULL,'normal'),(81,5,'FRI',7,'period',NULL,NULL,NULL,NULL,'normal'),(82,5,'FRI',8,'period',NULL,NULL,NULL,NULL,'normal'),(83,5,'FRI',9,'break',NULL,NULL,NULL,NULL,'normal'),(84,5,'FRI',10,'period',NULL,NULL,NULL,NULL,'normal'),(95,5,'MON',1,'period',NULL,'09:00','09:55',18,'normal'),(96,5,'MON',2,'period',NULL,'09:55','10:50',19,'normal'),(97,5,'MON',3,'break','INTERVAL 1','10:50','11:05',NULL,'normal'),(98,5,'MON',4,'period',NULL,'11:05','12:00',20,'normal'),(99,5,'MON',5,'period',NULL,'12:00','12:55',21,'normal'),(100,5,'MON',6,'break','LUNCH','12:55','13:55',NULL,'normal'),(101,5,'MON',7,'period',NULL,'13:55','14:50',22,'normal'),(102,5,'MON',8,'period',NULL,'14:50','15:45',23,'normal'),(103,5,'MON',9,'break','INTERVAL 2','15:45','15:55',NULL,'normal'),(104,5,'MON',10,'period',NULL,'15:55','16:50',24,'normal'),(105,5,'TUE',1,'period',NULL,'09:00','09:55',25,'normal'),(106,5,'TUE',2,'period',NULL,'09:55','10:50',23,'normal'),(107,5,'TUE',3,'break','INTERVAL 1','10:50','11:05',NULL,'normal'),(108,5,'TUE',4,'period',NULL,'11:05','12:00',19,'normal'),(109,5,'TUE',5,'period',NULL,'12:00','12:55',26,'normal'),(110,5,'TUE',6,'break','LUNCH','12:55','13:55',NULL,'normal'),(111,5,'TUE',7,'period',NULL,'13:55','14:50',27,'normal'),(112,5,'TUE',8,'period',NULL,'14:50','15:45',27,'normal'),(113,5,'TUE',9,'break','INTERVAL 2','15:45','15:55',NULL,'normal'),(114,5,'TUE',10,'period',NULL,'15:55','16:50',27,'normal'),(115,5,'SAT',1,'period',NULL,NULL,NULL,NULL,'normal'),(116,5,'SAT',2,'period',NULL,NULL,NULL,NULL,'normal'),(117,5,'SAT',3,'break',NULL,NULL,NULL,NULL,'normal'),(118,5,'SAT',4,'period',NULL,NULL,NULL,NULL,'normal'),(119,5,'SAT',5,'period',NULL,NULL,NULL,NULL,'normal'),(120,5,'SAT',6,'break',NULL,NULL,NULL,NULL,'normal'),(121,5,'SAT',7,'period',NULL,NULL,NULL,NULL,'normal'),(122,5,'SAT',8,'period',NULL,NULL,NULL,NULL,'normal'),(123,5,'SAT',9,'break',NULL,NULL,NULL,NULL,'normal'),(124,5,'SAT',10,'period',NULL,NULL,NULL,NULL,'normal'),(125,5,'SAT',11,'period',NULL,NULL,NULL,NULL,'normal'),(126,8,'MON',1,'period',NULL,'09:00','09:50',28,'confirmed_cover'),(127,8,'MON',2,'period',NULL,'09:50','10:40',29,'normal'),(128,8,'MON',3,'period',NULL,'10:40','11:30',31,'normal'),(173,9,'MON',1,'period',NULL,'09:00','09:55',49,'normal'),(174,9,'MON',2,'period',NULL,'09:55','10:50',51,'normal'),(175,9,'MON',3,'period',NULL,'11:05','12:00',63,'normal'),(176,9,'MON',4,'period',NULL,'12:00','12:55',56,'normal'),(177,9,'MON',5,'period',NULL,'13:55','14:50',61,'normal'),(178,9,'MON',6,'period',NULL,'14:50','15:45',53,'normal'),(179,9,'MON',7,'period',NULL,'15:55','16:50',60,'normal'),(180,9,'MON',8,'period',NULL,'17:00','18:00',60,'normal'),(181,9,'TUE',1,'period',NULL,'09:00','09:55',50,'normal'),(182,9,'TUE',2,'period',NULL,'09:55','10:50',53,'normal'),(183,9,'TUE',3,'period',NULL,'11:05','12:00',51,'normal'),(184,9,'TUE',4,'period',NULL,'12:00','12:55',48,'normal'),(185,9,'TUE',5,'period',NULL,'13:55','14:50',55,'normal'),(186,9,'TUE',6,'period',NULL,'14:50','15:45',55,'normal'),(187,9,'TUE',7,'period',NULL,'15:55','16:50',55,'normal'),(188,9,'TUE',8,'period',NULL,'17:00','18:00',59,'normal'),(189,9,'WED',1,'period',NULL,'09:00','09:55',48,'normal'),(190,9,'WED',2,'period',NULL,'09:55','10:50',62,'normal'),(191,9,'WED',3,'period',NULL,'11:05','12:00',56,'normal'),(192,9,'WED',4,'period',NULL,'12:00','12:55',57,'normal'),(193,9,'WED',5,'period',NULL,'13:55','14:50',49,'normal'),(194,9,'WED',6,'period',NULL,'14:50','15:45',51,'normal'),(195,9,'WED',7,'period',NULL,'15:55','16:50',52,'normal'),(196,9,'THU',1,'period',NULL,'09:00','09:55',54,'normal'),(197,9,'THU',2,'period',NULL,'09:55','10:50',54,'normal'),(198,9,'THU',3,'period',NULL,'11:05','12:00',54,'normal'),(199,9,'THU',4,'period',NULL,'12:00','12:55',54,'normal'),(200,9,'THU',5,'period',NULL,'13:55','14:50',50,'normal'),(201,9,'THU',6,'period',NULL,'14:50','15:45',59,'normal'),(202,9,'THU',7,'period',NULL,'15:55','16:50',52,'normal'),(203,9,'FRI',1,'period',NULL,'09:00','09:55',53,'normal'),(204,9,'FRI',2,'period',NULL,'09:55','10:50',59,'normal'),(205,9,'FRI',3,'period',NULL,'11:05','12:00',49,'normal'),(206,9,'FRI',4,'period',NULL,'12:00','12:55',50,'normal'),(207,9,'FRI',5,'period',NULL,'13:55','14:50',48,'normal'),(208,9,'FRI',6,'period',NULL,'14:50','15:45',58,'normal'),(209,9,'FRI',7,'period',NULL,'15:55','16:50',60,'normal'),(210,9,'SAT',1,'period',NULL,'09:00','09:55',51,'normal'),(211,9,'SAT',2,'period',NULL,'09:55','10:50',50,'normal'),(212,9,'SAT',3,'period',NULL,'11:05','12:00',48,'normal'),(213,9,'SAT',4,'period',NULL,'12:00','12:55',53,'normal'),(214,9,'SAT',5,'period',NULL,'13:55','14:50',52,'normal'),(215,9,'SAT',6,'period',NULL,'14:50','15:45',49,'normal'),(216,9,'SAT',7,'period',NULL,'15:55','16:50',60,'normal');
/*!40000 ALTER TABLE `timetable_entry` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_notification`
--

DROP TABLE IF EXISTS `user_notification`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_notification` (
  `notification_id` int NOT NULL AUTO_INCREMENT,
  `recipient_type` varchar(20) NOT NULL,
  `recipient_id` int NOT NULL,
  `message` varchar(255) NOT NULL,
  `notif_type` varchar(30) NOT NULL,
  `is_read` tinyint(1) DEFAULT NULL,
  `created_at` datetime DEFAULT (now()),
  `reference_id` int DEFAULT NULL,
  PRIMARY KEY (`notification_id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_notification`
--

LOCK TABLES `user_notification` WRITE;
/*!40000 ALTER TABLE `user_notification` DISABLE KEYS */;
INSERT INTO `user_notification` VALUES (1,'faculty',3,'You\'ve been invited to be CC for 2nd - A','cc_invite',1,'2026-08-09 21:46:46',NULL),(2,'faculty',3,'You\'ve been invited to be CC for 2nd - A','cc_invite',1,'2026-08-09 22:42:07',11),(3,'faculty',4,'You\'ve been invited to be CC for 2nd - A','cc_invite',1,'2026-08-09 22:42:14',12),(4,'faculty',3,'Your CC request for 2nd - A was accepted','cc_response',0,'2026-08-09 22:42:48',NULL),(5,'faculty',10,'You are confirmed to cover MON Period 1 (3rd Year - A) on 2026-08-17','cover_confirmed',0,'2026-08-15 13:58:31',NULL),(6,'faculty',9,'Dr. Alice (CSE Teaches Class) has been assigned as your substitute for MON Period 1 (3rd Year - A) on 2026-08-17','cover_confirmed',0,'2026-08-15 13:58:31',NULL),(7,'faculty',4,'Your CC request for 2nd - A was accepted','cc_response',0,'2026-08-15 15:04:55',NULL);
/*!40000 ALTER TABLE `user_notification` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-08-15 15:31:56
