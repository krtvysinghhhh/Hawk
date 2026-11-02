# Contributing to HAWK

Thank you for your interest in contributing to HAWK! We welcome contributions from iOS engineers, audio specialists, and designers who share our passion for native Apple audio fidelity.

---

## Code of Conduct

Please be respectful, collaborative, and constructive in all discussions, pull requests, and issue reports.

---

## Development Workflow

1. **Fork and Clone:**
   ```bash
   git clone https://github.com/krtvysinghhhh/HAWK.git
   cd HAWK
   ```

2. **Branching Strategy:**
   - Create a feature or bugfix branch from `main`:
     ```bash
     git checkout -b feat/your-feature-name
     ```

3. **Engineering Guidelines:**
   - **Swift 6 Concurrency:** Shared mutable state must be isolated in `actor` instances. Do not suppress Sendable warnings without architectural justification.
   - **No Simulated Success:** Do not write mock implementations or hardcode sample data to fabricate functionality.
   - **Apple HIG:** Adhere to Apple Human Interface Guidelines. Support Dynamic Type, VoiceOver accessibility labels, Reduce Motion, and Reduce Transparency.
   - **No Secrets:** Never commit API keys, personal credentials, provisioning profiles, or private keys.

4. **Testing Your Changes:**
   Before opening a Pull Request, run the automated verification suite:
   ```bash
   swift run HawkVerify
   ```
   All tests must pass cleanly.

5. **Submitting a Pull Request:**
   - Provide a clear, descriptive PR title and summary.
   - List the issues resolved or features added.
   - Include test results or device verification notes.

---

## Questions and Support

Open an issue on GitHub or join our community discussions.
