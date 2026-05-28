# RansomCTI — Ransomware CTI Collection Engine

> A PowerShell-based CTI engine solely powered by the [ransomware.live](https://ransomware.live) API — collecting victim intelligence, threat actor profiling, MITRE ATT&CK TTPs, IOCs, and YARA rules with automated Excel export for SOC/Detection Engineering pipelines.

**Author:** Kyaw Pyiyt Htet (Mik0yan)  
**Language:** PowerShell 5.1+  
**API Source:** [ransomware.live](https://ransomware.live)

---

## Overview

RansomCTI is a one-stop PowerShell CTI engine designed for threat intelligence analysts, SOC teams, and detection engineers. It leverages the ransomware.live API to collect, normalize, and present ransomware threat intelligence directly from the terminal — and exports structured Excel reports ready for downstream SOC and detection engineering pipelines.

```
ransomware.live API
       ↓
RansomCTI.ps1  ← CTI Collection Engine
       ↓
Terminal Output  ← Analyst consumption
       ↓
.xlsx Report     ← SOC / Detection Engineering pipeline
```

---

## Features

- **Victim Intelligence** — Search victims by keyword, country, or retrieve recent attacks with executive summary (top countries, sectors, threat actors)
- **Threat Actor Profiling** — Full group profile including overview, MITRE ATT&CK TTPs, exploited vulnerabilities, tools & utilities, and dark web infrastructure
- **IOC Harvesting** — Collect indicators across 6 types: `md5`, `sha256`, `ip`, `domain`, `email`, `btc`
- **YARA Rules** — Retrieve YARA detection rules by threat group
- **Excel Export Pipeline** — Automated `.xlsx` report with separated sheets for SOC/Detection Engineering handoff
- **Executive Summary** — Automatic ranking of top threat actors, targeted sectors, and countries

---

# Requirements
- PowerShell 5.1 or later
- ransomware.live API key — ransomware.live
- ImportExcel module (only required for -ExportExcel flag)

# Clone the repository
```
git clone https://github.com/Mikoyan-Dee/RansomCTI.git
cd RansomCTI
```
# Run
```
.\RansomCTI.ps1 -ApiKey <your_api_key> -Mode <mode> [options]
```
### Parameters

| Parameter | Type | Description |
|---|---|---|
| `-ApiKey` | string | **Required.** Your ransomware.live API key |
| `-Mode` | string | **Required.** See modes below |
| `-GroupName` | string | Required for: `yara`, `profile`, `iocs` |
| `-SearchQuery` | string | Required for: `search`, `countrysearch` |
| `-CountryCode` | string | Required for: `countrysearch` (e.g. `TH`, `US`, `UK`) |
| `-IOCType` | string | Required for: `iocs` — one of: `ip`, `md5`, `sha256`, `domain`, `url`, `email`, `btc` |
| `-ExportExcel` | switch | Export group profile to `.xlsx` (requires ImportExcel) |
| `-ShowBanner` | switch | Display the tool banner |

### Modes

| Mode | Description |
|---|---|
| `recent` | Retrieve most recent ransomware victims |
| `search` | Search victims by keyword |
| `countrysearch` | Search victims by keyword and country code |
| `profile` | Full threat actor group profile |
| `iocs` | Retrieve IOCs for a threat group |
| `yara` | Retrieve YARA rules for a threat group |

---

## Examples

```powershell
# Recent ransomware victims
.\RansomCTI.ps1 -ApiKey abc123 -Mode recent

# Search victims by keyword
.\RansomCTI.ps1 -ApiKey abc123 -Mode search -SearchQuery hospital

# Search victims by keyword and country
.\RansomCTI.ps1 -ApiKey abc123 -Mode countrysearch -SearchQuery Manufacturing -CountryCode TH

# Full threat actor profile with Excel export
.\RansomCTI.ps1 -ApiKey abc123 -Mode profile -GroupName qilin -ExportExcel

# Retrieve IP IOCs
.\RansomCTI.ps1 -ApiKey abc123 -Mode iocs -GroupName lockbit -IOCType ip

# Retrieve YARA rules
.\RansomCTI.ps1 -ApiKey abc123 -Mode yara -GroupName blackcat
```

---

## Excel Export

When `-ExportExcel` is used with `-Mode profile`, RansomCTI generates a structured `.xlsx` file named `<groupname>_cti_report.xlsx` containing the following sheets:

| Sheet | Contents |
|---|---|
| **Overview** | Report metadata — group, date, classification, audience |
| **IOCs** | Onion URLs, md5, sha256, ip, domain, email, btc |
| **MITRE TTPs** | Tactic headers with technique IDs and descriptions |
| **Tools & Utilities** | Categorized tools used by the threat group |
| **Exploitation** | Exploited CVEs with vendor, product, CVSS, severity (if available) |

> The Exploitation sheet is only included when vulnerability data is returned by the API.

---

## Disclaimer

This tool is intended for **defensive threat intelligence purposes only**. All data is sourced from the publicly accessible ransomware.live API. The author is not responsible for any misuse of this tool or the data it retrieves.

---

## License

MIT License — free to use, modify, and distribute with attribution.

---

## Excel Export Preview
<img width="859" height="475" alt="image" src="https://github.com/user-attachments/assets/43efdaae-5d98-4ead-828a-2618f6d245b8" />

*Built for the blue team. Powered by ransomware.live.*
