# Contributing

1. Create a focused branch and keep each change within one ownership boundary.
2. Follow the component convention documented in `README.md`.
3. Pin deployable versions; do not use `latest` image tags.
4. Run `./scripts/validate.sh` locally.
5. Describe rollout and rollback considerations in the pull request.

Changes flow through Git. Do not mutate Argo CD-managed resources directly in a
cluster except during a documented incident response.
