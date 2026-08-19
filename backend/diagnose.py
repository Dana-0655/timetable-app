import pandas as pd
from collections import defaultdict

# Try both files
for fname in ['temp_job_5d6f6e6c-03ce-4d52-915f-b2f904be7915.xlsx', 'temp_job_9938482a-b7d3-4120-8839-d4365f67c058.xlsx']:
    try:
        xls = pd.ExcelFile(fname)
    except:
        continue
    
    print("=== Analyzing:", fname, "===")
    
    alloc_df = pd.read_excel(xls, 'Faculty Allocation').dropna(how='all')
    slots_df = pd.read_excel(xls, 'Time Slots').dropna(how='all')
    
    total_slots = len(slots_df)
    print("Total time slots:", total_slots)
    print("Total allocations:", len(alloc_df))
    
    # Build per-faculty allocation: which classes and how many hours
    fac_allocs = defaultdict(list)
    for _, row in alloc_df.iterrows():
        fid = str(row['Faculty ID']).strip()
        cid = str(row['Class ID']).strip()
        hrs = int(row.get('Hours Per Week', 1))
        fac_allocs[fid].append({'class_id': cid, 'hours': hrs})
    
    # Check: for each faculty, total hours must <= total_slots
    # AND for each faculty, the classes they teach must not create impossible overlaps
    print("\n--- FACULTY CONFLICT ANALYSIS ---")
    for fid, items in sorted(fac_allocs.items()):
        total_hrs = sum(i['hours'] for i in items)
        unique_classes = set(i['class_id'] for i in items)
        
        # Check per-slot conflicts: Faculty teaches N classes. Each class also has other
        # allocations. If class C has K total allocations, then at most K slots are occupied by C.
        # But faculty can only be in 1 slot at a time.
        if total_hrs > total_slots:
            print("  *** OVERLOADED *** Faculty %s: %d hrs > %d slots" % (fid, total_hrs, total_slots))
    
    # Check: for each class, do classes share the same faculty in a way that creates conflicts?
    # A class that has the same faculty for two courses means that faculty needs N+M hours, 
    # AND the class needs N+M hours in different slots.
    # But the real issue is: can the COMBINATION of all faculty-class constraints be satisfied?
    
    # Let's check overlapping faculty across classes
    print("\n--- FACULTY TEACHING MULTIPLE CLASSES IN SAME SLOT ---")
    # For each time slot, at most 1 allocation per faculty.
    # If faculty F teaches class A (3hrs) and class B (3hrs), that's fine if A and B 
    # don't need to be scheduled at the same slots.
    # But if class A needs 30 hrs total and class B needs 30 hrs total, and they each 
    # fill all 48 slots, then faculty F can't teach both.
    
    class_total = defaultdict(int)
    for _, row in alloc_df.iterrows():
        cid = str(row['Class ID']).strip()
        hrs = int(row.get('Hours Per Week', 1))
        class_total[cid] += hrs
    
    # For each pair of classes sharing a faculty, check if their combined slot needs allow it
    fac_class_hours = defaultdict(lambda: defaultdict(int))
    for fid, items in fac_allocs.items():
        for item in items:
            fac_class_hours[fid][item['class_id']] += item['hours']
    
    conflicts_found = False
    for fid, class_hrs in fac_class_hours.items():
        if len(class_hrs) <= 1:
            continue
        total_fac_hrs = sum(class_hrs.values())
        classes_list = list(class_hrs.keys())
        
        # Check if any two classes this faculty teaches have so many hours 
        # that they'd need overlapping slots
        for i in range(len(classes_list)):
            for j in range(i+1, len(classes_list)):
                c1, c2 = classes_list[i], classes_list[j]
                c1_total = class_total[c1]
                c2_total = class_total[c2]
                # If c1 needs c1_total slots and c2 needs c2_total slots,
                # and c1_total + c2_total > total_slots, they MUST overlap.
                # But faculty can't be in both at same time.
                if c1_total + c2_total > total_slots:
                    f_c1 = class_hrs[c1]
                    f_c2 = class_hrs[c2]
                    overlap = (c1_total + c2_total) - total_slots
                    # In the overlap slots, both classes are running, but faculty 
                    # can only teach one. So faculty hours in those classes must be schedulable
                    # outside the overlap.
                    if f_c1 + f_c2 > total_slots - overlap:
                        conflicts_found = True
                        print("  CONFLICT: Faculty %s teaches %s (%d hrs, class needs %d total) AND %s (%d hrs, class needs %d total)" % (fid, c1, f_c1, c1_total, c2, f_c2, c2_total))
                        print("    Overlap: %d slots where both classes run. Faculty needs %d hrs but only %d available." % (overlap, f_c1 + f_c2, total_slots - overlap))
    
    if not conflicts_found:
        print("  No obvious pairwise conflicts found.")
        # The issue might be more subtle - let's check n-way
        print("\n--- CHECKING N-WAY FACULTY CONFLICTS ---")
        for fid, class_hrs in fac_class_hours.items():
            if len(class_hrs) <= 1:
                continue
            # For each slot, at most 1 class can use this faculty.
            # Faculty has total_fac_hrs to distribute across total_slots.
            # But each class constrains which slots are available.
            total_fac = sum(class_hrs.values())
            # Check: for each class this faculty teaches, that class has class_total[c] hours
            # of occupancy. Faculty must schedule their hours in those occupied slots.
            # The intersection of occupied slots across classes determines feasibility.
            print("  Faculty %s: %d total hrs across %d classes" % (fid, total_fac, len(class_hrs)))
            for cid, hrs in class_hrs.items():
                available_for_fac = class_total[cid]  # class occupied slots where faculty COULD teach
                print("    -> %s: faculty needs %d hrs, class has %d occupied slots" % (cid, hrs, available_for_fac))
    
    xls.close()
    break  # Only analyze first available file
