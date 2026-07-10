@echo off
rem EARTH DEFENSE FORCE - double-click to play (uses the Godot 4.7 in Downloads; no install)
rem %~dp0 ends in a backslash, and \" escapes the quote in Windows arg parsing - Godot then
rem aborts on the mangled path. The trailing dot keeps the quote intact: "...\." is valid.
start "" "%USERPROFILE%\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" --path "%~dp0."
