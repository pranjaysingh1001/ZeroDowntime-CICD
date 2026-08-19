# ZeroDowntime-CICD

A production-oriented CI/CD pipeline designed for secure, controlled and
zero-downtime application deployments.

This project was built as part of the **DevOps & Cloud Engineer Zero Downtime
CI/CD Pipeline Assessment** for **ZeTheta Algorithms Private Limited**.

The main goal of the project is not just to automate deployment, but to make
sure that code passes testing, security and compliance checks before it is
allowed to move towards deployment.

---

## Project Overview

The pipeline follows a gated CI/CD approach:

                         GitHub Repository
                                |
                                v
                       +------------------+
                       | GitHub Actions   |
                       +--------+---------+
                                |
                 +--------------+--------------+
                 |              |              |
                 v              v              v
              Build          Security        Tests
                 |              |              |
                 +--------------+--------------+
                                |
                                v
                         Compliance Gate
                                |
                       +--------+--------+
                       |                 |
                     FAIL               PASS
                       |                 |
                      STOP               v
                                  Deployment Gate
                                         |
                                  +------+------+
                                  |             |
                                  v             v
                              Blue-Green      Canary
                                  |             |
                                  +------+------+
                                         |
                                         v
                                  Health Checks
                                         |
                                  +------+------+
                                  |             |
                                PASS           FAIL
                                  |             |
                                  v             v
                               Release       Rollback