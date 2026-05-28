param(
    [string]$ApiKey,
    [string]$Mode,
    [string]$GroupName,
    [string]$SearchQuery,
	[string]$CountryCode,

    [AllowNull()]
    [AllowEmptyString()]
    [ValidateScript({
        if ($_ -and $_ -notin @("ip","md5", "sha256", "domain","url", "email", "btc")) {
            throw "IOCType must be one of: ip, md5, sha256, domain, url, email, btc"
        }
        return $true
    })]
    [string]$IOCType,

    [switch]$ShowBanner,
	[switch]$ExportExcel
)

# =========================
# Help / Usage Banner
# =========================
function Show-Help {
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "   CTI RANSOMWARE INTELLIGENCE COLLECTOR" -ForegroundColor Yellow
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host " Author : Kyaw Pyiyt Htet (Mik0yan)" -ForegroundColor White
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " USAGE:" -ForegroundColor Green
    Write-Host "   .\script.ps1 -ApiKey <key> -Mode <mode> [options]"
    Write-Host ""
    Write-Host " REQUIRED PARAMETERS:" -ForegroundColor Yellow
    Write-Host "   -ApiKey      <string>    Your ransomware.live API key"
    Write-Host "   -Mode        <string>    One of: yara | profile | iocs | search | countrysearch | recent"
    Write-Host ""
    Write-Host " OPTIONAL PARAMETERS:" -ForegroundColor Cyan
    Write-Host "   -GroupName   <string>    Required for modes: yara, profile, iocs"
    Write-Host "   -SearchQuery <string>    Required for mode:  search"
	Write-Host "   -CountryCode <string>    Required for Country Code: UK (United Kingdom), TH (Thailand)"
    Write-Host "   -IOCType     <string>    Required for mode:  iocs"
    Write-Host "                            One of: ip | md5 | sha256 | domain | url | email | btc"
    Write-Host "   -ShowBanner              Display the tool banner"
    Write-Host ""
    Write-Host " EXAMPLES:" -ForegroundColor Green
    Write-Host "   .\RansomCTI.ps1 -ApiKey abc123 -Mode recent"
    Write-Host "   .\RansomCTI.ps1 -ApiKey abc123 -Mode iocs -GroupName lockbit -IOCType ip"
    Write-Host "   .\RansomCTI.ps1 -ApiKey abc123 -Mode search -SearchQuery hospital"
	Write-Host "   .\RansomCTI.ps1 -ApiKey abc123 -Mode countrysearch -SearchQuery Manufacturing -CountryCode US"
    Write-Host "   .\RansomCTI.ps1 -ApiKey abc123 -Mode yara -GroupName blackcat"
	Write-Host "   .\RansomCTI.ps1 -ApiKey abc123 -Mode profile -GroupName qilin -ExportExcel"
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
}

# =========================
# Banner
# =========================
function Show-Banner {
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "   CTI RANSOMWARE INTELLIGENCE COLLECTOR" -ForegroundColor Yellow
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host " Author : Kyaw Pyiyt Htet (Mik0yan)"
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
}

# =========================
# Parameter Display
# =========================
function Show-Parameters {
    $displayGroup   = if ($GroupName)    { $GroupName }    else { "N/A" }
    $displaySearch  = if ($SearchQuery)  { $SearchQuery }  else { "N/A" }
    $displayIOC     = if ($IOCType)      { $IOCType }      else { "N/A" }
    $displayCountry = if ($CountryCode)  { $CountryCode }  else { "N/A" }   

    Write-Host "[+] Execution Parameters" -ForegroundColor Green
    Write-Host "---------------------------------------------"
    Write-Host ("Mode         : {0}" -f $Mode)
    Write-Host ("Group Name   : {0}" -f $displayGroup)
    Write-Host ("Search Query : {0}" -f $displaySearch)
    Write-Host ("Country Code : {0}" -f $displayCountry)                  
    Write-Host ("IOC Type     : {0}" -f $displayIOC)
    Write-Host "---------------------------------------------"
    Write-Host ""
}
# =========================
# Output Formatter
# =========================
function Format-Results {
    param([object]$Data)

    switch ($Mode) {
        "recent" { Format-Victims $Data }
        "search" { Format-Victims $Data }
		"countrysearch" { Format-Victims $Data }
        "profile" { Format-Group $Data }
        "iocs"   { Format-IOCs $Data }
        "yara"   { Format-Yara $Data }
    }
}

