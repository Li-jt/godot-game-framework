@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
:: ============================================================
:: GF Editor Tools — Windows 同步脚本（双击运行）
:: ============================================================
:: 双击此文件即可自动将框架编辑器工具安装到游戏项目中。
:: 脚本会自动向上查找 project.godot 来定位项目根目录。
:: ============================================================

:: ---- 推断框架根（向上搜索 addons\gf_editor_tools） ----
set "CURDIR=%~dp0"
:find_framework
set "CURDIR=%CURDIR:~0,-1%"
if "%CURDIR%"=="" goto :no_framework
if exist "%CURDIR%\addons\gf_editor_tools\plugin.cfg" goto :found_framework
:: 向上一级
for %%i in ("%CURDIR%") do set "CURDIR=%%~dpi"
goto :find_framework

:found_framework
set "FRAMEWORK_DIR=%CURDIR%"
set "SRC_ADDON=%FRAMEWORK_DIR%\addons\gf_editor_tools"
goto :find_project

:no_framework
cls
echo ╔══════════════════════════════════════════╗
echo ║  GF Editor Tools — 同步脚本 (Windows)   ║
echo ╚══════════════════════════════════════════╝
echo.
echo   [错误] 找不到 addons\gf_editor_tools
echo   请确认框架目录结构完整。
pause
exit /b 1

:: ---- 推断项目根（向上搜索 project.godot） ----
:find_project
set "CURDIR=%FRAMEWORK_DIR%"
:search_up
if "%CURDIR%"=="" goto :no_project
if exist "%CURDIR%\project.godot" goto :found_project
for %%i in ("%CURDIR%") do set "CURDIR=%%~dpi"
goto :search_up

:found_project
set "PROJECT_DIR=%CURDIR%"
set "DST_ADDON=%PROJECT_DIR%\addons\gf_editor_tools"
set "PROJECT_GODOT=%PROJECT_DIR%project.godot"
set "PLUGIN_ENTRY=res://addons/gf_editor_tools/plugin.cfg"
goto :main

:no_project
cls
echo ╔══════════════════════════════════════════╗
echo ║  GF Editor Tools — 同步脚本 (Windows)   ║
echo ╚══════════════════════════════════════════╝
echo.
echo   [错误] 找不到 project.godot
echo.
echo   脚本通过向上搜索 project.godot 来定位项目根。
echo   请确认：
echo     1. 框架代码放在了游戏项目的子目录中（如 src\framework\）
echo     2. 游戏项目根目录下有 project.godot
pause
exit /b 1

:: ---- 主流程 ----
:main
cls
echo ╔══════════════════════════════════════════╗
echo ║  GF Editor Tools — 同步脚本 (Windows)   ║
echo ╚══════════════════════════════════════════╝
echo.
echo   项目路径 : %PROJECT_DIR%
echo   框架路径 : %FRAMEWORK_DIR%
echo.

:: ---- 确认覆盖 ----
if exist "%DST_ADDON%" (
    echo   [!] 目标位置已存在 gf_editor_tools
    echo   [!] %DST_ADDON%
    echo.
    echo   覆盖会丢失该目录下的本地修改。
    echo   如果只是要更新版本，选择覆盖是安全的。
    echo.
    choice /c YN /n /m "  是否覆盖? [Y/N] "
    if errorlevel 2 goto :cancelled
    if errorlevel 1 goto :do_copy
)

:do_copy
:: ---- 确保 addons 目录存在 ----
if not exist "%PROJECT_DIR%\addons" (
    mkdir "%PROJECT_DIR%\addons"
    echo   已创建 addons\ 目录
)

:: ---- 步骤 1: 复制 addon ----
echo.
echo   [1/2] 复制 addon 文件...

:: 检查源和目标是否相同
for %%i in ("%SRC_ADDON%") do set "SRC_FULL=%%~fi"
for %%i in ("%DST_ADDON%") do set "DST_FULL=%%~fi" 2>nul
if /i "%SRC_FULL%"=="%DST_FULL%" (
    echo          源和目标相同，跳过复制
) else (
    if exist "%DST_ADDON%" rmdir /s /q "%DST_ADDON%" 2>nul
    xcopy /e /i /q /y "%SRC_ADDON%" "%DST_ADDON%" >nul
    echo          已复制到 %DST_ADDON%
)

:: ---- 步骤 2: 启用插件 ----
echo   [2/2] 启用插件...

findstr /c:"gf_editor_tools" "%PROJECT_GODOT%" >nul 2>&1
if !errorlevel! equ 0 (
    echo          插件已处于启用状态
    goto :done
)

:: 使用 PowerShell 修改 project.godot
powershell -ExecutionPolicy Bypass -Command ^
    "$path = '%PROJECT_GODOT%';" ^
    "$entry = '%PLUGIN_ENTRY%';" ^
    "$lines = Get-Content -Path $path -Encoding UTF8;" ^
    "$sectionIdx = -1; $enabledIdx = -1;" ^
    "for ($i = 0; $i -lt $lines.Count; $i++) {" ^
    "    if ($lines[$i].Trim() -eq '[editor_plugins]') { $sectionIdx = $i }" ^
    "    elseif ($sectionIdx -ge 0 -and $lines[$i].Trim().StartsWith('enabled=PackedStringArray')) { $enabledIdx = $i; break }" ^
    "    elseif ($sectionIdx -ge 0 -and $lines[$i].Trim().StartsWith('[') -and $i -gt $sectionIdx) { break }" ^
    "}" ^
    "if ($enabledIdx -ge 0) {" ^
    "    $old = $lines[$enabledIdx];" ^
    "    $escaped = '\"' + $entry + '\"';" ^
    "    if ($old -match '\((.+)\)') {" ^
    "        $inner = $Matches[1].Trim();" ^
    "        if ($inner -eq '') { $lines[$enabledIdx] = 'enabled=PackedStringArray(' + $escaped + ')' }" ^
    "        else { $lines[$enabledIdx] = $old.TrimEnd() -replace '\)$', (', ' + $escaped + ')') }" ^
    "    }" ^
    "} elseif ($sectionIdx -ge 0) {" ^
    "    $lines = @($lines[0..$sectionIdx]) + @('enabled=PackedStringArray(' + $escaped + ')') + @($lines[($sectionIdx+1)..($lines.Count-1)])" ^
    "} else {" ^
    "    $lines += ''; $lines += '[editor_plugins]'; $lines += 'enabled=PackedStringArray(' + $escaped + ')'" ^
    "}" ^
    "[System.IO.File]::WriteAllLines($path, $lines, [System.Text.UTF8Encoding]::new($false))"

if %errorlevel% equ 0 (
    echo          已启用 GF Editor Tools
) else (
    echo          [警告] 自动启用失败，请在 Godot 中手动启用：
    echo                 项目设置 → 插件 → 勾选 GF Editor Tools
)

goto :done

:cancelled
echo.
echo   已取消。
pause
exit /b 0

:done
echo.
echo   ══════════════════════════════════════════
echo   设置完成！
echo   重启 Godot 编辑器后，在 FileSystem 中
echo   右键 → 新建 → ECS Component 即可使用。
echo   ══════════════════════════════════════════
echo.
pause
