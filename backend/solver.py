import pandas as pd
from ortools.sat.python import cp_model

def generate_timetable_with_ortools(file_path):
    try:
        # 1. Read the sheets from the uploaded Excel file
        xls = pd.ExcelFile(file_path)
        
        departments_df = pd.read_excel(xls, 'Departments')
        classes_df = pd.read_excel(xls, 'Classes')
        faculty_df = pd.read_excel(xls, 'Faculty')
        courses_df = pd.read_excel(xls, 'Courses')
        allocation_df = pd.read_excel(xls, 'Faculty Allocation')
        rooms_df = pd.read_excel(xls, 'Rooms')
        time_slots_df = pd.read_excel(xls, 'Time Slots')
        fac_avail_df = pd.read_excel(xls, 'Faculty Availability')
        room_avail_df = pd.read_excel(xls, 'Room Availability')
        constraints_df = pd.read_excel(xls, 'Constraints')
        xls.close()  # Release file handle so Windows can delete the temp file

        # 2. Initialize the CP-SAT model
        model = cp_model.CpModel()

        # 3. Extract core entities
        rooms = rooms_df['Room ID'].tolist()
        
        # Time slots representation (Day, Period)
        time_slots = [(row['Day'], row['Period']) for _, row in time_slots_df.iterrows()]
        
        # Allocations (which faculty teaches which course to which class for how many hours)
        allocations = []
        for idx, row in allocation_df.iterrows():
            allocations.append({
                'id': idx,
                'faculty_id': row['Faculty ID'],
                'course_code': row['Course Code'],
                'class_id': row['Class ID'],
                'hours': int(row['Hours Per Week'])
            })

        # 4. Define Decision Variables
        # x[a_id, room, slot] = 1 if allocation a_id is scheduled in room at slot, else 0
        x = {}
        for alloc in allocations:
            a_id = alloc['id']
            for room in rooms:
                for slot in time_slots:
                    x[(a_id, room, slot)] = model.new_bool_var(f'alloc_{a_id}_room_{room}_slot_{slot}')

        # 5. Add Constraints

        # Constraint 1: Each allocation must be scheduled exactly for its required hours per week
        for alloc in allocations:
            a_id = alloc['id']
            required_hours = alloc['hours']
            model.add(
                sum(x[(a_id, room, slot)] for room in rooms for slot in time_slots) == required_hours
            )

        # Constraint 2: Room conflict - At most one allocation per room at any given time slot
        for room in rooms:
            for slot in time_slots:
                model.add(
                    sum(x[(a_id, room, slot)] for alloc in allocations for a_id in [alloc['id']]) <= 1
                )

        # Constraint 3: Faculty conflict - A faculty member cannot teach two different classes at the same time slot
        faculty_map = {f['Faculty ID']: [] for _, f in faculty_df.iterrows()}
        for alloc in allocations:
            faculty_map[alloc['faculty_id']].append(alloc['id'])

        for fac_id, a_ids in faculty_map.items():
            if not a_ids:
                continue
            for slot in time_slots:
                model.add(
                    sum(x[(a_id, room, slot)] for a_id in a_ids for room in rooms) <= 1
                )

        # Constraint 4: Class conflict - A class cannot attend two different courses at the same time slot
        class_map = {c['Class ID']: [] for _, c in classes_df.iterrows()}
        for alloc in allocations:
            class_map[alloc['class_id']].append(alloc['id'])

        for class_id, a_ids in class_map.items():
            if not a_ids:
                continue
            for slot in time_slots:
                model.add(
                    sum(x[(a_id, room, slot)] for a_id in a_ids for room in rooms) <= 1
                )

        # Constraint 5: Faculty Availability — block slots where faculty is unavailable
        for _, row in fac_avail_df.iterrows():
            avail = str(row.get('Availability', '')).strip().lower()
            if avail not in ('available', 'yes', '1', 'true'):
                fac_id = row['Faculty ID']
                day = row['Day']
                period = row['Period']
                slot = (day, period)
                if slot in time_slots and fac_id in faculty_map:
                    for a_id in faculty_map[fac_id]:
                        for room in rooms:
                            if (a_id, room, slot) in x:
                                model.add(x[(a_id, room, slot)] == 0)

        # Constraint 6: Room Availability — block slots where room is unavailable
        for _, row in room_avail_df.iterrows():
            avail = str(row.get('Availability', '')).strip().lower()
            if avail not in ('available', 'yes', '1', 'true'):
                room_id = row['Room ID']
                day = row['Day']
                period = row['Period']
                slot = (day, period)
                if slot in time_slots and room_id in rooms:
                    for alloc in allocations:
                        a_id = alloc['id']
                        if (a_id, room_id, slot) in x:
                            model.add(x[(a_id, room_id, slot)] == 0)

        # 6. Solve the Model
        solver = cp_model.CpSolver()
        solver.parameters.max_time_in_seconds = 60.0  # Time limit for optimization
        status = solver.solve(model)

        if status == cp_model.OPTIMAL or status == cp_model.FEASIBLE:
            print("Optimal Timetable Found!")
            
            scheduled_entries = []
            for alloc in allocations:
                a_id = alloc['id']
                for room in rooms:
                    for slot in time_slots:
                        if solver.value(x[(a_id, room, slot)]) == 1:
                            scheduled_entries.append({
                                'faculty_id': alloc['faculty_id'],
                                'course_code': alloc['course_code'],
                                'class_id': alloc['class_id'],
                                'room_id': room,
                                'day': slot[0],
                                'period': slot[1]
                            })
                            
            return {"status": "success", "schedule": scheduled_entries}
        elif status == cp_model.INFEASIBLE:
            return {"status": "failed", "error": "Constraints are contradictory — no valid timetable is possible with the given data. Check faculty hours, room counts, and time slots."}
        elif status == cp_model.MODEL_INVALID:
            return {"status": "failed", "error": "The solver model is invalid. Please check your uploaded Excel data for formatting issues."}
        else:
            # status == cp_model.UNKNOWN (typically means timeout)
            return {"status": "failed", "error": "Solver timed out after 60 seconds without finding a solution. Try reducing the number of allocations, rooms, or time slots."}

    except Exception as e:
        return {"status": "failed", "error": str(e)}