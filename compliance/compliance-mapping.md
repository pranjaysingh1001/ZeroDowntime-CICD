# ZeroDowntime-CICD Compliance Mapping

## Project

**Project:** DevOps & Cloud Engineer Zero Downtime CI/CD Pipeline Assessment

**Application:** ZeroDowntime-CICD

**Compliance Frameworks:**

- RBI IT Governance, Risk, Controls and Assurance Practices
- RBI IT / Cyber Security control expectations applicable to the regulated environment
- PCI DSS v4.0.1
- Segregation of Duties (SoD)

---

# 1. Compliance Objective

The ZeroDowntime-CICD pipeline implements automated security, infrastructure,
database migration, deployment and compliance controls.

The objective is to prevent an insecure or non-compliant change from reaching
the deployment stage.

The pipeline follows:

Code
  ↓
Build
  ↓
Test
  ↓
Security Scanning
  ↓
Container Security
  ↓
DAST
  ↓
Contract Testing
  ↓
Compliance Gate
  ↓
Deployment Gate
  ↓
Deployment

A failed mandatory compliance control blocks the pipeline.

---

# 2. RBI Compliance Mapping

| RBI Control Area | Implementation | Evidence |
|---|---|---|
| IT Governance | CI/CD controls are defined and automated | `.github/workflows/` |
| Change Management | Changes pass testing, security scanning and compliance checks before deployment | GitHub Actions workflow |
| Secure Development | Unit tests, contract tests, dependency scanning and DAST are integrated into CI/CD | `.github/workflows/` |
| Vulnerability Management | Dependency and container vulnerability scans are executed | `npm audit`, Trivy |
| Application Security | OWASP ZAP baseline DAST scan is executed | GitHub Actions |
| Access Control | Kubernetes security context and least-privilege controls are checked | `kubernetes/`, `scripts/compliance-check.sh` |
| Auditability | CI/CD execution logs and compliance reports are retained as pipeline artifacts | GitHub Actions / `reports/` |
| Data Migration Controls | Database migrations are versioned and maintained separately from application code | `database/migrations/` |
| Change Recovery | Blue-Green deployment provides rollback capability | `scripts/deploy-blue-green.sh` |
| Business Continuity / Resilience | Blue-Green and Canary strategies reduce deployment interruption risk | `scripts/` and `kubernetes/` |
| Security Testing | Automated SAST/DAST/dependency/container checks are included in CI/CD | GitHub Actions |
| Monitoring | Application health checks are performed before deployment progression | `/health` endpoint |

### RBI implementation note

RBI's IT Governance Directions cover governance, risk, controls,
assurance and business continuity/DR for applicable regulated entities.
The project implements technical CI/CD controls that support these objectives;
it does not claim that the project alone constitutes complete RBI compliance.

---

# 3. PCI DSS v4.0.1 Mapping

| PCI DSS Area | Project Control | Evidence |
|---|---|---|
| Requirement 1 – Network Security Controls | Kubernetes networking and controlled service exposure | `kubernetes/` |
| Requirement 2 – Secure Configuration | Kubernetes security settings and hardened container configuration | `kubernetes/` |
| Requirement 5 – Malware Protection | Container vulnerability scanning | Trivy |
| Requirement 6 – Secure Development | Automated testing and security testing in CI/CD | GitHub Actions |
| Requirement 6 – Vulnerability Management | Dependency vulnerability scanning | `npm audit` |
| Requirement 6 – Security Testing | DAST using OWASP ZAP | `zaproxy/action-baseline` |
| Requirement 6 – Change Control | Deployment only after build, testing and compliance gates | `.github/workflows/` |
| Requirement 7 – Restrict Access | Kubernetes security context and least-privilege configuration | `securityContext` |
| Requirement 8 – Identification / Authentication | Application and infrastructure access is separated from application code | Kubernetes / CI configuration |
| Requirement 10 – Logging and Monitoring | CI/CD execution logs and compliance reports are retained | GitHub Actions / `reports/` |
| Requirement 11 – Security Testing | Automated DAST and vulnerability scanning | OWASP ZAP / Trivy |
| Requirement 12 – Security Policy | Compliance controls and mapping are documented | `compliance/` |

### PCI DSS implementation note

The controls above represent technical controls implemented by this project
that can support PCI DSS requirements.

PCI DSS applicability depends on the organization's cardholder data
environment, scope, architecture and responsibilities. The project does not
claim independent PCI DSS certification.

---

# 4. Segregation of Duties (SoD)

## Objective

No single pipeline stage should be able to bypass the mandatory security
and compliance controls.

The pipeline separates:

1. Build
2. Testing
3. Security validation
4. Compliance validation
5. Deployment authorization

---

## SoD Pipeline Model

```text
Developer Commit
       |
       v
+----------------------+
| Build / Test         |
+----------------------+
       |
       v
+----------------------+
| Security Validation  |
| SAST                 |
| Dependency Scan      |
| Trivy                |
| DAST                 |
+----------------------+
       |
       v
+----------------------+
| Compliance Gate      |
+----------------------+
       |
       | PASS only
       v
+----------------------+
| Deployment Gate      |
+----------------------+
       |
       v
Deployment