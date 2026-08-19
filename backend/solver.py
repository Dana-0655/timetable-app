import pandas as pd
from ortools.sat.python import cp_model
from collections import defaultdict

def diagnose_infeasibility_reason(allocations, time_slots, faculty_map, class_map, fac_avail_df, active_constraints, rooms=None):
    total_slots = len(time_slots)

    # 1. Faculty Total Hours & Overlap Bottleneck Check
    fac_hours = defaultdict(int)
    fac_classes = defaultdict(set)
    for alloc in allocations:
        f_id = alloc['faculty_id']
        fac_hours[f_id] += alloc['hours']
        fac_classes[f_id].add(alloc['class_id'])

    for f_id, req_h in fac_hours.items():
        if req_h > total_slots:
            return f"Faculty '{f_id}' is assigned {req_h} total hours/week, exceeding the {total_slots} available time slots in 'Time Slots'."
        num_classes = len(fac_classes[f_id])
        if num_classes >= 5 and req_h >= 18:
            return f"Faculty '{f_id}' is assigned to {num_classes} overlapping classes ({req_h} total hours/week). Teachers assigned to 5 or more class sections create self-colliding schedules across the week."

    # 2. Total Room Capacity Check
    if rooms is not None and len(rooms) > 0:
        total_req_hours = sum(alloc['hours'] for alloc in allocations)
        total_room_capacity = len(rooms) * total_slots
        if total_req_hours > total_room_capacity:
            return f"The total required class hours ({total_req_hours} hours/week across {len(class_map)} classes) exceed total room capacity ({len(rooms)} rooms × {total_slots} slots = {total_room_capacity} room-slots). Please add more rooms in the 'Rooms' sheet or reduce class hours."

    # 3. Faculty Availability Lockout Check
    if not fac_avail_df.empty:
        fac_unavail = defaultdict(int)
        for _, row in fac_avail_df.iterrows():
            avail = str(row.get('Availability', '')).strip().lower()
            if avail not in ('available', 'yes', '1', 'true'):
                f_id = str(row.get('Faculty ID', '')).strip()
                if f_id:
                    fac_unavail[f_id] += 1

        for f_id, req_h in fac_hours.items():
            unavail_count = fac_unavail.get(f_id, 0)
            avail_slots = total_slots - unavail_count
            if req_h > avail_slots:
                return f"Faculty '{f_id}' requires {req_h} teaching hours, but is marked unavailable for {unavail_count} slots out of {total_slots} total slots in 'Faculty Availability'."

    # 4. Class Total Hours Check
    class_hours = defaultdict(int)
    for alloc in allocations:
        c_id = alloc['class_id']
        class_hours[c_id] += alloc['hours']

    for c_id, req_h in class_hours.items():
        if req_h > total_slots:
            return f"Class '{c_id}' requires {req_h} total hours/week across courses, exceeding the {total_slots} available time slots in 'Time Slots'."

    return "Constraints are contradictory — no valid timetable is possible with the given data. Check faculty hours, room counts, and time slots."

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
        fac_avail_df = pd.read_excel(xls, 'Faculty Availability') if 'Faculty Availability' in xls.sheet_names else pd.DataFrame()
        room_avail_df = pd.read_excel(xls, 'Room Availability') if 'Room Availability' in xls.sheet_names else pd.DataFrame()
        constraints_df = pd.read_excel(xls, 'Constraints') if 'Constraints' in xls.sheet_names else pd.DataFrame()
        xls.close()  # Release file handle so Windows can delete the temp file

        active_constraints = pd.DataFrame()
        if not constraints_df.empty:
            if 'Enable' in constraints_df.columns:
                enabled_mask = constraints_df['Enable'].astype(str).str.strip().str.upper().isin(['TRUE', '1', 'YES'])
                active_constraints = constraints_df[enabled_mask]
            else:
                active_constraints = constraints_df

        # 2. Initialize the CP-SAT model
        model = cp_model.CpModel()

        # 3. Extract core entities
        rooms = rooms_df['Room ID'].dropna().astype(str).str.strip().tolist() if 'Room ID' in rooms_df.columns and not rooms_df.empty else []
        using_default_room = False
        if not rooms:
            rooms = ['DEFAULT_ROOM']
            using_default_room = True

        # Time slots representation (Day, Period) - Smart Extractor
        time_slots = []
        if 'Day' in time_slots_df.columns and 'Period' in time_slots_df.columns:
            for _, row in time_slots_df.iterrows():
                d = str(row.get('Day', '')).strip()
                p = row.get('Period')
                if d and pd.notna(p):
                    try:
                        time_slots.append((d, int(float(p))))
                    except:
                        pass

        # Fallback if no named headers or shifted columns
        if not time_slots:
            raw_slots_df = pd.read_excel(file_path, 'Time Slots', header=None)
            valid_days = {'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'}
            for _, row in raw_slots_df.iterrows():
                row_vals = [v for v in row if pd.notna(v)]
                found_day = None
                found_period = None
                for v in row_vals:
                    v_str = str(v).strip()
                    if v_str.lower() in valid_days and not found_day:
                        found_day = v_str.capitalize()
                    else:
                        try:
                            num = int(float(v_str))
                            if 1 <= num <= 14 and found_period is None:
                                found_period = num
                        except:
                            pass
                if found_day and found_period is not None:
                    time_slots.append((found_day, found_period))

        if not time_slots:
            return {
                "status": "failed",
                "error": "No valid time slots found in 'Time Slots' sheet. Please ensure columns for Day (e.g. Monday) and Period (e.g. 1, 2) are present."
            }
        
        # Allocations (which faculty teaches which course to which class for how many hours)
        allocations = []
        for idx, row in allocation_df.iterrows():
            if pd.notna(row.get('Faculty ID')) and pd.notna(row.get('Class ID')):
                hrs_val = row.get('Hours Per Week')
                try:
                    hrs = int(hrs_val) if pd.notna(hrs_val) else 1
                    hrs = max(1, hrs)
                except (ValueError, TypeError):
                    hrs = 1
                allocations.append({
                    'id': idx,
                    'faculty_id': str(row['Faculty ID']).strip(),
                    'course_code': str(row['Course Code']).strip(),
                    'class_id': str(row['Class ID']).strip(),
                    'hours': hrs
                })

        # --- PRE-VALIDATION DIAGNOSTICS ---
        if not time_slots:
            return {"status": "failed", "error": "No time slots found in 'Time Slots' sheet. Please add entries with 'Day' and 'Period'."}

        if not allocations:
            return {"status": "failed", "error": "No allocations found in 'Faculty Allocation' sheet."}

        total_slots = len(time_slots)

        # Check Class required hours vs total time slots
        class_hours = {}
        for alloc in allocations:
            c_id = alloc['class_id']
            class_hours[c_id] = class_hours.get(c_id, 0) + alloc['hours']

        for c_id, req_h in class_hours.items():
            if req_h > total_slots:
                return {
                    "status": "failed",
                    "error": f"Class '{c_id}' requires total {req_h} hours/week across courses, but only {total_slots} time slots exist in 'Time Slots'."
                }

        # Check Faculty required hours vs total time slots
        fac_hours = {}
        for alloc in allocations:
            f_id = alloc['faculty_id']
            fac_hours[f_id] = fac_hours.get(f_id, 0) + alloc['hours']

        for f_id, req_h in fac_hours.items():
            if req_h > total_slots:
                return {
                    "status": "failed",
                    "error": f"Faculty '{f_id}' is assigned total {req_h} teaching hours/week, but only {total_slots} time slots exist in 'Time Slots'."
                }

        # Check Faculty Availability lockouts
        fac_unavail = {}
        if not fac_avail_df.empty:
            for _, row in fac_avail_df.iterrows():
                avail = str(row.get('Availability', '')).strip().lower()
                if avail not in ('available', 'yes', '1', 'true'):
                    f_id = str(row.get('Faculty ID', '')).strip()
                    if f_id:
                        fac_unavail[f_id] = fac_unavail.get(f_id, 0) + 1

        for f_id, req_h in fac_hours.items():
            unavail_count = fac_unavail.get(f_id, 0)
            avail_slots = total_slots - unavail_count
            if req_h > avail_slots:
                return {
                    "status": "failed",
                    "error": f"Faculty '{f_id}' requires {req_h} teaching hours, but is marked unavailable for {unavail_count} slots out of {total_slots} total slots (only {avail_slots} slots available)."
                }

        # Prepare helper structures for Default Constraints
        slots_by_day = defaultdict(list)
        for (d_name, p_num) in time_slots:
            slots_by_day[d_name.lower()].append(p_num)
        for d_name in slots_by_day:
            slots_by_day[d_name].sort()

        days_list = list(set(s[0].lower() for s in time_slots))

        lab_courses = set()
        if not courses_df.empty and 'Course Type' in courses_df.columns:
            lab_courses = set(
                courses_df[courses_df['Course Type'].astype(str).str.strip().str.lower() == 'lab']['Course Code']
                .dropna().astype(str).str.strip()
            )

        # Auto-fallback: If provided room capacity is less than total required class hours, switch to 2D model
        total_req_hours = sum(alloc['hours'] for alloc in allocations)
        if rooms and rooms != ['DEFAULT_ROOM']:
            if len(rooms) * total_slots < total_req_hours:
                using_default_room = True
                rooms = ['DEFAULT_ROOM']

        if using_default_room:
            # ===== 2D MODEL: No room dimension (allocation x slot) =====
            # x[a_id, slot] = 1 if allocation a_id is scheduled at slot
            x = {}
            for alloc in allocations:
                a_id = alloc['id']
                for slot in time_slots:
                    x[(a_id, slot)] = model.new_bool_var(f'alloc_{a_id}_slot_{slot}')

            # Constraint 1: Each allocation scheduled exactly for required hours
            for alloc in allocations:
                a_id = alloc['id']
                model.add(
                    sum(x[(a_id, slot)] for slot in time_slots) == alloc['hours']
                )

            # Constraint 2: Faculty conflict - 1 faculty member can only teach 1 class per slot
            faculty_map = defaultdict(list)
            for alloc in allocations:
                faculty_map[alloc['faculty_id']].append(alloc['id'])

            for fac_id, a_ids in faculty_map.items():
                if len(a_ids) <= 1:
                    continue
                for slot in time_slots:
                    model.add(sum(x[(a_id, slot)] for a_id in a_ids) <= 1)

            # Constraint 3: Class conflict - 1 class can only attend 1 course per slot
            class_map = defaultdict(list)
            for alloc in allocations:
                class_map[alloc['class_id']].append(alloc['id'])

            for c_id, a_ids in class_map.items():
                if len(a_ids) <= 1:
                    continue
                for slot in time_slots:
                    model.add(sum(x[(a_id, slot)] for a_id in a_ids) <= 1)

            # Constraint 4: Faculty Availability
            if not fac_avail_df.empty:
                for _, row in fac_avail_df.iterrows():
                    avail = str(row.get('Availability', '')).strip().lower()
                    if avail not in ('available', 'yes', '1', 'true'):
                        fac_id = str(row.get('Faculty ID', '')).strip()
                        day = str(row.get('Day', '')).strip()
                        period = int(row.get('Period', 0))
                        slot = (day, period)
                        if slot in time_slots and fac_id in faculty_map:
                            for a_id in faculty_map[fac_id]:
                                if (a_id, slot) in x:
                                    model.add(x[(a_id, slot)] == 0)

            # ===== DEFAULT CONSTRAINTS (ALWAYS ACTIVE) =====
            # 1. Consecutive Lab Blocks: Labs with >= 2 hours must be consecutive periods on the same day

            for alloc in allocations:
                a_id = alloc['id']
                c_code = str(alloc['course_code']).strip()
                hrs = alloc['hours']
                is_lab = 'lab' in c_code.lower() or c_code in lab_courses

                if is_lab and hrs >= 2:
                    valid_starts = []
                    for d_name, p_list in slots_by_day.items():
                        for i in range(len(p_list) - hrs + 1):
                            consec_block = p_list[i : i + hrs]
                            if all(consec_block[j] == consec_block[0] + j for j in range(hrs)):
                                start_p = consec_block[0]
                                b_var = model.new_bool_var(f'lab_start_{a_id}_{d_name}_{start_p}')
                                valid_starts.append((b_var, d_name, start_p))

                    if valid_starts:
                        model.add(sum(b_var for (b_var, _, _) in valid_starts) == 1)
                        for slot in time_slots:
                            d_lower = slot[0].lower()
                            p_num = slot[1]
                            covering = [
                                b_var for (b_var, d_s, p_s) in valid_starts
                                if d_s == d_lower and p_s <= p_num < p_s + hrs
                            ]
                            if (a_id, slot) in x:
                                if covering:
                                    model.add(x[(a_id, slot)] == sum(covering))
                                else:
                                    model.add(x[(a_id, slot)] == 0)

            # 2. Default Soft Objectives: Course Day Spreading & Faculty Load Distribution
            objective_terms = []
            days_list = list(set(s[0].lower() for s in time_slots))
            for alloc in allocations:
                a_id = alloc['id']
                c_code = str(alloc['course_code']).strip()
                hrs = alloc['hours']
                is_lab = 'lab' in c_code.lower() or c_code in lab_courses

                if not is_lab and hrs >= 2:
                    for d_lower in days_list:
                        day_slots = [s for s in time_slots if s[0].lower() == d_lower and (a_id, s) in x]
                        if day_slots:
                            day_active = model.new_bool_var(f'day_active_{a_id}_{d_lower}')
                            model.add(sum(x[(a_id, s)] for s in day_slots) >= day_active)
                            objective_terms.append(5 * day_active)

            # Constraint 5: User Configurable Constraints Sheet (Optional Custom Additions)
            active_constraints = pd.DataFrame()
            if not constraints_df.empty:
                if 'Enable' in constraints_df.columns:
                    enabled_mask = constraints_df['Enable'].astype(str).str.strip().str.upper().isin(['TRUE', '1', 'YES'])
                    active_constraints = constraints_df[enabled_mask]
                else:
                    active_constraints = constraints_df

                priority_weights = {'high': 10, 'medium': 5, 'low': 1}

                for _, r in active_constraints.iterrows():
                    c_type = str(r.get('Constraint Type', '')).strip().lower()
                    e_type = str(r.get('Entity Type', '')).strip().lower()
                    entity = str(r.get('Entity', '')).strip()
                    day = str(r.get('Day', '')).strip()
                    p_val = r.get('Period')
                    period = int(p_val) if pd.notna(p_val) and str(p_val).isdigit() else None
                    priority_str = str(r.get('Priority', 'Medium')).strip().lower()
                    weight = priority_weights.get(priority_str, 5)

                    if not c_type:
                        continue

                    # For fixed course/class, skip if Entity, Day, or Period is empty/NaN
                    if c_type in ['fixed course', 'fixed class']:
                        if not entity or entity.lower() == 'nan' or not day or day.lower() == 'nan' or period is None:
                            continue

                    target_a_ids = []
                    for alloc in allocations:
                        a_id = alloc['id']
                        if e_type == 'course' or c_type in ['fixed course', 'preferred day', 'preferred period', 'avoid day', 'avoid period', 'course same day restriction', 'spread course across days']:
                            if entity and alloc['course_code'] != entity:
                                continue
                        if e_type == 'class' or c_type in ['fixed class', 'class preferred day', 'class preferred period']:
                            if entity and alloc['class_id'] != entity:
                                continue
                        if e_type == 'faculty' or c_type in ['faculty preferred day', 'faculty preferred period', 'avoid first period', 'avoid last period']:
                            if entity and alloc['faculty_id'] != entity:
                                continue
                        if 'lab' in e_type or 'lab' in c_type:
                            if alloc['course_code'] not in lab_courses:
                                continue
                            if entity and alloc['course_code'] != entity:
                                continue
                        target_a_ids.append(a_id)

                    if not target_a_ids:
                        continue

                    # Hard Constraints
                    if c_type == 'fixed course':
                        if day and period and entity:
                            t_slot = (day, period)
                            if t_slot in time_slots and target_a_ids:
                                model.add(sum(x[(a_id, t_slot)] for a_id in target_a_ids if (a_id, t_slot) in x) == 1)

                    elif c_type == 'fixed class':
                        if day and period:
                            t_slot = (day, period)
                            if t_slot in time_slots and target_a_ids:
                                model.add(sum(x[(a_id, t_slot)] for a_id in target_a_ids if (a_id, t_slot) in x) == 1)

                    # Soft Constraints (Preferences & Penalties)
                    elif c_type in ['preferred day', 'faculty preferred day', 'class preferred day', 'preferred lab day']:
                        if day:
                            for a_id in target_a_ids:
                                for slot in time_slots:
                                    if slot[0].lower() == day.lower() and (a_id, slot) in x:
                                        objective_terms.append(weight * x[(a_id, slot)])

                    elif c_type in ['preferred period', 'faculty preferred period', 'class preferred period', 'preferred lab period']:
                        if period:
                            for a_id in target_a_ids:
                                for slot in time_slots:
                                    if slot[1] == period and (a_id, slot) in x:
                                        objective_terms.append(weight * x[(a_id, slot)])

                    elif c_type in ['avoid day', 'avoid lab day']:
                        if day:
                            for a_id in target_a_ids:
                                for slot in time_slots:
                                    if slot[0].lower() == day.lower() and (a_id, slot) in x:
                                        objective_terms.append(-weight * x[(a_id, slot)])

                    elif c_type in ['avoid period', 'avoid lab period']:
                        if period:
                            for a_id in target_a_ids:
                                for slot in time_slots:
                                    if slot[1] == period and (a_id, slot) in x:
                                        objective_terms.append(-weight * x[(a_id, slot)])

                    elif c_type == 'avoid first period':
                        min_p = min(s[1] for s in time_slots) if time_slots else 1
                        for a_id in target_a_ids:
                            for slot in time_slots:
                                if slot[1] == min_p and (a_id, slot) in x:
                                    objective_terms.append(-weight * x[(a_id, slot)])

                    elif c_type == 'avoid last period':
                        max_p = max(s[1] for s in time_slots) if time_slots else 6
                        for a_id in target_a_ids:
                            for slot in time_slots:
                                if slot[1] == max_p and (a_id, slot) in x:
                                    objective_terms.append(-weight * x[(a_id, slot)])

            if objective_terms:
                model.maximize(sum(objective_terms))

            # Solve
            solver = cp_model.CpSolver()
            solver.parameters.max_time_in_seconds = 120.0
            solver.parameters.num_search_workers = 8
            status = solver.solve(model)

            if status == cp_model.OPTIMAL or status == cp_model.FEASIBLE:
                print("Optimal Timetable Found!")
                scheduled_entries = []
                for alloc in allocations:
                    a_id = alloc['id']
                    for slot in time_slots:
                        if solver.value(x[(a_id, slot)]) == 1:
                            scheduled_entries.append({
                                'faculty_id': alloc['faculty_id'],
                                'course_code': alloc['course_code'],
                                'class_id': alloc['class_id'],
                                'room_id': 'DEFAULT_ROOM',
                                'day': slot[0],
                                'period': slot[1]
                            })
                return {"status": "success", "schedule": scheduled_entries}
            elif status == cp_model.INFEASIBLE:
                diag_msg = diagnose_infeasibility_reason(allocations, time_slots, faculty_map, class_map, fac_avail_df, active_constraints)
                return {"status": "failed", "error": diag_msg}
            elif status == cp_model.MODEL_INVALID:
                return {"status": "failed", "error": "The solver model is invalid. Please check your uploaded Excel data for formatting issues."}
            else:
                return {"status": "failed", "error": "Solver timed out after 120 seconds without finding a solution. Try reducing the number of allocations or time slots."}

        else:
            # ===== 3D MODEL: With room dimension (allocation x room x slot) =====
            x = {}
            for alloc in allocations:
                a_id = alloc['id']
                for room in rooms:
                    for slot in time_slots:
                        x[(a_id, room, slot)] = model.new_bool_var(f'alloc_{a_id}_room_{room}_slot_{slot}')

            # Constraint 1: Each allocation scheduled exactly for required hours
            for alloc in allocations:
                a_id = alloc['id']
                model.add(
                    sum(x[(a_id, room, slot)] for room in rooms for slot in time_slots) == alloc['hours']
                )

            # Constraint 2: Room conflict - at most 1 allocation per room per slot
            for room in rooms:
                for slot in time_slots:
                    model.add(
                        sum(x[(alloc['id'], room, slot)] for alloc in allocations) <= 1
                    )

            # Constraint 3: Faculty conflict
            faculty_map = defaultdict(list)
            for alloc in allocations:
                faculty_map[alloc['faculty_id']].append(alloc['id'])

            for fac_id, a_ids in faculty_map.items():
                if len(a_ids) <= 1:
                    continue
                for slot in time_slots:
                    model.add(sum(x[(a_id, room, slot)] for a_id in a_ids for room in rooms) <= 1)

            # Constraint 4: Class conflict
            class_map = defaultdict(list)
            for alloc in allocations:
                class_map[alloc['class_id']].append(alloc['id'])

            for c_id, a_ids in class_map.items():
                if len(a_ids) <= 1:
                    continue
                for slot in time_slots:
                    model.add(sum(x[(a_id, room, slot)] for a_id in a_ids for room in rooms) <= 1)

            # Constraint 5: Faculty Availability
            if not fac_avail_df.empty:
                for _, row in fac_avail_df.iterrows():
                    avail = str(row.get('Availability', '')).strip().lower()
                    if avail not in ('available', 'yes', '1', 'true'):
                        fac_id = str(row.get('Faculty ID', '')).strip()
                        day = str(row.get('Day', '')).strip()
                        period = int(row.get('Period', 0))
                        slot = (day, period)
                        if slot in time_slots and fac_id in faculty_map:
                            for a_id in faculty_map[fac_id]:
                                for room in rooms:
                                    if (a_id, room, slot) in x:
                                        model.add(x[(a_id, room, slot)] == 0)

            # Constraint 6: Room Availability
            if not room_avail_df.empty:
                for _, row in room_avail_df.iterrows():
                    avail = str(row.get('Availability', '')).strip().lower()
                    if avail not in ('available', 'yes', '1', 'true'):
                        room_id = str(row.get('Room ID', '')).strip()
                        day = str(row.get('Day', '')).strip()
                        period = int(row.get('Period', 0))
                        slot = (day, period)
                        if slot in time_slots and room_id in rooms:
                            for alloc in allocations:
                                a_id = alloc['id']
                                if (a_id, room_id, slot) in x:
                                    model.add(x[(a_id, room_id, slot)] == 0)

            # ===== DEFAULT CONSTRAINTS FOR 3D MODEL (ALWAYS ACTIVE) =====
            # 1. Consecutive Lab Blocks: Labs with >= 2 hours must be consecutive periods in the SAME room on the SAME day
            for alloc in allocations:
                a_id = alloc['id']
                c_code = str(alloc['course_code']).strip()
                hrs = alloc['hours']
                is_lab = 'lab' in c_code.lower() or c_code in lab_courses

                if is_lab and hrs >= 2:
                    valid_starts = []
                    for room in rooms:
                        for d_name, p_list in slots_by_day.items():
                            for i in range(len(p_list) - hrs + 1):
                                consec_block = p_list[i : i + hrs]
                                if all(consec_block[j] == consec_block[0] + j for j in range(hrs)):
                                    start_p = consec_block[0]
                                    b_var = model.new_bool_var(f'lab3d_start_{a_id}_{room}_{d_name}_{start_p}')
                                    valid_starts.append((b_var, room, d_name, start_p))

                    if valid_starts:
                        model.add(sum(b_var for (b_var, _, _, _) in valid_starts) == 1)
                        for room in rooms:
                            for slot in time_slots:
                                d_lower = slot[0].lower()
                                p_num = slot[1]
                                covering = [
                                    b_var for (b_var, r_s, d_s, p_s) in valid_starts
                                    if r_s == room and d_s == d_lower and p_s <= p_num < p_s + hrs
                                ]
                                if (a_id, room, slot) in x:
                                    if covering:
                                        model.add(x[(a_id, room, slot)] == sum(covering))
                                    else:
                                        model.add(x[(a_id, room, slot)] == 0)

            # 2. Default Soft Objectives for 3D Model: Course Day Spreading
            objective_terms_3d = []
            for alloc in allocations:
                a_id = alloc['id']
                c_code = str(alloc['course_code']).strip()
                hrs = alloc['hours']
                is_lab = 'lab' in c_code.lower() or c_code in lab_courses

                if not is_lab and hrs >= 2:
                    for d_lower in days_list:
                        day_slots = [(r, s) for r in rooms for s in time_slots if s[0].lower() == d_lower and (a_id, r, s) in x]
                        if day_slots:
                            day_active = model.new_bool_var(f'day3d_active_{a_id}_{d_lower}')
                            model.add(sum(x[(a_id, r, s)] for (r, s) in day_slots) >= day_active)
                            objective_terms_3d.append(5 * day_active)

            if objective_terms_3d:
                model.maximize(sum(objective_terms_3d))

            # Solve
            solver = cp_model.CpSolver()
            solver.parameters.max_time_in_seconds = 120.0
            solver.parameters.num_search_workers = 8
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
                diag_msg = diagnose_infeasibility_reason(allocations, time_slots, faculty_map, class_map, fac_avail_df, active_constraints, rooms=rooms)
                return {"status": "failed", "error": diag_msg}
            elif status == cp_model.MODEL_INVALID:
                return {"status": "failed", "error": "The solver model is invalid. Please check your uploaded Excel data for formatting issues."}
            else:
                return {"status": "failed", "error": "Solver timed out after 120 seconds without finding a solution. Try reducing the number of allocations, rooms, or time slots."}

    except Exception as e:
        return {"status": "failed", "error": str(e)}