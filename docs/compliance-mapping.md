# Compliance Mapping

## PCI DSS

| Control | Pipeline Implementation | Evidence |
|---|---|---|
| Secure software development | SAST | SAST report |
| Vulnerability management | Dependency scanning | Dependency scan report |
| Application security | DAST | DAST report |
| Access control | Kubernetes security checks | Compliance report |
| Auditability | CI/CD logs | GitHub Actions logs |
| Security governance | Compliance policy files | compliance/ |

## RBI

| Control Area | Implementation | Evidence |
|---|---|---|
| Change management | Pull request + CI/CD gate | GitHub Actions |
| Access controls | Kubernetes security context | Compliance report |
| Audit trails | CI/CD and application logs | Logs |
| Security testing | SAST/DAST/scanning | Security reports |
| Data migration controls | Expand-contract migrations | database/migrations |
| Business continuity | Blue-green/canary deployment | Deployment evidence |

## Segregation of Duties

| Control | Implementation | Evidence |
|---|---|---|
| Independent code review | Pull request approval | GitHub |
| Protected main branch | Branch protection | GitHub settings |
| Compliance before deployment | Required CI job | GitHub Actions |
| Emergency changes | Auditable workflow | GitHub logs |