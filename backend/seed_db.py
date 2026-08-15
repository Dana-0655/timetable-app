import sys
import os

# Add the backend folder to the path so we can import app.py
backend_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(backend_dir)

from app import app, db, College, Admin, Faculty, Class, Course, Semester, TimetableConfig, TimetableEntry, bcrypt

def seed():
    with app.app_context():
        # Create all tables first
        db.create_all()

        # Check if college already exists
        if College.query.first():
            print("Database already contains data. Skipping seeding.")
            return

        print("Seeding database...")

        # 1. Add College
        college = College(
            college_name="Engineering College of Technology",
            college_code="ECT2026"
        )
        db.session.add(college)
        db.session.flush()

        # 2. Add Admin Account
        admin_pw_hash = bcrypt.generate_password_hash("admin123").decode('utf-8')
        admin = Admin(
            college_id=college.college_id,
            name="Principal Admin",
            email="admin@college.edu",
            password_hash=admin_pw_hash,
            department_name="Computer Science"
        )
        db.session.add(admin)

        # 3. Add Faculty Members
        faculty_list = [
            ("Dr. John Doe", "john.doe@college.edu", "Data Structures", "faculty123"),
            ("Dr. Alice Smith", "alice.smith@college.edu", "Database Systems", "faculty123"),
            ("Prof. Bob Johnson", "bob.johnson@college.edu", "Software Engineering", "faculty123"),
            ("Dr. Emma Watson", "emma.watson@college.edu", "Artificial Intelligence", "faculty123")
        ]

        db_faculties = []
        for name, email, expertise, password in faculty_list:
            fac_pw_hash = bcrypt.generate_password_hash(password).decode('utf-8')
            fac = Faculty(
                college_id=college.college_id,
                name=name,
                email=email,
                password_hash=fac_pw_hash,
                subject_expertise=expertise
            )
            db.session.add(fac)
            db_faculties.append(fac)
        db.session.flush()

        # 4. Add Active Semester
        semester = Semester(
            college_id=college.college_id,
            semester_name="Fall 2026",
            is_active=True
        )
        db.session.add(semester)
        db.session.flush()

        # 5. Add Classes
        class_cse = Class(
            college_id=college.college_id,
            semester_id=semester.semester_id,
            year="III Year",
            section="A",
            department="Computer Science",
            cc_faculty_id=db_faculties[0].faculty_id # Dr. John Doe is CC
        )
        db.session.add(class_cse)
        db.session.flush()

        # 6. Add Courses
        courses_data = [
            ("Data Structures & Algorithms", "CS301", db_faculties[0].faculty_id),
            ("Database Management Systems", "CS302", db_faculties[1].faculty_id),
            ("Software Engineering & Agile", "CS303", db_faculties[2].faculty_id),
            ("Artificial Intelligence", "CS304", db_faculties[3].faculty_id)
        ]

        db_courses = []
        for name, code, fac_id in courses_data:
            course = Course(
                class_id=class_cse.class_id,
                course_name=name,
                course_code=code,
                faculty_id=fac_id
            )
            db.session.add(course)
            db_courses.append(course)
        db.session.flush()

        # 7. Add Timetable Config
        config = TimetableConfig(
            class_id=class_cse.class_id,
            periods_per_day=6,
            period_duration_minutes=50,
            start_time="09:00"
        )
        db.session.add(config)

        # 8. Create Timetable Entries for MON, TUE, WED, THU, FRI
        days = ["MON", "TUE", "WED", "THU", "FRI"]
        
        for day in days:
            if day in ["MON", "FRI"]:
                course_order = [db_courses[0], db_courses[1], None, db_courses[2], None, db_courses[3]]
            elif day == "TUE":
                course_order = [db_courses[1], db_courses[2], None, db_courses[3], None, db_courses[0]]
            elif day == "WED":
                course_order = [db_courses[2], db_courses[3], None, db_courses[0], None, db_courses[1]]
            else: # THU
                course_order = [db_courses[3], db_courses[0], None, db_courses[1], None, db_courses[2]]

            for period_no, course in enumerate(course_order, 1):
                is_break = course is None
                label = "Lunch" if period_no == 3 else ("Tea Break" if period_no == 5 else None)
                entry_type = "break" if is_break else "period"
                
                if period_no == 1:
                    start, end = "09:00", "09:50"
                elif period_no == 2:
                    start, end = "09:50", "10:40"
                elif period_no == 3:
                    start, end = "10:40", "11:30"
                elif period_no == 4:
                    start, end = "11:30", "12:20"
                elif period_no == 5:
                    start, end = "12:20", "12:50"
                else:
                    start, end = "12:50", "13:40"

                entry = TimetableEntry(
                    class_id=class_cse.class_id,
                    day_of_week=day,
                    period_no=period_no,
                    entry_type=entry_type,
                    label=label,
                    start_time=start,
                    end_time=end,
                    course_id=None if is_break else course.course_id,
                    status_color="normal"
                )
                db.session.add(entry)

        db.session.commit()
        print("Database successfully seeded!")
        print("\nUse the following test credentials:")
        print(f"College Code: {college.college_code}")
        print("\n--- ADMIN ACCOUNT ---")
        print(f"Email: {admin.email}")
        print("Password: admin123")
        print("\n--- FACULTY ACCOUNTS ---")
        for f in db_faculties:
            print(f"Email: {f.email} | Subject: {f.subject_expertise}")
        print("Password: faculty123")

if __name__ == "__main__":
    seed()
