@echo off
cd /d "%~dp0"
cd lib

mkdir core\constants 2>nul
mkdir core\theme 2>nul
mkdir core\validators 2>nul
mkdir core\models 2>nul
mkdir features\auth\screens 2>nul
mkdir features\auth\providers 2>nul
mkdir features\onboarding\screens 2>nul
mkdir features\onboarding\widgets 2>nul
mkdir features\home\screens 2>nul
mkdir features\home\widgets 2>nul
mkdir features\suggestion\screens 2>nul
mkdir features\suggestion\providers 2>nul
mkdir features\profile\screens 2>nul
mkdir features\profile\widgets 2>nul
mkdir router 2>nul
mkdir shared\widgets 2>nul

echo Klasorler basariyla olusturuldu!
pause
