from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)

app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///timetable.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

class College(db.Model):
    college_id = db.Column(db.Integer, primary_key=True)
    college_name = db.Column(db.String(150), nullable=False)
    college_code = db.Column(db.String(20), unique=True, nullable=False)
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

if __name__ == "__main__":
    app.run(debug=True)