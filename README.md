# Mullvad

A Windows batch script for automatically managing Mullvad VPN devices, designed to maintain security by enforcing a maximum device limit (3). The script continuously monitors connected devices, automatically revoking unauthorized devices when the limit is exceeded while preserving a specified authorized device. It includes periodic account verification every 2 hours to ensure the correct account is being used, automatically re-logging if unauthorized access is detected. The script randomly selects unauthorized devices for removal, making it unpredictable for potential attackers.
