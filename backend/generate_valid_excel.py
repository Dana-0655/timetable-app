import pandas as pd

depts = [
    {'Department ID': 'CSE', 'Department Name': 'Computer Science and Engineering'},
    {'Department ID': 'ECE', 'Department Name': 'Electronics and Communication Engineering'},
    {'Department ID': 'EEE', 'Department Name': 'Electrical and Electronics Engineering'},
    {'Department ID': 'MECH', 'Department Name': 'Mechanical Engineering'},
    {'Department ID': 'CIVIL', 'Department Name': 'Civil Engineering'}
]

classes = []
for dept in ['CSE', 'ECE', 'EEE', 'MECH', 'CIVIL']:
    for year in range(1, 5):
        classes.append({
            'Class ID': f'{dept}-Y{year}A',
            'Academic Year': f'Year {year}',
            'Department': dept,
            'Section': 'A',
            'Semester': str(year * 2 - 1)
        })

faculty = []
fac_idx = 1
for dept in ['CSE', 'ECE', 'EEE', 'MECH', 'CIVIL']:
    for f in range(1, 6):
        fid = f'F{fac_idx:02d}'
        faculty.append({
            'Faculty ID': fid,
            'Faculty Name': f'Prof. {dept} {f}',
            'Department': dept,
            'Email': f'faculty_{fid.lower()}@college.edu'
        })
        fac_idx += 1

courses = []
allocations = []

fac_by_dept = {
    'CSE': [f'F{i:02d}' for i in range(1, 6)],
    'ECE': [f'F{i:02d}' for i in range(6, 11)],
    'EEE': [f'F{i:02d}' for i in range(11, 16)],
    'MECH': [f'F{i:02d}' for i in range(16, 21)],
    'CIVIL': [f'F{i:02d}' for i in range(21, 26)]
}

c_counter = 101
for dept in ['CSE', 'ECE', 'EEE', 'MECH', 'CIVIL']:
    dept_facs = fac_by_dept[dept]
    for year in range(1, 5):
        class_id = f'{dept}-Y{year}A'
        for course_num in range(1, 5):
            c_code = f'{dept}{c_counter}'
            c_name = f'{dept} Subject {c_counter}'
            c_counter += 1
            
            courses.append({
                'Course Code': c_code,
                'Course Name': c_name,
                'Department': dept,
                'Semester': str(year * 2 - 1),
                'Course Type': 'Theory',
                'Hours Per Week': 4,
                'Periods Per Session': 1
            })
            
            assigned_fac = dept_facs[(year + course_num) % len(dept_facs)]
            
            allocations.append({
                'Faculty ID': assigned_fac,
                'Course Code': c_code,
                'Class ID': class_id,
                'Hours Per Week': 4
            })

days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
slots = []
for d in days:
    for p in range(1, 7):
        slots.append({
            'Day': d,
            'Period': p,
            'Start Time': f'{8 + p:02d}:00',
            'End Time': f'{9 + p:02d}:00'
        })

# 15 Rooms (15 x 30 = 450 capacity for 320 hours required)
rooms = [
    {'Room ID': f'LH{i:03d}', 'Room Name': f'Lecture Hall {i}', 'Room Type': 'Lecture', 'Capacity': 60}
    for i in range(101, 116)
]

with pd.ExcelWriter('Valid_Timetable_Template.xlsx', engine='openpyxl') as writer:
    pd.DataFrame(depts).to_excel(writer, sheet_name='Departments', index=False)
    pd.DataFrame(classes).to_excel(writer, sheet_name='Classes', index=False)
    pd.DataFrame(faculty).to_excel(writer, sheet_name='Faculty', index=False)
    pd.DataFrame(courses).to_excel(writer, sheet_name='Courses', index=False)
    pd.DataFrame(allocations).to_excel(writer, sheet_name='Faculty Allocation', index=False)
    pd.DataFrame(rooms).to_excel(writer, sheet_name='Rooms', index=False)
    pd.DataFrame(slots).to_excel(writer, sheet_name='Time Slots', index=False)

print("Valid_Timetable_Template.xlsx updated with 15 rooms!")
