# Security Policy

## 🔒 Privacy & Security Posture

The **991CW Scientific Calculator** is designed with an offline-first, zero-trust architecture:

- **Zero Permissions**: The application requests **no internet, storage, camera, location, or device identity permissions** (`AndroidManifest.xml` is completely permission-free).
- **100% Offline Execution**: All mathematical evaluations, symbolic simplifications, spreadsheet calculations, and QR code generations happen locally on the user's device.
- **Zero External Math Dependencies**: The calculator engine relies exclusively on pure Dart standard library primitives (`BigInt`, `dart:math`, `dart:typed_data`), minimizing supply-chain attack surface.

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security issue—such as an algorithmic denial-of-service (e.g., an infinite loop or memory exhaustion triggered by a crafted mathematical expression or spreadsheet formula)—please report it responsibly:

1. **Email**: Contact the maintainer at **b.ravindudilshan@gmail.com**, or open a private [GitHub Security Advisory](https://github.com/ravindudil5han/scientific-calculator/security/advisories/new).
2. **Include Details**: Provide the exact calculator mode (`AppMode`), key sequence or expression AST, and expected vs. observed behavior.
3. **Response Timeline**: You can expect an initial acknowledgment within 72 hours, followed by a fix and coordinated disclosure.
