<#
.SYNOPSIS
Builds Qt's MySQL driver (qsqlmysql.dll, "QMYSQL") for your installed Qt
(MinGW) and installs it into that Qt.

.DESCRIPTION
The Qt installer doesn't include the MySQL driver, and a driver only works
with the exact Qt version it was built for (it uses Qt-internal headers), so
run this once per Qt version you install.

It uses MariaDB Connector/C from this repository
(mariadb-connector-c\mariadb-connector-c-<ver>) as the MySQL client library:
LGPL, works with MySQL 8.x/9.x (including the default caching_sha2_password
login), TLS through Windows' own Schannel.

What it does:
  1. finds Qt (-QtDir, else QT_DIR, else the newest C:\Qt\6.*\mingw_64), and
     Qt's MinGW, CMake and Ninja (C:\Qt\Tools\..., else PATH)
  2. finds the driver source: Qt's "Sources" component
     (C:\Qt\<ver>\Src\qtbase\src\plugins\sqldrivers) or, if that isn't
     installed, downloads just that folder with git
  3. builds it with Qt's qt-cmake and installs plugins\sqldrivers\qsqlmysql.dll
     into Qt, and copies libmariadb.dll into Qt's bin\ (next to the Qt DLLs)
  4. builds and runs a small check program: the driver must load; with
     -TestConnection it also connects (TLS required) and runs a query

Deploying your application: Qt's deployment (windeployqt, or
qt_generate_deploy_app_script) copies qsqlmysql.dll but not libmariadb.dll.
Install that yourself, e.g. in CMake:
  install(FILES "$<TARGET_FILE_DIR:Qt6::Core>/libmariadb.dll" DESTINATION ${CMAKE_INSTALL_BINDIR})

