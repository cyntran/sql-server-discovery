function Get-LiveHosts {
  [OutputType([System.Collections.ArrayList])]
  $liveHosts = [System.Collections.ArrayList]::new()
  
  # There are currently five servers assigned IPs in 192.168.100.0/24
  # To scan for all of them instead, change range to 1..254
  10..15 | ForEach-Object {
    $ip = "192.168.100.$_"
    if (Test-Connection -ComputerName $ip -Count 1 -Quiet) {
      $liveHosts.Add("$ip") | Out-Null
    }
  }

  Write-Host "List of live hosts $($liveHosts -join ', ')"
  return $liveHosts
}


function Search-SQLServer {
  param(
    [Parameter(Mandatory)]
    [System.Collections.ArrayList]$Hosts
  )

  Write-Host "Searching for SQL servers"

  foreach ($ip in $Hosts) {
    Get-DNSName -IP $ip

    try {
      # Get all the services in the server with the name 'MSSQL*', default or named
      $sqlServices = Get-Service -ComputerName $ip -Name 'MSSQL*' -ErrorAction Stop

      foreach ($serv in $sqlServices) {
        $serverInstance = "" 

        # Gets details for both the default and named instances
        if ($serv.Name -eq 'MSSQLSERVER') {
          $serverInstance = $ip
        }
        else {
          $instanceName = $serv.Name -replace '^MSSQL\$', ''
          $serverInstance = "$ip\$instanceName"
        }

        Write-Host "$serverInstance is running instance an instance of SQL Server"
        Get-ServerInstanceDetails -ServerInstance $serverInstance
      }
    }
    catch {
      Write-Host "$ip is not running SQL Server"
    }
  }
}

function Get-DNSName {
  param(
    [string]$IP
  )

  try {
    $dnsName = [System.Net.Dns]::GetHostEntry($ip).HostName
    Write-Host "$IP -> $dnsName"
  }
  catch {
    Write-Host "$IP -> No DNS entry found"
  }
} 

. .\Credentials.ps1 # Import $username and $password

function Get-ServerInstanceDetails {
  param(
    [Parameter(Mandatory)]
    [string]$ServerInstance
  )

  Write-Host "`n================= [$ServerInstance] SERVER DETAILS =================" -ForegroundColor Cyan

  Write-Host "`nDatabases:" -ForegroundColor Yellow
  Invoke-Sqlcmd -ServerInstance $ServerInstance `
    -Username $username -Password $password `
    -Query "SELECT name FROM sys.databases;" `
    -TrustServerCertificate | Format-Table -AutoSize 

  # todo: include server version
  Write-Host "`nServer Name:" -ForegroundColor Yellow
  Invoke-Sqlcmd -ServerInstance $ServerInstance `
    -Username $username -Password $password `
    -Query "SELECT @@SERVERNAME AS ServerName;" `
    -TrustServerCertificate | Format-Table -AutoSize

  Write-Host "`nSQL Instance Name:" -ForegroundColor Yellow
  Invoke-Sqlcmd -ServerInstance $ServerInstance `
    -Username $username -Password $password  `
    -Query "SELECT @@SERVICENAME AS SqlInstanceName;" `
    -TrustServerCertificate | Format-Table -AutoSize

  Write-Host "`nDisk Free Space (MB):" -ForegroundColor Yellow
  Invoke-Sqlcmd -ServerInstance $ServerInstance `
    -Username $username -Password $password `
    -Query "EXEC xp_fixeddrives;" `
    -TrustServerCertificate | Format-Table -AutoSize 

  Write-Host "`nServer Configurations:" -ForegroundColor Yellow
  Invoke-Sqlcmd -ServerInstance $ServerInstance `
    -Username $username -Password $password `
    -Query "SELECT name, value, value_in_use, description FROM sys.configurations ORDER BY name;" `
    -TrustServerCertificate | Format-Table -Wrap -AutoSize 
}

