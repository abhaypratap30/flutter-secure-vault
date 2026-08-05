# Security Policy

## 🛡️ Overview

**Vault** is designed with security and privacy as core priorities. The application employs AES-256 CBC encryption, SHA-256 PIN hashing, hardware-backed secure key storage, dual-vault session isolation, and stealth features.

---

## 🔒 Security Principles

1. **On-Device Cryptography**:
   - All photos, videos, and text notes are encrypted locally before persistent storage.
   - Symmetric keys are derived dynamically using SHA-256 from passcodes.

2. **Session Isolation**:
   - Master and Decoy vault environments use isolated directories and independent metadata manifests.

3. **Key Management**:
   - Encryption keys are kept strictly in ephemeral RAM and purged immediately upon locking the vault.
   - Master PINs stored for biometric unlock use platform-level hardware keychains via `FlutterSecureStorage`.

---

## 🚨 Reporting Vulnerabilities

If you discover a security vulnerability or potential threat in Vault:

1. **Do NOT report security vulnerabilities via public GitHub issues.**
2. Please disclose vulnerabilities responsibly by contacting the maintainer via private message or email.
3. Provide a detailed description of the issue, vulnerability vector, and proof-of-concept steps.

We appreciate your effort in helping keep Vault secure for the community!
