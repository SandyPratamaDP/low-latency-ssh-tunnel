# ==============================================================================
# OPTIMIZED SSH TUNNEL SCRIPT - JSGI PORTAL (HYBRID DATABASE & FILE MODE)
# Features: Smart Reconnect, API Monitor, Hardware Acceleration (AES-NI).
# ==============================================================================

# --- 0. Admin Privilege Check ---
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Script harus dijalankan sebagai Administrator." -ForegroundColor Red
    exit
}

# --- 1. Core Configuration ---
$logFile      = "PATH_TO\database_tunnel.log"
$debugFile    = "PATH_TO\ssh_debug.log"
$remoteHost   = "{TARGET_HOST}"
$sshUser      = "{SSH_USER}"
$sshPort      = "{SSH_PORT}"
$apiPort      = {API_PORT}

# Tunnel List (LocalPort:RemoteHost:RemotePort)
$tunnels = @(
    "3306:localhost:3306",    # MySQL (Database)
    "1522:jsgdb:1522",        # Oracle (Database)
    "1521:jsgdb:1521",        # Oracle (Database)
    "222:127.0.0.1:22"        # SFTP/File Transfer (Port 222)
)

# --- 2. Logging Function ---
function Write-Log($message, $color = "White") {
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fullMsg = "[$stamp] $message"
    $fullMsg | Out-File -FilePath $logFile -Append -Encoding utf8
    Write-Host $fullMsg -ForegroundColor $color
}

# --- 3. Hybrid Optimization Parameters ---
# -c aes128-gcm@openssh.com: Terbaik untuk CPU modern (AES-NI), cepat untuk DB & File.
# -o Compression=no: Mematikan kompresi SSH karena gambar/file besar sudah terkompresi.
#                    Ini mengurangi beban CPU dan mencegah "double compression lag".
# -o IPQoS=throughput: Mengutamakan volume data untuk kestabilan transfer.
$optArgsBase = "-o Compression=no -o ExitOnForwardFailure=yes -c aes128-gcm@openssh.com -o IPQoS=throughput -o StrictHostKeyChecking=no -o ServerAliveInterval=15 -o TCPKeepAlive=yes -E `"$debugFile`""

# --- 4. Main Tunneling Logic ---
function Check-Tunnels {
    Write-Log "Memeriksa status tunnel (Hybrid DB & File Mode)..." "Cyan"
    foreach ($tunnel in $tunnels) {
        $localPort = $tunnel.Split(":")[0]
        $checkPort = netstat -ano | Select-String "LISTENING" | Select-String ":$localPort\s+"

        if (-not $checkPort) {
            $sshArgs = "-L ${tunnel} ${optArgsBase} `"${sshUser}`"@${remoteHost} -p ${sshPort} -N"
            Start-Process "ssh" -ArgumentList $sshArgs -WindowStyle Hidden
            Write-Log "[RECONNECT] Port $localPort terputus. Menghubungkan kembali..." "Yellow"
            Start-Sleep -Seconds 1
        } else {
            Write-Log "[OK] Port $localPort AKTIF." "Green"
        }
    }
}

# --- 5. API Monitoring Function ---
function Start-MonitoringAPI {
    param($apiPort, $tunnels, $remoteHost)
    
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$apiPort/")
    $listener.Prefixes.Add("http://127.0.0.1:$apiPort/")
    
    try {
        $listener.Start()
        Write-Output "API Monitor berjalan di port $apiPort"
        
        while ($listener.IsListening) {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response
            
            $response.Headers.Add("Access-Control-Allow-Origin", "*")
            $response.Headers.Add("Access-Control-Allow-Methods", "GET, OPTIONS")
            $response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")

            if ($request.HttpMethod -eq "OPTIONS") {
                $response.StatusCode = 200
                $response.Close()
                continue
            }

            if ($request.Url.LocalPath -eq "/" -or $request.Url.LocalPath -eq "/status") {
                $activePorts = @()
                foreach ($t in $tunnels) {
                    $p = $t.Split(":")[0]
                    $isLive = netstat -ano | Select-String "LISTENING" | Select-String ":$p\s+"
                    if ($isLive) { $activePorts += $p }
                }

                $allSshProcesses = Get-Process -Name "ssh" -ErrorAction SilentlyContinue | Sort-Object StartTime
                $uptimeStr = "N/A"
                
                if ($allSshProcesses) { 
                    $oldestSsh = $allSshProcesses[0]
                    $span = (Get-Date) - $oldestSsh.StartTime
                    $uptimeStr = "{0:D2}d {1:D2}h {2:D2}m" -f $span.Days, $span.Hours, $span.Minutes 
                }

                $data = @{
                    activePorts = $activePorts
                    totalTunnels = $tunnels.Count
                    uptime = $uptimeStr
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    server = $remoteHost
                    status = "Running (Hybrid Optimized)"
                }
                
                $json = $data | ConvertTo-Json
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
                $response.StatusCode = 200
                $response.ContentType = "application/json"
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            } else {
                $response.StatusCode = 404
            }
            $response.Close()
        }
    } catch {
        Write-Output "API Error: $_"
    } finally {
        if ($null -ne $listener) { $listener.Stop() }
    }
}

# --- 6. Main Execution ---
Write-Log "--- JSGI TUNNEL SYSTEM INITIALIZED (HYBRID MODE) ---" "Green"

$apiThread = [runspacefactory]::CreateRunspace()
$apiThread.Open()
$apiPowerShell = [powershell]::Create().AddScript((Get-Item function:Start-MonitoringAPI).Definition)
$apiPowerShell.AddArgument($apiPort)
$apiPowerShell.AddArgument($tunnels)
$apiPowerShell.AddArgument($remoteHost)
$apiPowerShell.Runspace = $apiThread
$handle = $apiPowerShell.BeginInvoke()

Write-Log "API Service is warming up..." "Cyan"

try {
    while ($true) {
        Check-Tunnels
        if ($handle.IsCompleted -and $apiPowerShell.Streams.Error.Count -gt 0) {
            Write-Log "WARNING: API thread crash." "Red"
        }
        Write-Log "Berikutnya: Pemeriksaan kesehatan dalam 30 detik..." "Gray"
        Start-Sleep -Seconds 30
    }
} finally {
    Write-Log "Sistem dimatikan." "Red"
    if ($null -ne $apiPowerShell) { $apiPowerShell.Dispose() }
    if ($null -ne $apiThread) { $apiThread.Close() }
}