function Format-Victims {
    param([object]$Data)

    $victims = if ($Data.victims) { $Data.victims } else { @($Data) }
    $total   = if ($Data.count)   { $Data.count }   else { $victims.Count }

    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "   RANSOMWARE VICTIM INTELLIGENCE REPORT"     -ForegroundColor Yellow
    Write-Host ("   Generated     : {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor Gray
    Write-Host ("   Total Records : {0}" -f $total)           -ForegroundColor Gray
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""

    #Summary 
    Write-Host " EXECUTIVE SUMMARY" -ForegroundColor Yellow
    Write-Host "---------------------------------------------"

    $byCountry = $victims | Where-Object { $_.country } | Group-Object country  | Sort-Object Count -Descending | Select-Object -First 5
    $bySector  = $victims | Where-Object { $_.activity } | Group-Object activity | Sort-Object Count -Descending | Select-Object -First 5
    $byGroup = $victims | Where-Object { $_.group_name } | Group-Object group_name | Sort-Object Count -Descending | Select-Object -First 5

    Write-Host " Top Targeted Countries:" -ForegroundColor Cyan
    $byCountry | ForEach-Object {
        Write-Host ("   {0,-6} ({1} victims)" -f $_.Name, $_.Count) -ForegroundColor White
    }

    Write-Host ""
    Write-Host " Top Targeted Sectors:" -ForegroundColor Cyan
    $bySector | ForEach-Object {
        Write-Host ("   {0,-25} [{1} victims]" -f $_.Name, $_.Count) -ForegroundColor White
    }

    Write-Host ""
    Write-Host " Most Active Threat Actors:" -ForegroundColor Cyan
    $byGroup | ForEach-Object {
        $rank      = [array]::IndexOf($byGroup, $_) + 1
        $bar       = "#" * $_.Count
        $rankColor = switch ($rank) {
            1       { "Red" }
            2       { "DarkRed" }
            3       { "Yellow" }
            default { "White" }
        }
        Write-Host ("   #{0} {1,-25} {2,-5} attacks  {3}" -f `
            $rank, $_.Name, $_.Count, $bar) -ForegroundColor $rankColor
    }

    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host " VICTIM DETAILS"                              -ForegroundColor Yellow
    Write-Host "=============================================" -ForegroundColor Cyan

    $index = 1
    foreach ($v in $victims) {

        #Null-safe field extraction
        $victimName  = if ($v.post_title)  { $v.post_title }  else { "Unknown" }
        $group       = if ($v.group_name)       { $v.group_name }       else { "Unknown" }
        $country     = if ($v.country)     { $v.country }     else { "Unknown" }
        $sector      = if ($v.activity)    { $v.activity }    else { "Unknown" }
        $website     = if ($v.website)     { $v.website }     else { "N/A" }
        $permalink   = if ($v.permalink)   { $v.permalink }   else { "N/A" }
        $ransom      = if ($v.ransom)      { "$" + $v.ransom } else { "Undisclosed" }
        $dataSize    = if ($v.data_size)   { $v.data_size }   else { "Undisclosed" }
		$postUrl     = if ($v.post_url)    { $v.post_url }    else { "N/A" }


        $discoveredDate = "Unknown"
        if ($v.discovered) {
            try { $discoveredDate = ([datetime]$v.discovered).ToString("yyyy-MM-dd HH:mm") } catch {}
        }

        #Description 
        $description = "No description available"
        if ($v.description -and $v.description -ne "N/A") {
            $words = $v.description.Trim() -split '\s+'
            $lines = @(); $line = ""
            foreach ($word in $words) {
                if (("$line $word").Trim().Length -gt 80) { $lines += $line.Trim(); $line = $word }
                else { $line = "$line $word" }
            }
            if ($line.Trim()) { $lines += $line.Trim() }
            $description = $lines -join "`n                   "
        }
        Write-Host ""
        Write-Host (" [{0:D3}] {1}" -f $index, $victimName.ToUpper()) -ForegroundColor Yellow
        Write-Host "---------------------------------------------"
        Write-Host ("  Threat Actor   : {0}" -f $group)         -ForegroundColor Red
        Write-Host ("  Discovered     : {0}" -f $discoveredDate) -ForegroundColor White
        Write-Host ("  Country        : {0}" -f $country)        -ForegroundColor White
        Write-Host ("  Sector         : {0}" -f $sector)         -ForegroundColor White
        Write-Host ("  Website        : {0}" -f $website)        -ForegroundColor Gray
        Write-Host ("  Ransom Demand  : {0}" -f $ransom)         -ForegroundColor Magenta
        Write-Host ("  Data Size      : {0}" -f $dataSize)       -ForegroundColor Magenta
		Write-Host ("  Onion URL      : {0}" -f $postUrl)      -ForegroundColor DarkGray
        Write-Host ("  Description    : {0}" -f $description)    -ForegroundColor Gray
        Write-Host ("  Permalink      : {0}" -f $permalink)      -ForegroundColor DarkCyan

        #Infostealer — only show if data exists
        if ($v.infostealer -and $v.infostealer -is [PSCustomObject]) {
            $emp = $v.infostealer.employees
            $usr = $v.infostealer.users
            if ($emp -gt 0 -or $usr -gt 0) {
                Write-Host ("  Infostealer    : Employees={0}  Users={1}" -f $emp, $usr) -ForegroundColor Yellow
            }
        }

        Write-Host "---------------------------------------------"
        $index++
    }

    Write-Host ""
    Write-Host " END OF REPORT" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Format-IOCs {
    param([object]$Data)
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ("   IOC REPORT - Type: {0}" -f $IOCType.ToUpper()) -ForegroundColor Yellow
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    if ($Data -is [System.Array] -and $Data.Count -gt 0) {
        Write-Host (" Total IOCs : {0}" -f $Data.Count) -ForegroundColor Gray
        Write-Host ""
        $Data | ForEach-Object { Write-Host ("  [IOC] {0}" -f $_) -ForegroundColor Red }
    } else {
        Write-Host "  No IOCs returned." -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
}

# =============================================================================
# EXCEL EXPORT  (Pure PowerShell — requires ImportExcel module)
# Install once: Install-Module ImportExcel -Scope CurrentUser
# =============================================================================
function Export-GroupToExcel {
    param([object]$Data, [string]$GName)

    #Check ImportExcel module
    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        Write-Host "[!] ImportExcel module not found." -ForegroundColor Red
        Write-Host "    Run: Install-Module ImportExcel -Scope CurrentUser" -ForegroundColor Yellow
        return
    }
    Import-Module ImportExcel -ErrorAction Stop

    $outFile    = ".\${GName}_cti_report.xlsx"
    $reportDate = (Get-Date -Format 'yyyy-MM-dd')
	
    Write-Host ""
    Write-Host "[+] Collecting all IOC types for Excel export..." -ForegroundColor Cyan

    #Fetch all IOC types from API
    $iocRows = @()

    # Onion URLs from locations
    $locations = if ($Data.locations) { $Data.locations } else { @() }
	foreach ($loc in $locations) {
        $iocRows += [PSCustomObject]@{
            "IOC Type"  = "Onion URL"
            "Indicator" = $loc.fqdn
            "Source"    = "Group Infrastructure"
            "Notes"     = "Type: $($loc.type) | Status: $(if ($loc.available) { 'LIVE' } else { 'DOWN' })"
        }
    }

    #Fetch md5, sha256, ip, domain, email, btc from API
    foreach ($type in @("md5","sha256","ip","domain","email","btc")) {
        try {
            $uri  = "https://api-pro.ransomware.live/iocs/$GName`?type=$type"
            $r    = Invoke-RestMethod -Uri $uri -Headers @{ "X-Api-Key" = $ApiKey } -Method GET -ErrorAction Stop
            $list = $r.iocs.$type
            if ($list -and $list.Count -gt 0) {
                foreach ($val in $list) {
                    if ($val) {
                        $iocRows += [PSCustomObject]@{
                            "IOC Type"  = $type.ToUpper()
                            "Indicator" = $val
                            "Source"    = "Threat Intel Feed"
                            "Notes"     = ""
                        }
                    }
                }
                Write-Host ("    [{0,-8}] {1} indicator(s)" -f $type.ToUpper(), $list.Count) -ForegroundColor DarkGray
            } else {
                Write-Host ("    [{0,-8}] No data" -f $type.ToUpper()) -ForegroundColor DarkGray
            }
        } catch {}
    }

    #Build MITRE TTPs rows
    $ttpRows = @()
    $ttpList = if ($Data.ttps) { $Data.ttps } else { @() }
	foreach ($tactic in $ttpList) {
        # Tactic header row
        $ttpRows += [PSCustomObject]@{
            "MITRE ID"    = "[$($tactic.tactic_id)] $($tactic.tactic_name)"
            "Description" = ""
        }
        $techList = if ($tactic.techniques) { $tactic.techniques } else { @() }
		foreach ($tech in $techList) {
            $ttpRows += [PSCustomObject]@{
                "MITRE ID"    = $tech.technique_id
                "Description" = if ($tech.technique_details) { $tech.technique_details } else { $tech.technique_name }
            }
        }
    }

    #Build Tools rows
    $toolRows = @()
    if ($Data.tools) {
        $Data.tools.PSObject.Properties | ForEach-Object {
            $category = $_.Name
            $_.Value  | ForEach-Object {
                $toolName  = if ($_ -is [string]) { $_ } else { $_.name }
                $toolRows += [PSCustomObject]@{
                    "Category"  = $category
                    "Tool Name" = $toolName
                    "Notes"     = ""
                }
            }
        }
    }
	
	
	#Build Exploitation rows (optional — only if data exists)
    $vulnRows = @()
    if ($Data.vulnerabilities) {
        foreach ($vuln in $Data.vulnerabilities) {
            $vulnRows += [PSCustomObject]@{
                "Vendor"   = $vuln.Vendor
                "Product"  = $vuln.Product
                "CVE"      = $vuln.CVE
                "CVSS"     = $vuln.CVSS
                "Severity" = $vuln.severity
            }
        }
    }

    
	$sheetList = "Overview | IOCs | MITRE TTPs | Tools & Utilities"
    if ($vulnRows.Count -gt 0) { $sheetList += " | Exploitation" }
	
	#Overview data
    $overviewRows = @(
        [PSCustomObject]@{ "Field" = "Threat Group";   "Value" = $GName.ToUpper() }
        [PSCustomObject]@{ "Field" = "Report Date";    "Value" = $reportDate }
        [PSCustomObject]@{ "Field" = "Sheets";         "Value" = $sheetList }
        [PSCustomObject]@{ "Field" = "Audience";       "Value" = "CTI / SOC / Detection Engineering" }
    )

    #Write all sheets
    Write-Host "[+] Generating Excel report..." -ForegroundColor Cyan

    $overviewRows | Export-Excel -Path $outFile -WorksheetName "Overview"          -AutoSize -FreezeTopRow -BoldTopRow -ClearSheet
    $iocRows      | Export-Excel -Path $outFile -WorksheetName "IOCs"              -AutoSize -FreezeTopRow -BoldTopRow
    $ttpRows      | Export-Excel -Path $outFile -WorksheetName "MITRE TTPs"        -AutoSize -FreezeTopRow -BoldTopRow
    $toolRows     | Export-Excel -Path $outFile -WorksheetName "Tools & Utilities" -AutoSize -FreezeTopRow -BoldTopRow
	if ($vulnRows.Count -gt 0) {
        $vulnRows | Export-Excel -Path $outFile -WorksheetName "Exploitation" -AutoSize -FreezeTopRow -BoldTopRow
    }
	
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host " EXCEL EXPORT COMPLETE"                        -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ("  File     : {0}" -f $outFile)                -ForegroundColor Yellow
    Write-Host ("  Group    : {0}" -f $GName.ToUpper())        -ForegroundColor White
    Write-Host ("  Date     : {0}" -f $reportDate)             -ForegroundColor White
    Write-Host ("  Sheets   : {0}" -f $sheetList)              -ForegroundColor White
    Write-Host "  Audience : SOC / Detection Engineering"      -ForegroundColor White
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Format-Group {
    param([object]$Data)

    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ("   GROUP PROFILE - {0}" -f $GroupName.ToUpper()) -ForegroundColor Yellow
    Write-Host "=============================================" -ForegroundColor Cyan

    # --- Basic Info ---
    Write-Host ""
    Write-Host " GROUP OVERVIEW" -ForegroundColor Yellow
    Write-Host "---------------------------------------------"
    if ($Data.name)        { Write-Host ("  Name         : {0}" -f $Data.name) }
    if ($Data.also_known)  { Write-Host ("  Also Known   : {0}" -f ($Data.also_known -join ", ")) }
    if ($Data.country)     { Write-Host ("  Origin       : {0}" -f $Data.country) }
    if ($Data.first_seen)  { Write-Host ("  First Seen   : {0}" -f $Data.first_seen) }	
	if ($Data.description) {
    $cleanDesc = $Data.description -replace '<br\s*/?>', "`n" -replace '(?i)<br\s*/?>', "`n"
    Write-Host ("  Description  : {0}" -f $cleanDesc)
}

    # --- TTPs ---
    if ($Data.ttps) {
        Write-Host ""
        Write-Host " MITRE ATT&CK TTPs" -ForegroundColor Yellow
        Write-Host "---------------------------------------------"

        foreach ($tactic in $Data.ttps) {
            Write-Host ""
            Write-Host ("  [{0}] {1}" -f $tactic.tactic_id, $tactic.tactic_name) -ForegroundColor Cyan

            foreach ($technique in $tactic.techniques) {
                Write-Host ("    - [{0}] {1}" -f $technique.technique_id, $technique.technique_name) -ForegroundColor White
                if ($technique.technique_details) {
                    Write-Host ("        > {0}" -f $technique.technique_details) -ForegroundColor Gray
                }
            }
        }
    }

    # --- Vulnerabilities ---
    if ($Data.vulnerabilities) {
        Write-Host ""
        Write-Host " EXPLOITED VULNERABILITIES" -ForegroundColor Yellow
        Write-Host "---------------------------------------------"
        Write-Host ("  {0,-20} {1,-20} {2,-18} {3,-6} {4}" -f "Vendor","Product","CVE","CVSS","Severity")
        Write-Host "  $(('-' * 80))"

        foreach ($vuln in $Data.vulnerabilities) {
            $severityColor = switch ($vuln.severity) {
                "CRITICAL" { "Red" }
                "HIGH"     { "DarkRed" }
                "MEDIUM"   { "Yellow" }
                "LOW"      { "Gray" }
                default    { "White" }
            }
            Write-Host ("  {0,-20} {1,-20} {2,-18} {3,-6} {4}" -f `
                $vuln.Vendor, $vuln.Product, $vuln.CVE, $vuln.CVSS, $vuln.severity) `
                -ForegroundColor $severityColor
        }
    }

    # --- Tools ---
    if ($Data.tools) {
        Write-Host ""
        Write-Host " TOOLS & UTILITIES" -ForegroundColor Yellow
        Write-Host "---------------------------------------------"

        $Data.tools.PSObject.Properties | ForEach-Object {
            $category  = $_.Name
            $toolList  = $_.Value

            if ($toolList -and $toolList.Count -gt 0) {
                Write-Host ("  [{0}]" -f $category) -ForegroundColor Cyan
                $toolList | ForEach-Object {
                    $toolName = if ($_.name) { $_.name } else { $_ }
                    Write-Host ("    - {0}" -f $toolName) -ForegroundColor White
                }
            }
        }
    }
	
	
	# --- Onion Locations ---
    if ($Data.locations) {
        Write-Host ""
        Write-Host " KNOWN INFRASTRUCTURE / ONION LOCATIONS" -ForegroundColor Yellow
        Write-Host "---------------------------------------------"
        Write-Host ("  {0,-8} {1,-12} {2}" -f "Status","Type","FQDN")
        Write-Host "  $(('-' * 80))"

        foreach ($loc in $Data.locations) {

            # Availability color
            $availColor = if ($loc.available) { "Green" } else { "DarkGray" }
            $availLabel = if ($loc.available) { "[LIVE]" } else { "[DOWN]" }

            # Type color
            $typeColor = switch ($loc.type) {
                "Chat" { "Cyan" }
                "DLS"  { "Red" }        # Data Leak Site
                "Blog" { "Magenta" }
                default { "White" }
            }

            Write-Host ("  {0,-8}" -f $availLabel) -ForegroundColor $availColor -NoNewline
            Write-Host ("{0,-12}" -f $loc.type)     -ForegroundColor $typeColor  -NoNewline
            Write-Host ("{0}" -f $loc.fqdn)         -ForegroundColor DarkCyan

        }
    }
	
	#Excel Export (if flag set)
    if ($ExportExcel) {
        Export-GroupToExcel -Data $Data -GName $GroupName
    }

    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host " END OF GROUP PROFILE" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Format-Yara {
    param([object]$Data)

    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ("   YARA RULES - {0}" -f $GroupName.ToUpper()) -ForegroundColor Yellow
    Write-Host ("   Total Rules : {0}" -f $Data.count)         -ForegroundColor Gray
    Write-Host "=============================================" -ForegroundColor Cyan

    foreach ($rule in $Data.rules) {
        Write-Host ""
        Write-Host ("  File : {0}" -f $rule.filename) -ForegroundColor Yellow
        Write-Host "---------------------------------------------"
        Write-Host $rule.content -ForegroundColor Green
        Write-Host "---------------------------------------------"
    }

    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host " END OF YARA RULES" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
}

# =========================
# Validation Layer
# =========================
function Validate-Inputs {
    switch ($Mode) {
        "yara"    { if (-not $GroupName) { throw "GroupName required for yara" } }
        "profile" { if (-not $GroupName) { throw "GroupName required for profile" } }
        "iocs" {
            if (-not $GroupName -or -not $IOCType) {
                throw "GroupName + IOCType required for iocs"
            }
        }
        "search" {
            if (-not $SearchQuery) {
                throw "SearchQuery required for search"
            }
        }                                                 
        "countrysearch" {
            if (-not $SearchQuery -or -not $CountryCode) {
                throw "SearchQuery + CountryCode required for countrysearch"
            }
        }
    }
}

# =========================
# Core CTI Function
# =========================
function Invoke-RansomCTI {
    $baseUrl = "https://api-pro.ransomware.live"
    $headers = @{ "X-Api-Key" = $ApiKey }

    switch ($Mode) {
    "yara"          { $uri = "$baseUrl/yara/$($GroupName)" }
    "profile"       { $uri = "$baseUrl/groups/$($GroupName)" }
    "iocs"          { $uri = "$baseUrl/iocs/$($GroupName)?type=$($IOCType)" }
    "search"        { $uri = "$baseUrl/victims/search?q=$($SearchQuery)" }
    "countrysearch" { $uri = "$baseUrl/victims/search?q=$($SearchQuery)&country=$($CountryCode)" }
    "recent"        { $uri = "$baseUrl/victims/recent" }
}
    

    Write-Host "[+] Querying API..." -ForegroundColor Cyan
    Write-Host "[+] URI: $uri" -ForegroundColor DarkGray
    Write-Host ""

    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET

    if ($Mode -eq "iocs") {
        switch ($IOCType) {
			#ip | md5 | sha256 | domain | url | email | btc
            "md5"    { return $response.iocs.md5 }
			"sha256" { return $response.iocs.sha256}
            "ip"     { return $response.iocs.ip }
            "domain" { return $response.iocs.domain }
            "url"    { return $response.iocs.url }
			"email"  { return $response.iocs.email}
			"btc"    { return $response.iocs.btc}
        }
    }

    return $response
}

# =========================
# Execution Flow
# =========================

#No args -> show help and exit
if ($PSBoundParameters.Count -eq 0) {
    Show-Help
    exit 0
}

#Validate required: ApiKey
if (-not $ApiKey) {
    Write-Host "[!] Missing required parameter: -ApiKey" -ForegroundColor Red
    Write-Host ""
    Show-Help
    exit 1
}

#Validate required: Mode
if (-not $Mode) {
    Write-Host "[!] Missing required parameter: -Mode" -ForegroundColor Red
    Write-Host ""
    Show-Help
    exit 1
}

#Validate Mode value
$validModes = @("yara","profile","iocs","search","countrysearch","recent")
if ($Mode -notin $validModes) {
    Write-Host "[!] Invalid Mode '$Mode'. Must be one of: yara | profile | iocs | search | recent" -ForegroundColor Red
    exit 1
}

#Run
if ($ShowBanner) { Show-Banner }
Show-Parameters

try {
    Validate-Inputs
    $result = Invoke-RansomCTI
    if ($result) {
        Format-Results $result        
    }
} catch {
    Write-Host "[!] Error: $_" -ForegroundColor Red
}