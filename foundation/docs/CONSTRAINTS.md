# Engineering Constraints

## Critical Constraints
- Preserve behavioral parity
- No API renames without approval
- No workflow changes during stabilization
- No breaking schema changes without migration plan

## Apps Script Constraints
- Use batched writes
- Cache aggressively
- Minimize sheet scans
- LockService required for writes

## Frontend Constraints
- Mobile responsive
- Premium warm aesthetic
- Avoid layout overflow
- Fast loading

## Security Constraints
- Never commit secrets
- Use environment variables
- Server-side validation required
