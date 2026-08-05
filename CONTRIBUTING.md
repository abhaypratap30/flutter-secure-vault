# Contributing to Vault

Thank you for your interest in contributing to **Vault**! We welcome contributions from the open-source community to improve performance, enhance security, and add new features.

---

## 📜 Code of Conduct

Please help us keep this project open, welcoming, and inclusive:
* Be polite, respectful, and collaborative.
* Focus on constructive feedback and maintain high standards of software quality.

---

## 🛠️ How to Contribute

### 1. Reporting Bugs
* Check existing issues before opening a new one.
* Include a clear description of the bug, steps to reproduce, device details, and relevant console logs.
* **Important**: Do NOT submit security vulnerability reports as public issues. Refer to [SECURITY.md](SECURITY.md) for security disclosures.

### 2. Suggesting Features
* Open an issue outlining the feature request, its use case, and suggested implementation approach.

### 3. Submitting Pull Requests
1. **Fork the Repository**: Create a fork under your GitHub account.
2. **Create a Feature Branch**:
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Follow Flutter & Dart Coding Standards**:
   - Maintain Clean Architecture boundary separation (`data`, `logic`, `presentation`).
   - Run `flutter analyze` to ensure zero linter warnings.
   - Use meaningful variable, function, and class names.
   - Add DartDoc comments for new public APIs and services.
4. **Test Your Changes**: Verify feature behavior on Android/iOS simulators or real hardware.
5. **Submit Pull Request**:
   - Provide a clear PR title and detailed description of the changes.

---

## 🎨 Code Style & Standards

* **Formatting**: Format all Dart code using standard Dart formatter (`dart format .`).
* **State Management**: Use Flutter BLoC (`flutter_bloc`) for business logic and state management.
* **Deprecations**: Ensure no deprecated Flutter APIs are introduced.

Thank you for contributing to Vault! 🚀
