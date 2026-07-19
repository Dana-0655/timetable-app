from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import Bcrypt

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
        
if __name__ == "__main__":
    app.run(debug=True)