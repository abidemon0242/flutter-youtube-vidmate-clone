# Security Policy

## Supported status

Tube Arena is under active development. There is no production support or guaranteed response-time commitment.

## Reporting a vulnerability

Please do not publish credentials, private data, or a working exploit in a public issue.

If GitHub's **Private vulnerability reporting** option is enabled for this repository, use the repository Security tab to submit a private report. Otherwise, contact the repository owner through a private GitHub communication channel and include:

- A concise description of the affected component.
- The impact and conditions needed to reproduce the issue.
- A safe proof of concept that does not access other people's data.
- Any suggested mitigation.

Do not include API keys, passwords, signing keys, session cookies, or other secrets in the report.

## Secret handling

Never commit credentials or private configuration. If a secret is accidentally exposed, revoke or rotate it immediately and remove it from active use; deleting it from the latest commit alone is not sufficient.
