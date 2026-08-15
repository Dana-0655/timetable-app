@echo off
title Timetable Backend Server
echo Starting Timetable App Backend...
cd /d "C:\Users\Melvin Joshua\Desktop\timetable-app"
call venv\Scripts\activate
set "DATABASE_URL=mysql+pymysql://root:%%23RJtamilan003@localhost/timetable_db"
cd backend
python app.py
pause
