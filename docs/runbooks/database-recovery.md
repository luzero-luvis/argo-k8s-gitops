# Database recovery

Stop writers, select a verified backup, restore into an isolated target, verify
data consistency, and switch clients only after application-level checks pass.
