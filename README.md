# **JSGI Ultra-Low Latency SSH Tunnel System**

A high-performance SSH tunneling automation system optimized for the **JSGI Portal**. This solution is specifically engineered to handle hybrid workloads: responsive database queries (low latency) and rapid large file/image transfers (high throughput).

## **🖥️ Dashboard Preview**

## **🚀 Key Features**

* **Hybrid Optimization**: Utilizes the aes128-gcm cipher with hardware acceleration (AES-NI) for peak performance on Oracle/MySQL databases and SFTP file transfers.  
* **Smart Reconnect**: A persistent PowerShell script that automatically detects disconnected tunnels and re-establishes them every 30 seconds.  
* **Real-time API Monitor**: Provides a local API endpoint (http://localhost:8081) to monitor tunnel health and status programmatically.  
* **Uptime Tracking**: Accurate uptime calculation logic based on the oldest active SSH process.  
* **Modern Dashboard**: A clean, responsive web interface (HTML/Tailwind CSS) for visual connection monitoring.

## **📂 File Structure**

| File | Description |
| :---- | :---- |
| database\_tunnel\_optimized.ps1 | Core PowerShell script (Backend/Service). |
| monitor\_tunnel.html | Real-time monitoring dashboard (Frontend). |
| database\_tunnel.log | Activity log and connection history. |

## **🛠️ Getting Started**

### **1\. Prerequisites**

* Windows 10/11 or Windows Server.  
* **OpenSSH Client** feature installed.  
* Administrator Privileges (required to start the API Listener).

### **2\. Configuration**

Open database\_tunnel\_optimized.ps1 and update the core variables (remoteHost, sshUser, sshPort) to match your server environment:

$remoteHost   \= "124.158.152.73" \# Target Server IP  
$sshUser      \= "JSGI\\administrator"  
$sshPort      \= "8022"

## **⚙️ Automating with Task Scheduler**

To ensure the tunnel starts automatically when the server boots (even without user login), follow these steps:

1. Open **Task Scheduler** as Administrator.  
2. Click **Create Task...** (not Basic Task).  
3. **General Tab**:  
   * Name: JSGI\_SSH\_Tunnel\_Service  
   * User Account: Use SYSTEM or an Administrator account.  
   * Select **Run whether user is logged on or not**.  
   * Check **Run with highest privileges**.  
4. **Triggers Tab**:  
   * New... \-\> Begin the task: **At startup**.  
5. **Actions Tab**:  
   * New... \-\> Action: **Start a program**.  
   * Program/script: powershell.exe  
   * Add arguments: \-ExecutionPolicy Bypass \-File "D:\\Portal\\Database\\database\_tunnel\_optimized.ps1"  
6. **Settings Tab**:  
   * Uncheck **Stop the task if it runs longer than...**  
   * If the task fails, restart every: **1 minute**.  
7. **Conditions Tab**:  
   * Uncheck **Start the task only if the computer is on AC power** to ensure the tunnel keeps running if the server/laptop switches to battery/UPS backup.

## **📈 Optimization Details (Hybrid Mode)**

* **AES-GCM Cipher**: Reduces CPU overhead by up to 40% on devices supporting AES-NI instructions.  
* **Compression Disabled**: SSH compression is turned off for pre-compressed files (like .jpg or .zip) to prevent "double compression lag".  
* **QoS Throughput**: Instructs the OS and routers to prioritize large data volumes for stable transfers.

## **📝 Security Notes**

* Ensure your SSH Public Key is registered on the target server's authorized\_keys.  
* Use a firewall to restrict access to the API port (8081).

**Maintained by JSGI IT Section \- 2026**
