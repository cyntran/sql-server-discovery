Import-Module ./SQLServerDiscovery/SQLServerDiscovery.psm1

$hosts = Get-LiveHosts 
Search-SQLServer -Hosts $hosts
