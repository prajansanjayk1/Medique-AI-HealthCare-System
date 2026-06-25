# Contributing to MediQue

Thank you for considering contributing to MediQue! We welcome contributions from the community, whether they are bug reports, feature requests, documentation improvements, or code changes.

---

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Commit Message Convention](#commit-message-convention)
- [Pull Request Process](#pull-request-process)
- [Issue Guidelines](#issue-guidelines)

---

## 🤝 Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it before contributing.

---

## 🛠️ How Can I Contribute?

### 🐛 Reporting Bugs

1. Search existing [Issues](../../issues) to avoid duplicates.
2. Use the **Bug Report** issue template.
3. Include:
   - Steps to reproduce the issue
   - Expected vs. actual behavior
   - Flutter/Node.js version, OS, device
   - Screenshots or screen recordings if applicable

### ✨ Suggesting Features

1. Search existing [Issues](../../issues) and [Discussions](../../discussions).
2. Use the **Feature Request** issue template.
3. Clearly describe the problem your feature solves.
4. Include mockups or examples if possible.

### 📖 Improving Documentation

Documentation improvements are always welcome! Simply:
1. Fork the repository.
2. Edit the relevant `.md` file.
3. Submit a pull request.

### 💻 Code Contributions

1. Fork the repository and create a new branch.
2. Make your changes following the coding standards below.
3. Add/update tests if applicable.
4. Submit a pull request with a clear description.

---

## 🚀 Development Setup

### Prerequisites
- Flutter SDK 3.x+
- Node.js 20.x+
- Firebase CLI (`npm install -g firebase-tools`)
- A Firebase project with Firestore, Auth, and Functions enabled

### Local Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/MediQue.git
cd MediQue

# Flutter setup
cd mediqueue_flutter
flutter pub get
cd ..

# Functions setup
cd functions
npm install
cd ..

# Start local emulators
firebase emulators:start
```

### Environment
Copy `functions/.env.example` to `functions/.env` and fill in your values.

> ⚠️ Never commit real API keys, OTP peppers, or Firebase service account credentials.

---

## 🎨 Coding Standards

### Dart / Flutter
- Follow the official [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Run `flutter analyze` before submitting — zero warnings/errors required
- Use `flutter format .` to auto-format
- Component names must be PascalCase; variables and functions must be camelCase

### JavaScript / Node.js
- Use `const`/`let` — never `var`
- All async operations must use `async/await` with proper error handling
- All HTTP endpoints must verify authentication before processing
- Never log raw PHI (patient names, phone numbers, OTPs) — use hashed references

### General
- Write self-documenting code with meaningful variable and function names
- Add JSDoc / Dart doc comments to all public functions
- Keep functions small and focused (single responsibility)

---

## ✅ Commit Message Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>

[optional body]

[optional footer]
```

**Types:**
| Type | Description |
|---|---|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no logic change |
| `refactor` | Code restructuring |
| `test` | Adding or updating tests |
| `chore` | Build process or tooling changes |
| `security` | Security hardening or fixes |

**Examples:**
```
feat(patient): add QR check-in flow
fix(auth): resolve OTP cooldown not resetting on lockout
docs(api): add notifyPatient endpoint documentation
security(functions): hash client IPs in audit logs
```

---

## 🔄 Pull Request Process

1. **Branch Naming:** Use the format `type/short-description`
   - `feat/sms-bot-integration`
   - `fix/otp-lockout-reset`
   - `docs/api-reference`

2. **PR Checklist:**
   - [ ] Code follows style guidelines
   - [ ] All existing tests pass
   - [ ] New tests added for new features/fixes
   - [ ] Documentation updated if needed
   - [ ] No secrets or credentials committed
   - [ ] PR description clearly explains the changes and motivation

3. **Review Process:**
   - At least one maintainer review is required to merge
   - Address all review comments before merge
   - Squash commits before merging for a clean history

---

## 📝 Issue Guidelines

When filing an issue, please:

- Use a clear, descriptive title
- Fill in the issue template completely
- Label the issue appropriately (`bug`, `enhancement`, `documentation`, `security`)
- Link related issues or PRs if applicable

---

Thank you for making MediQue better for everyone! 🏥
