### Written by: Brett Webb
### Date Modified: 22/09/2020
If (!(Get-module "ActiveDirectory")) {
  Import-Module ActiveDirectory -Verbose:$false
}
Write-Host "Please provide the username to search (e.g. DOMAIN\Administrator): " -foregroundcolor Yellow -NoNewline
$UserName = Read-Host 
$list = (Get-ADComputer -Filter {OperatingSystem -like "*Server*"} -Property *).Name | Sort-Object
$online = @()
$offline = @()
$logfilepath = "$env:temp\Log_$(Get-Date -format "dd-MMM-yyyy_HH-mm").CSV"
$htmllogfilepath = "$env:temp\Log_$(Get-Date -format "dd-MMM-yyyy_HH-mm").html"
$VerbosePreference = "continue"
$ErrorActionPreference = "SilentlyContinue"
$domain = Get-ADDomain | Select-Object dnsroot
$css = @"
<style>
h1, h5 { text-align: center; font-family: Arial; }
th { text-align: center; font-family: Arial; }
table { margin: auto; font-family: Segoe UI; box-shadow: 5px 5px 2.5px #888; border: thin ridge grey; }
th { background: #1f7bbe; color: #fff; max-width: 400px; padding: 5px 10px; }
td { font-size: 11px; padding: 5px 20px; color: #000; }
tr { background: #b8d1f3; }
tr:nth-child(even) { background: #dae5f4; }
tr:nth-child(odd) { background: #b8d1f3; }
p { text-align: center; width: 90%; position: relative; margin-left: auto; margin-right: auto; color: gray; font-size: x-small; }
</style>
"@
If ((Test-Path $logfilepath) -eq $True) {
    Clear-Content $logfilepath
}
Add-content -path $logfilepath -Value "Computer Name, Entity Name, Username Used, Type"
foreach ($computername in $list) {
    if (test-connection -computername $computername -quiet -count 1) {
        Write-Host "Scanning $computername..." -foregroundcolor Green
        $online += $computername
        $path = "\\" + $computername + "\c$\Windows\System32\Tasks"
        $tasks = Get-ChildItem -Path $path -File
        #Checking Scheduled Tasks
        foreach ($item in $tasks)
        {
            $AbsolutePath = $path + "\" + $item.Name
            $task = [xml] (Get-Content $AbsolutePath)
            [STRING]$check = $task.Task.Principals.Principal.UserId

            if ($task.Task.Principals.Principal.UserId)
            {
                if ($check -Like $UserName) {
                    Add-content -path $logfilepath -Value "$computername,  $item, $check, Scheduled Task"
                }
            }
        }
        #Checking Services
        $services = Get-WmiObject win32_service -ComputerName $computername -Property * | Where-Object StartName -Like $UserName
        foreach ($service in $services) {
            $sname = $service.Name
            $suser = $service.StartName
            Add-content -path $logfilepath -Value "$computername, $sname, $suser, Service"    
        }
    } else {
    $offline += $computername
    Write-Host "Scanning $computername... Failed." -foregroundcolor Red
    }
}
Import-CSV $logfilepath | ConvertTo-Html -Head $css -Body "<h1>Scheduled Tasks & Services Report</h1>`n<h5>Domain: $($domain.dnsroot)</br>`nGenerated on $(Get-Date)</h5>`n<p><b>Online Servers ($($online.count)):</b> <i>$($online -join ', ').</i></br>`n</br><b>Offline Servers ($($offline.count)):</b> <i>$($offline -join ', ').</i></p>" | Out-File $htmllogfilepath
Invoke-Item $htmllogfilepath