# Air-Gap Bastion & Staging Host Module

This module provisions an internal, hardened jumpbox / staging host within the private IL6 VPC subnet.

## Highlights
- **No Public IP or Ingress**: Managed exclusively via AWS Systems Manager (SSM) Session Manager without requiring open inbound SSH ports (port 22).
- **FIPS 140-2 / DISA STIG Compliant**: Uses hardened OS AMIs with encrypted EBS volumes.
- **Air-Gap Transfer Utility**: Serves as the high-side staging node for receiving incoming air-gap media, validating Cosign signatures, and running Skopeo / Helm sync scripts to populate the internal Harbor registry.
