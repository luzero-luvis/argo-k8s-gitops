# Secret management

Store only ExternalSecret references in Git. Never commit plaintext credentials.
Rotate exposed values at the upstream secret store before reconciling the fix.
