import sys
import os
import unittest
import json

backend_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(backend_dir)

from app import app, db, College, Admin, Faculty, Class, Course, Semester, TimetableConfig, TimetableEntry, Leave, CoverRequest, UserNotification, bcrypt

class TestSubstitutionEngine(unittest.TestCase):
    def setUp(self):
        app.config['TESTING'] = True
        app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
        self.app_ctx = app.app_context()
        self.app_ctx.push()
        self.client = app.test_client()

        # Re-bind engine for testing
        db.engine.dispose()
        db.create_all()

        # Create test college
        college = College(college_name="Test Tech", college_code="TT2026")
        db.session.add(college)
        db.session.flush()

        # Create faculty members
        pw = bcrypt.generate_password_hash("pass").decode('utf-8')
        f1 = Faculty(college_id=college.college_id, name="Dr. John (CSE)", email="john@test.com", password_hash=pw, subject_expertise="Data Structures", department="Computer Science", max_daily_load=4)
        f2 = Faculty(college_id=college.college_id, name="Dr. Alice (CSE Teaches Class)", email="alice@test.com", password_hash=pw, subject_expertise="DBMS", department="Computer Science", max_daily_load=4)
        f3 = Faculty(college_id=college.college_id, name="Prof. Bob (ECE)", email="bob@test.com", password_hash=pw, subject_expertise="VLSI", department="ECE", max_daily_load=4)
        f4 = Faculty(college_id=college.college_id, name="Dr. Emma (CSE Overloaded)", email="emma@test.com", password_hash=pw, subject_expertise="AI", department="Computer Science", max_daily_load=1)

        db.session.add_all([f1, f2, f3, f4])
        db.session.flush()

        # Create active semester
        sem = Semester(college_id=college.college_id, semester_name="Fall 2026", is_active=True)
        db.session.add(sem)
        db.session.flush()

        # Create Class
        cls = Class(college_id=college.college_id, semester_id=sem.semester_id, year="3rd Year", section="A", department="Computer Science", cc_faculty_id=f1.faculty_id)
        db.session.add(cls)
        db.session.flush()

        # Create Courses
        c1 = Course(class_id=cls.class_id, course_name="Data Structures", course_code="CS301", faculty_id=f1.faculty_id)
        c2 = Course(class_id=cls.class_id, course_name="Database Systems", course_code="CS302", faculty_id=f2.faculty_id)
        c3 = Course(class_id=cls.class_id, course_name="VLSI Design", course_code="EC301", faculty_id=f3.faculty_id)
        c4 = Course(class_id=cls.class_id, course_name="AI Systems", course_code="CS304", faculty_id=f4.faculty_id)
        db.session.add_all([c1, c2, c3, c4])
        db.session.flush()

        # Timetable config
        config = TimetableConfig(class_id=cls.class_id, periods_per_day=6, period_duration_minutes=50, start_time="09:00")
        db.session.add(config)

        # Timetable entries for MON
        e1 = TimetableEntry(class_id=cls.class_id, day_of_week="MON", period_no=1, entry_type="period", start_time="09:00", end_time="09:50", course_id=c1.course_id)
        e2 = TimetableEntry(class_id=cls.class_id, day_of_week="MON", period_no=2, entry_type="period", start_time="09:50", end_time="10:40", course_id=c2.course_id)
        e3 = TimetableEntry(class_id=cls.class_id, day_of_week="MON", period_no=3, entry_type="period", start_time="10:40", end_time="11:30", course_id=c4.course_id)
        db.session.add_all([e1, e2, e3])
        db.session.commit()

        self.f1_id = f1.faculty_id
        self.f2_id = f2.faculty_id
        self.f3_id = f3.faculty_id
        self.f4_id = f4.faculty_id
        self.e1_id = e1.entry_id

    def test_auto_substitution_engine(self):
        with app.app_context():
            # 1. Mark leave for Dr. John (f1) on e1 (MON Period 1)
            resp = self.client.post("/mark_leave", json={
                "faculty_id": self.f1_id,
                "entry_id": self.e1_id,
                "leave_date": "2026-08-17"
            })
            self.assertEqual(resp.status_code, 200)
            leave_id = resp.get_json()["leave_id"]

            # 2. Get auto-substitute suggestions
            sug_resp = self.client.get(f"/suggest_substitutes/{leave_id}")
            self.assertEqual(sug_resp.status_code, 200)
            data = sug_resp.get_json()

            self.assertIn("candidates", data)
            candidates = data["candidates"]
            self.assertGreater(len(candidates), 0)

            # Dr. Alice (f2) teaches in this class and is in CSE, so she should be rank 1
            top_cand = candidates[0]
            self.assertEqual(top_cand["faculty_id"], self.f2_id)
            self.assertTrue(top_cand["teaches_target_class"])
            self.assertTrue(top_cand["same_department"])
            self.assertEqual(top_cand["rank"], 1)

            # 3. Approve substitute (Dr. Alice f2)
            app_resp = self.client.post("/approve_substitute", json={
                "leave_id": leave_id,
                "substitute_faculty_id": self.f2_id,
                "approved_by_role": "admin"
            })
            self.assertEqual(app_resp.status_code, 200)
            self.assertIn("successfully approved", app_resp.get_json()["message"])

            # 4. Verify DB state & notification
            leave = Leave.query.get(leave_id)
            self.assertEqual(leave.status, "confirmed")
            self.assertEqual(leave.confirmed_faculty_id, self.f2_id)

            notifs = UserNotification.query.filter_by(recipient_id=self.f2_id).all()
            self.assertGreater(len(notifs), 0)
            self.assertIn("confirmed to cover", notifs[0].message)

            print("\n[SUCCESS] Auto-substitution engine test passed perfectly!")

if __name__ == "__main__":
    unittest.main()
