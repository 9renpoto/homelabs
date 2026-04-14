# Security Policy

## Supported branch

Security fixes target the active `main` branch.

This repository is public and contains infrastructure definitions, so do not open a public issue for a suspected secret leak or exploitable configuration problem.

## Reporting a vulnerability

Use GitHub private vulnerability reporting for this repository when it is available.

If private reporting is not available, contact the repository owner privately through GitHub instead of posting details in a public issue or discussion.

Include:

- the affected file or workflow
- the impact you expect
- the steps required to reproduce the issue
- any suggested mitigation or containment step

## Secret handling

Never commit real credentials, tracked `.env` files, Kubernetes `Secret` manifests with real values, VM-local secret files, kubeconfig files, or backup archives.
