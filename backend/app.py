import os
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import Bcrypt
from apscheduler.schedulers.background import BackgroundScheduler
from datetime import datetime, timedelta


app = Flask(__name__)

app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///timetable.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)
bcrypt = Bcrypt(app)

class College(db.Model):
    college_id = db.Column(db.Integer, primary_key=True)
    college_name = db.Column(db.String(150), nullable=False)
    college_code = db.Column(db.String(20), unique=True, nullable=False)
    created_at = db.Column(db.DateTime, server_default=db.func.now())

class Admin(db.Model):
    admin_id = db.Column(db.Integer, primary_key=True)
    college_id = db.Column(db.Integer, db.ForeignKey('college.college_id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(150), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    department_name = db.Column(db.String(100), nullable=False)
    created_at = db.Column(db.DateTime, server_default=db.func.now())

class Faculty(db.Model):
    faculty_id = db.Column(db.Integer, primary_key=True)
    college_id = db.Column(db.Integer, db.ForeignKey('college.college_id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(150), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    subject_expertise = db.Column(db.String(255), nullable=True)
    created_at = db.Column(db.DateTime, server_default=db.func.now())

class Class(db.Model):
    class_id = db.Column(db.Integer, primary_key=True)
    college_id = db.Column(db.Integer, db.ForeignKey('college.college_id'), nullable=False)
    year = db.Column(db.String(20), nullable=False)
    section = db.Column(db.String(10), nullable=False)
    department = db.Column(db.String(100), nullable=False)
    cc_faculty_id = db.Column(db.Integer, db.ForeignKey('faculty.faculty_id'), nullable=True)
    created_at = db.Column(db.DateTime, server_default=db.func.now())

class CCRequest(db.Model):
    cc_request_id = db.Column(db.Integer, primary_key=True)
    class_id = db.Column(db.Integer, db.ForeignKey('class.class_id'), nullable=False)
    faculty_id = db.Column(db.Integer, db.ForeignKey('faculty.faculty_id'), nullable=False)
    initiated_by = db.Column(db.String(20), nullable=False)  # 'faculty' or 'admin'
    status = db.Column(db.String(20), nullable=False, default='pending')  # pending/accepted/rejected
    requested_at = db.Column(db.DateTime, server_default=db.func.now())
    resolved_at = db.Column(db.DateTime, nullable=True)

class Course(db.Model):
    course_id = db.Column(db.Integer, primary_key=True)
    class_id = db.Column(db.Integer, db.ForeignKey('class.class_id'), nullable=False)
    course_name = db.Column(db.String(100), nullable=False)
    faculty_id = db.Column(db.Integer, db.ForeignKey('faculty.faculty_id'), nullable=True)
    created_at = db.Column(db.DateTime, server_default=db.func.now())

class CourseFacultyRequest(db.Model):
    cf_request_id = db.Column(db.Integer, primary_key=True)
    course_id = db.Column(db.Integer, db.ForeignKey('course.course_id'), nullable=False)
    faculty_id = db.Column(db.Integer, db.ForeignKey('faculty.faculty_id'), nullable=False)
    initiated_by = db.Column(db.String(20), nullable=False)  # 'faculty', 'cc', or 'admin'
    status = db.Column(db.String(20), nullable=False, default='pending')
    requested_at = db.Column(db.DateTime, server_default=db.func.now())
    resolved_at = db.Column(db.DateTime, nullable=True)

class TimetableConfig(db.Model):
    config_id = db.Column(db.Integer, primary_key=True)
    class_id = db.Column(db.Integer, db.ForeignKey('class.class_id'), nullable=False)
    periods_per_day = db.Column(db.Integer, nullable=False)
    period_duration_minutes = db.Column(db.Integer, nullable=False)
    start_time = db.Column(db.String(10), nullable=False)  # e.g. "09:00"

class TimetableEntry(db.Model):
    entry_id = db.Column(db.Integer, primary_key=True)
    class_id = db.Column(db.Integer, db.ForeignKey('class.class_id'), nullable=False)
    day_of_week = db.Column(db.String(10), nullable=False)  # MON, TUE, etc.
    period_no = db.Column(db.Integer, nullable=False)
    course_id = db.Column(db.Integer, db.ForeignKey('course.course_id'), nullable=True)
    status_color = db.Column(db.String(20), nullable=False, default='normal')

class Leave(db.Model):
    leave_id = db.Column(db.Integer, primary_key=True)
    faculty_id = db.Column(db.Integer, db.ForeignKey('faculty.faculty_id'), nullable=False)
    entry_id = db.Column(db.Integer, db.ForeignKey('timetable_entry.entry_id'), nullable=False)
    leave_date = db.Column(db.String(20), nullable=False)  # e.g. "2026-07-20"
    status = db.Column(db.String(20), nullable=False, default='open')  # open/pending_requests/confirmed
    confirmed_faculty_id = db.Column(db.Integer, db.ForeignKey('faculty.faculty_id'), nullable=True)
    confirmed_by_role = db.Column(db.String(20), nullable=True)  # 'faculty' or 'cc'
    created_at = db.Column(db.DateTime, server_default=db.func.now())

class CoverRequest(db.Model):
    cover_req_id = db.Column(db.Integer, primary_key=True)
    leave_id = db.Column(db.Integer, db.ForeignKey('leave.leave_id'), nullable=False)
    requesting_faculty_id = db.Column(db.Integer, db.ForeignKey('faculty.faculty_id'), nullable=False)
    status = db.Column(db.String(20), nullable=False, default='pending')
    requested_at = db.Column(db.DateTime, server_default=db.func.now())

class SwapRequest(db.Model):
    swap_id = db.Column(db.Integer, primary_key=True)
    requester_faculty_id = db.Column(db.Integer, db.ForeignKey('faculty.faculty_id'), nullable=False)
    requester_entry_id = db.Column(db.Integer, db.ForeignKey('timetable_entry.entry_id'), nullable=False)
    target_faculty_id = db.Column(db.Integer, db.ForeignKey('faculty.faculty_id'), nullable=False)
    target_entry_id = db.Column(db.Integer, db.ForeignKey('timetable_entry.entry_id'), nullable=False)
    status = db.Column(db.String(20), nullable=False, default='pending')
    rejection_reason = db.Column(db.String(255), nullable=True)
    requested_at = db.Column(db.DateTime, server_default=db.func.now())
    resolved_at = db.Column(db.DateTime, nullable=True)

class Notification(db.Model):
    notification_id = db.Column(db.Integer, primary_key=True)
    leave_id = db.Column(db.Integer, db.ForeignKey('leave.leave_id'), nullable=False)
    sent_to_faculty = db.Column(db.Boolean, default=False)
    sent_to_cc = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, server_default=db.func.now())

def check_pending_leaves():
    with app.app_context():
        pending_leaves = Leave.query.filter(Leave.status != "confirmed").all()
        print(f"[DEBUG] Scheduler ran. Found {len(pending_leaves)} pending leave(s).")

        for leave in pending_leaves:
            already_notified = Notification.query.filter_by(leave_id=leave.leave_id).first()
            if already_notified:
                print(f"[DEBUG] Leave {leave.leave_id} already notified, skipping.")
                continue

            entry = TimetableEntry.query.get(leave.entry_id)
            config = TimetableConfig.query.filter_by(class_id=entry.class_id).first()

            if not config:
                print(f"[DEBUG] No config found for class_id {entry.class_id}")
                continue

            leave_date_obj = datetime.strptime(leave.leave_date, "%Y-%m-%d")
            start_hour, start_minute = map(int, config.start_time.split(":"))
            minutes_to_add = (entry.period_no - 1) * config.period_duration_minutes
            class_datetime = leave_date_obj.replace(hour=start_hour, minute=start_minute) + timedelta(minutes=minutes_to_add)

            now = datetime.now()
            reminder_time = class_datetime - timedelta(hours=3)

            print(f"[DEBUG] now={now}, reminder_time={reminder_time}, class_datetime={class_datetime}")

            if now >= reminder_time and now < class_datetime:
                faculty = Faculty.query.get(leave.faculty_id)
                print(f"[REMINDER] Faculty {faculty.name}: You haven't assigned anyone for {entry.day_of_week} Period {entry.period_no} at {class_datetime.strftime('%H:%M')}.")
                print(f"[REMINDER TO CC] {faculty.name} is on leave and hasn't assigned a substitute for {entry.day_of_week} Period {entry.period_no}. Class starts at {class_datetime.strftime('%H:%M')}.")

                new_notification = Notification(
                    leave_id=leave.leave_id,
                    sent_to_faculty=True,
                    sent_to_cc=True
                )
                db.session.add(new_notification)
                db.session.commit()
            else:
                print(f"[DEBUG] Not in reminder window yet.")

@app.route("/")
def home():
    return "Timetable App Backend is Running!"

@app.route("/add_college", methods=["POST"])
def add_college():
    data = request.get_json()
    new_college = College(
        college_name=data["college_name"],
        college_code=data["college_code"]
    )
    db.session.add(new_college)
    db.session.commit()
    return jsonify({"message": "College added successfully!"})

@app.route("/colleges", methods=["GET"])
def get_colleges():
    all_colleges = College.query.all()
    result = []
    for c in all_colleges:
        result.append({
            "college_id": c.college_id,
            "college_name": c.college_name,
            "college_code": c.college_code
        })
    return jsonify(result)

@app.route("/register_admin", methods=["POST"])
def register_admin():
    data = request.get_json()

    college = College.query.filter_by(college_code=data["college_code"]).first()
    if not college:
        return jsonify({"error": "Invalid college code"}), 400

    existing_admin = Admin.query.filter_by(email=data["email"]).first()
    if existing_admin:
        return jsonify({"error": "Email already registered"}), 400

    hashed_pw = bcrypt.generate_password_hash(data["password"]).decode('utf-8')

    new_admin = Admin(
        college_id=college.college_id,
        name=data["name"],
        email=data["email"],
        password_hash=hashed_pw,
        department_name=data["department_name"]
    )
    db.session.add(new_admin)
    db.session.commit()

    return jsonify({"message": "Admin registered successfully!"})

@app.route("/login_admin", methods=["POST"])
def login_admin():
    data = request.get_json()

    admin = Admin.query.filter_by(email=data["email"]).first()
    if not admin:
        return jsonify({"error": "Admin not found"}), 404

    if bcrypt.check_password_hash(admin.password_hash, data["password"]):
        return jsonify({
            "message": "Login successful",
            "admin_id": admin.admin_id,
            "name": admin.name,
            "college_id": admin.college_id
        })
    else:
        return jsonify({"error": "Incorrect password"}), 401

@app.route("/register_faculty", methods=["POST"])
def register_faculty():
    data = request.get_json()

    college = College.query.filter_by(college_code=data["college_code"]).first()
    if not college:
        return jsonify({"error": "Invalid college code"}), 400

    existing_faculty = Faculty.query.filter_by(email=data["email"]).first()
    if existing_faculty:
        return jsonify({"error": "Email already registered"}), 400

    hashed_pw = bcrypt.generate_password_hash(data["password"]).decode('utf-8')

    new_faculty = Faculty(
        college_id=college.college_id,
        name=data["name"],
        email=data["email"],
        password_hash=hashed_pw,
        subject_expertise=data.get("subject_expertise", "")
    )
    db.session.add(new_faculty)
    db.session.commit()

    return jsonify({"message": "Faculty registered successfully!"})

@app.route("/login_faculty", methods=["POST"])
def login_faculty():
    data = request.get_json()

    faculty = Faculty.query.filter_by(email=data["email"]).first()
    if not faculty:
        return jsonify({"error": "Faculty not found"}), 404

    if bcrypt.check_password_hash(faculty.password_hash, data["password"]):
        return jsonify({
            "message": "Login successful",
            "faculty_id": faculty.faculty_id,
            "name": faculty.name,
            "college_id": faculty.college_id
        })
    else:
        return jsonify({"error": "Incorrect password"}), 401

@app.route("/add_class", methods=["POST"])
def add_class():
    data = request.get_json()

    admin = Admin.query.filter_by(admin_id=data["admin_id"]).first()
    if not admin:
        return jsonify({"error": "Invalid admin"}), 400

    new_class = Class(
        college_id=admin.college_id,
        year=data["year"],
        section=data["section"],
        department=data["department"]
    )
    db.session.add(new_class)
    db.session.commit()

    return jsonify({"message": "Class created successfully!", "class_id": new_class.class_id})

@app.route("/classes/<int:college_id>", methods=["GET"])
def get_classes(college_id):
    classes = Class.query.filter_by(college_id=college_id).all()
    result = []
    for c in classes:
        result.append({
            "class_id": c.class_id,
            "year": c.year,
            "section": c.section,
            "department": c.department,
            "cc_faculty_id": c.cc_faculty_id
        })
    return jsonify(result)

@app.route("/request_cc", methods=["POST"])
def request_cc():
    data = request.get_json()

    new_request = CCRequest(
        class_id=data["class_id"],
        faculty_id=data["faculty_id"],
        initiated_by="faculty",
        status="pending"
    )
    db.session.add(new_request)
    db.session.commit()

    return jsonify({"message": "CC request sent successfully!", "request_id": new_request.cc_request_id})

@app.route("/cc_requests/<int:class_id>", methods=["GET"])
def get_cc_requests(class_id):
    requests = CCRequest.query.filter_by(class_id=class_id, status="pending").all()
    result = []
    for r in requests:
        faculty = Faculty.query.get(r.faculty_id)
        result.append({
            "cc_request_id": r.cc_request_id,
            "faculty_id": r.faculty_id,
            "faculty_name": faculty.name,
            "status": r.status
        })
    return jsonify(result)

@app.route("/resolve_cc_request", methods=["POST"])
def resolve_cc_request():
    data = request.get_json()

    cc_request = CCRequest.query.get(data["cc_request_id"])
    if not cc_request:
        return jsonify({"error": "Request not found"}), 404

    if cc_request.status != "pending":
        return jsonify({"error": "This request has already been resolved"}), 400

    cc_request.status = data["decision"]  # "accepted" or "rejected"
    cc_request.resolved_at = db.func.now()

    if data["decision"] == "accepted":
        class_obj = Class.query.get(cc_request.class_id)
        class_obj.cc_faculty_id = cc_request.faculty_id

    db.session.commit()

    return jsonify({"message": f"CC request {data['decision']} successfully!"})

@app.route("/add_course", methods=["POST"])
def add_course():
    data = request.get_json()
    new_course = Course(
        class_id=data["class_id"],
        course_name=data["course_name"]
    )
    db.session.add(new_course)
    db.session.commit()
    return jsonify({"message": "Course added successfully!", "course_id": new_course.course_id})

@app.route("/request_course_faculty", methods=["POST"])
def request_course_faculty():
    data = request.get_json()
    new_request = CourseFacultyRequest(
        course_id=data["course_id"],
        faculty_id=data["faculty_id"],
        initiated_by="faculty",
        status="pending"
    )
    db.session.add(new_request)
    db.session.commit()
    return jsonify({"message": "Course faculty request sent!", "request_id": new_request.cf_request_id})

@app.route("/course_faculty_requests/<int:course_id>", methods=["GET"])
def get_course_faculty_requests(course_id):
    requests = CourseFacultyRequest.query.filter_by(course_id=course_id, status="pending").all()
    result = []
    for r in requests:
        faculty = Faculty.query.get(r.faculty_id)
        result.append({
            "cf_request_id": r.cf_request_id,
            "faculty_id": r.faculty_id,
            "faculty_name": faculty.name,
            "status": r.status
        })
    return jsonify(result)

@app.route("/resolve_course_faculty_request", methods=["POST"])
def resolve_course_faculty_request():
    data = request.get_json()
    cf_request = CourseFacultyRequest.query.get(data["cf_request_id"])

    if not cf_request:
        return jsonify({"error": "Request not found"}), 404
    if cf_request.status != "pending":
        return jsonify({"error": "This request has already been resolved"}), 400

    cf_request.status = data["decision"]
    cf_request.resolved_at = db.func.now()

    if data["decision"] == "accepted":
        course = Course.query.get(cf_request.course_id)
        course.faculty_id = cf_request.faculty_id

    db.session.commit()
    return jsonify({"message": f"Course faculty request {data['decision']} successfully!"})

@app.route("/set_timetable_config", methods=["POST"])
def set_timetable_config():
    data = request.get_json()
    new_config = TimetableConfig(
        class_id=data["class_id"],
        periods_per_day=data["periods_per_day"],
        period_duration_minutes=data["period_duration_minutes"],
        start_time=data["start_time"]
    )
    db.session.add(new_config)
    db.session.commit()
    return jsonify({"message": "Timetable config set successfully!"})

@app.route("/add_timetable_entry", methods=["POST"])
def add_timetable_entry():
    data = request.get_json()
    new_entry = TimetableEntry(
        class_id=data["class_id"],
        day_of_week=data["day_of_week"],
        period_no=data["period_no"],
        course_id=data.get("course_id")
    )
    db.session.add(new_entry)
    db.session.commit()
    return jsonify({"message": "Timetable entry added!", "entry_id": new_entry.entry_id})
    
@app.route("/timetable/<int:class_id>", methods=["GET"])
def get_timetable(class_id):
    entries = TimetableEntry.query.filter_by(class_id=class_id).all()
    result = []
    for e in entries:
        course_name = None
        faculty_name = None

        if e.course_id:
            course = Course.query.get(e.course_id)
            course_name = course.course_name
            if course.faculty_id:
                faculty = Faculty.query.get(course.faculty_id)
                faculty_name = faculty.name
        # Check if this slot has a CONFIRMED leave/substitution
        if course_name:  # only apply substitute override if a course exists in this slot
            confirmed_leave = Leave.query.filter_by(entry_id=e.entry_id, status="confirmed").first()
            if confirmed_leave and confirmed_leave.confirmed_faculty_id:
                substitute = Faculty.query.get(confirmed_leave.confirmed_faculty_id)
                faculty_name = substitute.name
        result.append({
            "entry_id": e.entry_id,
            "day_of_week": e.day_of_week,
            "period_no": e.period_no,
            "course_name": course_name,
            "faculty_name": faculty_name,
            "status_color": e.status_color
        })
    return jsonify(result)

@app.route("/verify_college_code/<string:code>", methods=["GET"])
def verify_college_code(code):
    college = College.query.filter_by(college_code=code).first()
    if not college:
        return jsonify({"error": "Invalid college code"}), 404

    return jsonify({
        "college_id": college.college_id,
        "college_name": college.college_name
    })

@app.route("/departments/<int:college_id>", methods=["GET"])
def get_departments(college_id):
    classes = Class.query.filter_by(college_id=college_id).all()
    departments = list(set([c.department for c in classes]))
    return jsonify(departments)

@app.route("/classes_by_department/<int:college_id>/<string:department>", methods=["GET"])
def get_classes_by_department(college_id, department):
    classes = Class.query.filter_by(college_id=college_id, department=department).all()
    result = []
    for c in classes:
        result.append({
            "class_id": c.class_id,
            "year": c.year,
            "section": c.section
        })
    return jsonify(result)

@app.route("/mark_leave", methods=["POST"])
def mark_leave():
    data = request.get_json()

    new_leave = Leave(
        faculty_id=data["faculty_id"],
        entry_id=data["entry_id"],
        leave_date=data["leave_date"]
    )
    db.session.add(new_leave)
    db.session.commit()

    # Highlight the slot as "open" in the timetable
    entry = TimetableEntry.query.get(data["entry_id"])
    entry.status_color = "open_leave"
    db.session.commit()

    return jsonify({"message": "Leave marked and slot highlighted!", "leave_id": new_leave.leave_id})

@app.route("/send_cover_request", methods=["POST"])
def send_cover_request():
    data = request.get_json()

    new_cover_req = CoverRequest(
        leave_id=data["leave_id"],
        requesting_faculty_id=data["requesting_faculty_id"]
    )
    db.session.add(new_cover_req)
    db.session.commit()

    # Update leave status to show requests are coming in
    leave = Leave.query.get(data["leave_id"])
    leave.status = "pending_requests"
    db.session.commit()

    return jsonify({"message": "Cover request sent!", "cover_req_id": new_cover_req.cover_req_id})

@app.route("/cover_requests/<int:leave_id>", methods=["GET"])
def get_cover_requests(leave_id):
    requests = CoverRequest.query.filter_by(leave_id=leave_id, status="pending").all()
    result = []
    for r in requests:
        faculty = Faculty.query.get(r.requesting_faculty_id)
        result.append({
            "cover_req_id": r.cover_req_id,
            "requesting_faculty_id": r.requesting_faculty_id,
            "faculty_name": faculty.name
        })
    return jsonify(result)

@app.route("/confirm_cover_request", methods=["POST"])
def confirm_cover_request():
    data = request.get_json()

    leave = Leave.query.get(data["leave_id"])
    if not leave:
        return jsonify({"error": "Leave not found"}), 404
    if leave.status == "confirmed":
        return jsonify({"error": "This leave slot is already confirmed"}), 400

    chosen_request = CoverRequest.query.get(data["cover_req_id"])
    chosen_request.status = "accepted"

    # Reject all other pending requests for this same leave
    other_requests = CoverRequest.query.filter(
        CoverRequest.leave_id == data["leave_id"],
        CoverRequest.cover_req_id != data["cover_req_id"]
    ).all()
    for r in other_requests:
        r.status = "rejected"

    # Update the Leave record
    leave.status = "confirmed"
    leave.confirmed_faculty_id = chosen_request.requesting_faculty_id
    leave.confirmed_by_role = data["confirmed_by_role"]  # 'faculty' or 'cc'

    # Update the timetable entry: assign substitute + change color
    entry = TimetableEntry.query.get(leave.entry_id)
    entry.status_color = "confirmed_cover"

    db.session.commit()

    return jsonify({"message": "Cover request confirmed successfully!"})

@app.route("/send_swap_request", methods=["POST"])
def send_swap_request():
    data = request.get_json()

    new_swap = SwapRequest(
        requester_faculty_id=data["requester_faculty_id"],
        requester_entry_id=data["requester_entry_id"],
        target_faculty_id=data["target_faculty_id"],
        target_entry_id=data["target_entry_id"]
    )
    db.session.add(new_swap)
    db.session.commit()

    return jsonify({"message": "Swap request sent!", "swap_id": new_swap.swap_id})

@app.route("/swap_requests/<int:target_faculty_id>", methods=["GET"])
def get_swap_requests(target_faculty_id):
    requests = SwapRequest.query.filter_by(target_faculty_id=target_faculty_id, status="pending").all()
    result = []
    for r in requests:
        requester = Faculty.query.get(r.requester_faculty_id)
        requester_entry = TimetableEntry.query.get(r.requester_entry_id)
        target_entry = TimetableEntry.query.get(r.target_entry_id)
        result.append({
            "swap_id": r.swap_id,
            "requester_name": requester.name,
            "requester_slot": f"{requester_entry.day_of_week} Period {requester_entry.period_no}",
            "target_slot": f"{target_entry.day_of_week} Period {target_entry.period_no}"
        })
    return jsonify(result)

@app.route("/resolve_swap_request", methods=["POST"])
def resolve_swap_request():
    data = request.get_json()

    swap = SwapRequest.query.get(data["swap_id"])
    if not swap:
        return jsonify({"error": "Swap request not found"}), 404
    if swap.status != "pending":
        return jsonify({"error": "This request has already been resolved"}), 400

    swap.status = data["decision"]
    swap.resolved_at = db.func.now()
    swap.rejection_reason = data.get("rejection_reason", "")

    if data["decision"] == "accepted":
        requester_entry = TimetableEntry.query.get(swap.requester_entry_id)
        target_entry = TimetableEntry.query.get(swap.target_entry_id)

        # Swap the courses between the two slots
        requester_entry.course_id, target_entry.course_id = target_entry.course_id, requester_entry.course_id
        requester_entry.status_color = "swapped"
        target_entry.status_color = "swapped"

    db.session.commit()

    return jsonify({"message": f"Swap request {data['decision']} successfully!"})

@app.route("/mark_day_leave", methods=["POST"])
def mark_day_leave():
    data = request.get_json()
    faculty_id = data["faculty_id"]
    leave_date = data["leave_date"]
    day_of_week = data["day_of_week"]  # e.g. "MON"

    # Find all timetable entries where this faculty teaches, on that day
    entries = db.session.query(TimetableEntry).join(Course).filter(
        Course.faculty_id == faculty_id,
        TimetableEntry.day_of_week == day_of_week
    ).all()

    if not entries:
        return jsonify({"message": "No classes found for this faculty on that day"}), 200

    created_leaves = []
    for entry in entries:
        new_leave = Leave(
            faculty_id=faculty_id,
            entry_id=entry.entry_id,
            leave_date=leave_date
        )
        db.session.add(new_leave)
        entry.status_color = "open_leave"
        created_leaves.append(entry.entry_id)

    db.session.commit()

    return jsonify({
        "message": f"Leave marked for {len(created_leaves)} period(s)",
        "affected_entries": created_leaves
    })

if os.environ.get('WERKZEUG_RUN_MAIN') == 'true' or not app.debug:
    scheduler = BackgroundScheduler()
    scheduler.add_job(check_pending_leaves, 'interval', minutes=1)
    scheduler.start()
    
if __name__ == "__main__":
    app.run(debug=True)