# Contributing to Kamailio SIP Server Project

## 🤝 Welcome Contributors!

Thank you for your interest in contributing to the Kamailio SIP Server project. This guide will help you understand how you can contribute effectively.

## 🌟 Ways to Contribute

### 1. Code Contributions
- Bug fixes
- Feature enhancements
- Performance improvements
- Documentation updates

### 2. Non-Code Contributions
- Bug reporting
- Feature suggestions
- Documentation improvements
- Community support

## 🛠 Development Setup

### Prerequisites
- Git
- Docker (v20.10+)
- Docker Compose (v1.29+)
- Linux Environment (Recommended)

### Local Development Setup
```bash
# Clone the repository
git clone https://github.com/your-org/kamailio-sip-server.git
cd kamailio-sip-server

# Initialize project
./initialize_kamailio_project.sh

# Run test suite
./scripts/test_suite.sh
```

## 🔍 Contribution Process

### 1. Find an Issue
- Check GitHub Issues
- Look for "good first issue" or "help wanted" labels

### 2. Fork the Repository
```bash
# Fork on GitHub
# Clone your forked repository
git clone https://github.com/your-username/kamailio-sip-server.git
cd kamailio-sip-server
```

### 3. Create a Branch
```bash
# Create a descriptive branch
git checkout -b feature/your-feature-name
# OR
git checkout -b bugfix/issue-description
```

## 🧪 Development Guidelines

### Code Quality
- Follow existing code style
- Write clear, commented code
- Add/update tests for new features

### Testing
```bash
# Run full test suite
./scripts/test_suite.sh

# Run specific tests
./scripts/test_suite.sh --filter registration
```

### Documentation
- Update README.md if needed
- Add comments to code
- Update DOCUMENTATION.md for significant changes

## 🔒 Security Contributions

### Reporting Security Issues
- Do NOT open public issues for security vulnerabilities
- Email security@kamailio-project.org with details
- Include:
  - Detailed description
  - Potential impact
  - Reproduction steps
  - Suggested fix (if possible)

## 🤖 Automated Checks

### Pre-Commit Checks
- Code formatting
- Static code analysis
- Unit tests
- Integration tests

### Continuous Integration
- GitHub Actions will run:
  - Test Suite
  - Code Coverage
  - Security Scans

## 📝 Commit Message Guidelines

### Commit Message Format
```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Formatting, missing semicolons
- `refactor`: Code restructuring
- `test`: Adding or modifying tests
- `chore`: Maintenance tasks

### Example
```
feat(registration): Add TLS support for SIP registrations

- Implement TLS configuration in Kamailio
- Update test suite to verify TLS functionality
- Enhance security documentation

Closes #123
```

## 🏆 Contribution Recognition

### Ways We Recognize Contributors
- GitHub Contributors badge
- Mention in CONTRIBUTORS.md
- Potential swag/merchandise
- Speaking opportunities

## 📋 Code of Conduct

### Our Pledge
- Welcoming environment
- Respectful communication
- Constructive feedback
- Inclusive community

### Unacceptable Behavior
- Harassment
- Discriminatory language
- Trolling
- Personal attacks

## 🌐 Community Channels

### Communication Platforms
- GitHub Discussions
- Mailing Lists
- Community Forums
- Discord/Slack Channel

## 📄 Licensing

- Contributions are under GPL v2
- Sign Developer Certificate of Origin (DCO)
- `git commit -s` to sign commits

## 🚀 Getting Help

### Support Channels
- GitHub Issues
- Community Forums
- Mailing Lists
- Discord Support Channel

---

**Thank you for contributing to the Kamailio SIP Server project!**

*Last Updated*: $(date)
*Version*: 1.0.0