# Architecture — Hybrid Identity Operations Lab

## Infrastructure Diagram

```
┌─────────────────────────────────────────────────────────┐
│                Oracle Cloud Infrastructure               │
│                  US Midwest (Chicago)                    │
│                                                          │
│  VCN: goldenworks-lab-vpn (10.0.0.0/16)                 │
│  Subnet: goldenworks-lab-subnet (10.0.1.0/24)           │
│                                                          │
│  ┌─────────────────────────────────┐                    │
│  │  CORP-DC01                      │                    │
│  │  Windows Server 2022            │                    │
│  │  Private IP: 10.0.1.59          │                    │
│  │  Public IP:  64.181.199.164     │                    │
│  │                                 │                    │
│  │  Roles:                         │                    │
│  │  - Active Directory DS          │                    │
│  │  - DNS Server                   │                    │
│  │  - Windows Event Collector      │                    │
│  └─────────────────────────────────┘                    │
│                                                          │
│  Internet Gateway → Default Route Table → Subnet        │
└─────────────────────────────────────────────────────────┘
              │
              │ RDP (TCP 3389) — restricted to admin IP
              │ SSH (TCP 22)   — restricted to admin IP
              │
┌─────────────────────────┐
│   Admin Workstation     │
│   (Local PC)            │
│   174.171.128.99        │
└─────────────────────────┘
```

## Network Security

### Oracle Security List — Ingress Rules

| Source | Protocol | Port | Purpose |
|---|---|---|---|
| 174.171.128.99/32 | TCP | 3389 | RDP — admin only |
| 174.171.128.99/32 | TCP | 22 | SSH — admin only |
| 10.0.1.0/24 | TCP | All | Internal subnet traffic |
| 0.0.0.0/0 | ICMP | — | Ping and path MTU |

### Oracle Security List — Egress Rules

| Destination | Protocol | Port | Purpose |
|---|---|---|---|
| 0.0.0.0/0 | All | All | Outbound internet access |

## Active Directory Architecture

### OU Design Rationale

The OU hierarchy follows the **role-based OU model** used in enterprise environments:

- **Users OU** — All standard employee accounts. GPOs for user configuration (desktop, drive mapping, software) apply here.
- **Computers OU** — All domain-joined endpoints. GPOs for machine hardening (USB lockdown, firewall) apply here.
- **Groups OU** — All security and distribution groups centralized for easy auditing and delegation.
- **Service Accounts OU** — Non-interactive accounts for services and scheduled tasks. Separate for fine-grained password policy (FGPP) application.
- **Admins OU** — Privileged admin accounts only. Separate from Users OU to enforce Tier 0 isolation.
- **Disabled OU** — Landing zone for offboarded accounts. Retained for 90 days before deletion per data retention policy.

### Identity Tiers

| Tier | Accounts | Access Scope |
|---|---|---|
| Tier 0 | admin-jwilson, Administrator | Domain controllers, AD administration |
| Tier 1 | jwilson, jsmith | Member servers, IT systems |
| Tier 2 | mgarcia, sjohnson, dlee | Workstations, standard business applications |

### Authentication Flow

```
User logs in
    │
    ▼
Kerberos AS-REQ → CORP-DC01 (KDC)
    │
    ▼
Password hash validated against AD
    │
    ▼
TGT issued → User accesses resources via service tickets
    │
    ▼
Logon event 4624 written to Security log
    │
    ▼
GW-SecurityMonitor.ps1 picks up event in next run
```

## Automation Architecture

```
Ticket / Request
    │
    ▼
New-GWUser.ps1          ← Onboarding
    │  Creates AD user
    │  Assigns to dept group
    │  Assigns to VPN group
    │  Forces password reset
    ▼
User Active in AD

Offboard Request
    │
    ▼
Remove-GWUser.ps1       ← Offboarding
    │  Disables account
    │  Strips all groups
    │  Moves to Disabled OU
    │  Renames with ticket number
    ▼
Account in Disabled OU (retained 90 days)

Scheduled / On-Demand
    │
    ▼
GW-AccessReview.ps1     ← Governance
    │  Stale account detection
    │  Never-logged-in detection
    │  Disabled-with-groups detection
    │  Exports CSV report
    ▼
GW-Remediate-DisabledGroups.ps1  ← Remediation
    │  Auto-removes groups from disabled accounts
    │  Excludes sensitive built-ins
    ▼
GW-SecurityMonitor.ps1  ← Monitoring
    │  Queries last 24h Security log
    │  Surfaces key event IDs
    │  Exports CSV report
    ▼
Reports in C:\GoldenWorks\Reports\
```

## Lessons Learned / Troubleshooting Log

This section documents real issues encountered during lab build — the kind of
operational knowledge that only comes from hands-on work.

| Issue | Root Cause | Resolution |
|---|---|---|
| RDP unreachable from internet | No default route rule in OCI Route Table | Added 0.0.0.0/0 → Internet Gateway route |
| VM had no internet access | Missing egress rule in OCI Security List | Added allow-all egress rule |
| RDP listener not responding | Missing RDP-Tcp registry key | Recreated via reg add and Set-ItemProperty |
| Domain promotion failed | Local Administrator password was blank | Set strong password via net user before promoting |
| Onboarding script password rejected | GPO enforced 14-char minimum; script used 12-char default | Updated default password in script to meet policy |
| VNC console fingerprint mismatch | Console connection regenerated new host key | Cleared PuTTY host key cache, re-accepted fingerprint |

> These are not failures — they are the operational signal that the environment
> is behaving like a real enterprise system. Each issue required diagnosis,
> root cause identification, and a documented fix.
