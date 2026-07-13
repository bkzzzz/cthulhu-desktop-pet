@echo off
setlocal
call "%~dp0run_game.cmd" -Headless --script res://tests/run_tests.gd
exit /b %ERRORLEVEL%
