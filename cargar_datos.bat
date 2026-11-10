@echo off
chcp 65001 >nul
title Cargar datos de Olist en la base entregas
cd /d "%~dp0"

echo.
echo  Cargando los 8 CSV de Olist en la base "entregas".
echo  Te va a pedir la contrasena del usuario postgres.
echo.

"C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d entregas -W -f "01_raw\03_cargar.sql"

echo.
echo  Revisa arriba: deben aparecer 8 tablas y 550759 filas en total.
echo.
pause