.PARAMETER QtDir
The Qt kit, e.g. C:\Qt\6.12.0\mingw_64.
.PARAMETER ConnectorDir
MariaDB Connector/C (default: newest under this repository's mariadb-connector-c\).
.PARAMETER SourceDir
qtbase\src\plugins\sqldrivers of the same Qt version (default: see above).
.PARAMETER BuildDir
Scratch folder (default: %TEMP%\qt-mysql-driver-<Qt version>).
.PARAMETER TestConnection
host:port:user:password of a MySQL server to test against.
.PARAMETER NoInstall
Build only: leave Qt untouched (the plugin stays in BuildDir).

.EXAMPLE
powershell -ExecutionPolicy Bypass -File windows\build-qt-mysql-driver.ps1
.EXAMPLE
powershell -ExecutionPolicy Bypass -File windows\build-qt-mysql-driver.ps1 -QtDir C:\Qt\6.12.0\mingw_64 -TestConnection "db.example.com:3306:me:secret"
#>
[CmdletBinding()]
param(
    [string] $QtDir,
    [string] $ConnectorDir,
    [string] $SourceDir,
    [string] $BuildDir,
    [string] $TestConnection,
    [switch] $NoInstall
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$onWindows = [System.Environment]::OSVersion.Platform -eq 'Win32NT'

function Fail([string] $message) {
    Write-Host "error: $message" -ForegroundColor Red
    exit 1
}

# Run a program; stop if it fails.
function Invoke-Tool([string] $exe, [string[]] $arguments) {
    & $exe @arguments
    if ($LASTEXITCODE -ne 0) { Fail "$(Split-Path -Leaf $exe) failed (exit code $LASTEXITCODE)" }
}

function CMakePath([string] $path) { return ($path -replace '\\', '/') }

# The folder whose name has the highest version number
# (6.12.0, mingw1310_64, mariadb-connector-c-3.4.11, ...).
function Select-Newest($folders) {
    return @($folders) | Where-Object { $_ } | Sort-Object {
        $m = [regex]::Match((Split-Path -Leaf $_), '\d+(\.\d+)*')
        $v = if ($m.Success) { $m.Value } else { '0' }
        if ($v -notmatch '\.') { $v += '.0' }
        [version]$v
    } -Descending | Select-Object -First 1
}

# --- 1. Qt and tools -----------------------------------------------------------
if (-not $QtDir -and $env:QT_DIR) { $QtDir = $env:QT_DIR }
if (-not $QtDir) {
    # C:\Qt\<version>\mingw_64 with the highest version
    $versions = @(Get-ChildItem "$env:SystemDrive\Qt\6.*" -Directory -ErrorAction SilentlyContinue |
                  Where-Object { Test-Path "$($_.FullName)\mingw_64\lib\cmake\Qt6\Qt6Config.cmake" } |
                  ForEach-Object { $_.FullName })
    if ($versions.Count -eq 0) { Fail "no Qt found: pass -QtDir (e.g. C:\Qt\6.12.0\mingw_64) or set QT_DIR" }
    $QtDir = Join-Path (Select-Newest $versions) 'mingw_64'
}
$QtDir = (Resolve-Path $QtDir).Path
$versionFile = Get-ChildItem "$QtDir/lib/cmake/Qt6" -Filter 'Qt6ConfigVersion*.cmake' -ErrorAction SilentlyContinue |
               Select-String 'PACKAGE_VERSION "(\d+\.\d+\.\d+)"' | Select-Object -First 1
if (-not $versionFile) { Fail "$QtDir is not a Qt 6 kit (no lib\cmake\Qt6\Qt6ConfigVersion*.cmake)" }
$qtVersion = $versionFile.Matches[0].Groups[1].Value
$qtCmake = if ($onWindows) { "$QtDir\bin\qt-cmake.bat" } else { "$QtDir/bin/qt-cmake" }
if (-not (Test-Path $qtCmake)) { Fail "qt-cmake not found in $QtDir\bin" }
Write-Host "Qt $qtVersion at $QtDir"

if ($onWindows) {
    # Qt's own MinGW, CMake and Ninja (Qt\Tools), put first on PATH.
    $qtRoot = Split-Path -Parent (Split-Path -Parent $QtDir)
    $toolDirs = @()
    $mingw = Select-Newest @(Get-ChildItem "$qtRoot\Tools\mingw*_64" -Directory -ErrorAction SilentlyContinue |
                             Where-Object { Test-Path "$($_.FullName)\bin\g++.exe" } | ForEach-Object { $_.FullName })
    if ($mingw) { $toolDirs += "$mingw\bin" }
    foreach ($dir in "$qtRoot\Tools\CMake_64\bin", "$qtRoot\Tools\Ninja") {
        if (Test-Path $dir) { $toolDirs += $dir }
    }
    if ($toolDirs.Count) { $env:PATH = ($toolDirs -join ';') + ';' + $env:PATH }
    foreach ($tool in 'g++', 'cmake', 'ninja') {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            Fail "$tool not found: install it with the Qt installer (Qt > Developer and Designer Tools: MinGW, CMake, Ninja)"
        }
    }
    Write-Host "Compiler: $((Get-Command g++).Source)"
}

# --- 2. Connector and driver source --------------------------------------------
if (-not $ConnectorDir) {
    $ConnectorDir = Select-Newest @(Get-ChildItem "$repo/mariadb-connector-c/mariadb-connector-c-*" -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
}
if (-not $ConnectorDir) { Fail "MariaDB Connector/C not found in $repo\mariadb-connector-c (pass -ConnectorDir)" }
$connectorDll = Join-Path $ConnectorDir 'bin/libmariadb.dll'
$connectorLib = Get-ChildItem "$ConnectorDir/lib" -Filter '*mariadb*.dll.a' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not (Test-Path $connectorDll) -or -not $connectorLib -or -not (Test-Path "$ConnectorDir/include/mariadb/mysql.h")) {
    Fail "$ConnectorDir is incomplete (expected bin\libmariadb.dll, lib\*mariadb*.dll.a, include\mariadb\mysql.h)"
}
Write-Host "MariaDB Connector/C at $ConnectorDir"

if (-not $BuildDir) { $BuildDir = Join-Path ([System.IO.Path]::GetTempPath()) "qt-mysql-driver-$qtVersion" }
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

if (-not $SourceDir) {
    # Qt installer layout: C:\Qt\<version>\Src next to C:\Qt\<version>\mingw_64
    $versionDir = [System.IO.Path]::GetDirectoryName($QtDir.TrimEnd('\', '/'))
    $installed = if ($versionDir) { Join-Path $versionDir 'Src/qtbase/src/plugins/sqldrivers' } else { '' }
    if ($installed -and (Test-Path "$installed/CMakeLists.txt")) {
        $SourceDir = $installed
    } else {
        # Only the sqldrivers folder of qtbase, at the same version.
        $clone = Join-Path $BuildDir 'qtbase'
        if (-not (Test-Path "$clone/src/plugins/sqldrivers/CMakeLists.txt")) {
            if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
                Fail "Qt's sources aren't installed and git isn't available: add 'Sources' for Qt $qtVersion in the Qt installer, or install git"
            }
            if (Test-Path $clone) { Remove-Item -Recurse -Force $clone }
            Write-Host "Downloading qtbase $qtVersion src/plugins/sqldrivers ..."
            Invoke-Tool git @('-c', 'advice.detachedHead=false', 'clone', '-q', '--depth', '1', '--filter=blob:none',
                              '--sparse', '--branch', "v$qtVersion", 'https://github.com/qt/qtbase.git', $clone)
            Invoke-Tool git @('-C', $clone, 'sparse-checkout', 'set', 'src/plugins/sqldrivers')
        }
        $SourceDir = "$clone/src/plugins/sqldrivers"
    }
}
if (-not (Test-Path "$SourceDir/mysql")) { Fail "$SourceDir has no mysql driver source" }
Write-Host "Driver source: $SourceDir"

# --- 3. Build and install ------------------------------------------------------
$build = Join-Path $BuildDir 'build'
if (Test-Path $build) { Remove-Item -Recurse -Force $build }
$prefix = if ($NoInstall) { Join-Path $BuildDir 'install' } else { $QtDir }
Invoke-Tool $qtCmake @('-G', 'Ninja', '-S', (CMakePath $SourceDir), '-B', (CMakePath $build),
    '-DCMAKE_BUILD_TYPE=Release',
    "-DCMAKE_INSTALL_PREFIX=$(CMakePath $prefix)",
    '-DFEATURE_sql_mysql=ON',
    '-DFEATURE_sql_sqlite=OFF', '-DFEATURE_sql_odbc=OFF', '-DFEATURE_sql_psql=OFF',
    '-DFEATURE_sql_ibase=OFF', '-DFEATURE_sql_oci=OFF', '-DFEATURE_sql_db2=OFF', '-DFEATURE_sql_mimer=OFF',
    "-DMySQL_INCLUDE_DIR=$(CMakePath "$ConnectorDir/include/mariadb")",
    "-DMySQL_LIBRARY=$(CMakePath $connectorLib.FullName)")
if (-not (Select-String -Path "$build/config.summary" -Pattern '^\s*MySql \.+ yes' -Quiet)) {
    Fail "the MySQL driver was not enabled; see $build\config.summary"
}
Invoke-Tool cmake @('--build', $build)
Invoke-Tool cmake @('--install', $build)

$pluginDir = Join-Path $prefix 'plugins/sqldrivers'
$plugin = Get-ChildItem $pluginDir -Filter '*qsqlmysql*' | Where-Object { $_.Extension -in '.dll', '.so' } | Select-Object -First 1
if (-not $plugin) { Fail "the driver wasn't installed to $pluginDir" }
$binDir = Join-Path $prefix 'bin'
New-Item -ItemType Directory -Force -Path $binDir | Out-Null
Copy-Item $connectorDll $binDir -Force
Write-Host "Installed $($plugin.FullName)"
Write-Host "      and $(Join-Path $binDir 'libmariadb.dll')"

# --- 4. Check program ----------------------------------------------------------
$checkSrc = Join-Path $BuildDir 'check'
New-Item -ItemType Directory -Force -Path $checkSrc | Out-Null
@'
cmake_minimum_required(VERSION 3.16)
project(mysqlcheck LANGUAGES CXX)
find_package(Qt6 REQUIRED COMPONENTS Sql)
add_executable(mysqlcheck main.cpp)
target_link_libraries(mysqlcheck PRIVATE Qt6::Sql)
'@ | Set-Content -Encoding ASCII "$checkSrc/CMakeLists.txt"
@'
#include <QCoreApplication>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStringList>
#include <cstdio>
int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    if (!QSqlDatabase::isDriverAvailable("QMYSQL")) {
        std::printf("QMYSQL driver NOT available; drivers: %s\n", qPrintable(QSqlDatabase::drivers().join(", ")));
        return 1;
    }
    QSqlDatabase db = QSqlDatabase::addDatabase("QMYSQL");
    if (!db.isValid()) { std::printf("QMYSQL driver failed to load\n"); return 1; }
    std::printf("QMYSQL driver loads\n");
    const QStringList s = app.arguments().mid(1).join(':').split(':');
    if (s.size() != 4) return 0;
    db.setHostName(s[0]); db.setPort(s[1].toInt()); db.setUserName(s[2]); db.setPassword(s[3]);
    db.setConnectOptions("SSL_MODE=SSL_MODE_REQUIRED");
    if (!db.open()) { std::printf("connect failed: %s\n", qPrintable(db.lastError().text())); return 1; }
    QSqlQuery q(db);
    if (!q.exec("select version(), (select variable_value from performance_schema.session_status where variable_name = 'Ssl_cipher')") || !q.next()) {
        std::printf("query failed: %s\n", qPrintable(q.lastError().text())); return 1;
    }
    std::printf("connected: MySQL %s, TLS %s\n", qPrintable(q.value(0).toString()), qPrintable(q.value(1).toString()));
    return 0;
}
'@ | Set-Content -Encoding ASCII "$checkSrc/main.cpp"
$checkBuild = Join-Path $BuildDir 'check-build'
if (Test-Path $checkBuild) { Remove-Item -Recurse -Force $checkBuild }
Invoke-Tool $qtCmake @('-G', 'Ninja', '-S', (CMakePath $checkSrc), '-B', (CMakePath $checkBuild), '-DCMAKE_BUILD_TYPE=Release')
Invoke-Tool cmake @('--build', $checkBuild)
$checkExe = Join-Path $checkBuild 'mysqlcheck.exe'
if (-not $onWindows) {
    Write-Host "Check program built: $checkExe (run it on Windows with Qt's bin on PATH)"
    exit 0
}
$env:PATH = "$binDir;$QtDir\bin;$env:PATH"
if ($NoInstall) { $env:QT_PLUGIN_PATH = Join-Path $prefix 'plugins' }
$checkArgs = @()
if ($TestConnection) { $checkArgs = @($TestConnection) }
& $checkExe @checkArgs
if ($LASTEXITCODE -ne 0) { Fail "the check failed" }
Write-Host "Done: QSqlDatabase::addDatabase(""QMYSQL"") works with Qt $qtVersion." -ForegroundColor Green
