# WhatsApp Chat Exporter - Security & Quality Roadmap

This document outlines potential improvements to enhance the security and quality of the WhatsApp Chat Exporter project. These items are recommendations from the security review and community feedback.

## High Priority

### 1. Replace Deprecated `bleach` Dependency
**Status**: Planned  
**Priority**: High  
**Effort**: Low

**Current State:**
- Using `bleach` for HTML sanitization (deprecated since 2023)
- Only used for allowing `<br>` tags in sanitized output

**Proposed Solution:**
- Migrate to `nh3` (maintained by Mozilla) or use `markupsafe` alone
- `nh3` is a Python binding to Ammonia (Rust HTML sanitizer)
- Alternative: Use `markupsafe.escape()` with manual `<br>` replacement

**Benefits:**
- Active maintenance and security updates
- Better performance with `nh3` (Rust-based)
- Reduced dependency footprint

**Implementation:**
```python
# Option 1: Using nh3
import nh3
def sanitize_except(html: str) -> Markup:
    return Markup(nh3.clean(html, tags={"br"}))

# Option 2: Using markupsafe only
from markupsafe import Markup, escape
def sanitize_except(html: str) -> Markup:
    # Escape everything, then allow <br>
    escaped = escape(html)
    return Markup(escaped.replace('&lt;br&gt;', '<br>'))
```

### 2. Implement Parameterized SQL Queries
**Status**: Recommended  
**Priority**: High  
**Effort**: Medium

**Current State:**
- SQL queries use f-string formatting with validated inputs
- Input validation prevents most attacks
- Not following SQL best practices

**Proposed Solution:**
- Migrate to parameterized queries using `?` placeholders
- Ensure all dynamic filters use proper parameter binding

**Benefits:**
- Eliminates SQL injection risks entirely
- Follows security best practices
- More maintainable code

**Implementation:**
```python
# Before:
date_filter = f'AND messages.timestamp {filter_date}' if filter_date is not None else ''
cursor.execute(f"SELECT * FROM messages WHERE 1=1 {date_filter}")

# After:
if filter_date:
    cursor.execute("SELECT * FROM messages WHERE timestamp BETWEEN ? AND ?", (start, end))
else:
    cursor.execute("SELECT * FROM messages")
```

## Medium Priority

### 3. Add Built-in Export Encryption
**Status**: Consideration  
**Priority**: Medium  
**Effort**: Medium

**Current State:**
- Users must manually encrypt exports using GPG
- secure_export.sh provides encryption via GPG wrapper

**Proposed Solution:**
- Add `--encrypt` flag to directly encrypt output
- Support multiple encryption methods (GPG, AES, etc.)
- Optionally use Python cryptography library

**Benefits:**
- Easier for users unfamiliar with GPG
- More integrated workflow
- Cross-platform consistency

**Considerations:**
- Key management complexity
- Increases dependencies
- May be redundant with GPG

### 4. Secure Deletion Option
**Status**: Consideration  
**Priority**: Medium  
**Effort**: Low

**Current State:**
- Users must manually run shred/secure delete commands
- Instructions provided by secure_export.sh

**Proposed Solution:**
- Add `--secure-delete-temp` flag
- Automatically shred temporary files after export
- Warn users about SSD limitations

**Benefits:**
- Improved privacy for temporary files
- One-step cleanup process

**Considerations:**
- Platform-specific implementation
- Ineffective on SSDs (should document this)

### 5. Integrity Verification (Checksums)
**Status**: Recommended  
**Priority**: Medium  
**Effort**: Low

**Current State:**
- No automatic checksum generation
- Users can manually create checksums

**Proposed Solution:**
- Generate SHA-256 checksums for all exports
- Save checksums in `.sha256` files alongside exports
- Add `--verify` flag to verify existing exports

**Benefits:**
- Detect file corruption
- Verify export integrity
- Useful for archival purposes

**Implementation:**
```python
import hashlib

def generate_checksum(file_path):
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()
```

### 6. Dependency Monitoring Integration
**Status**: Recommended  
**Priority**: Medium  
**Effort**: Low

**Current State:**
- No automated dependency vulnerability scanning
- Users encouraged to use third-party tools

**Proposed Solution:**
- Add GitHub Dependabot configuration
- Include safety/pip-audit in CI/CD
- Document dependency update process

**Benefits:**
- Automated security alerts
- Proactive dependency updates
- Reduced maintenance burden

**Implementation:**
```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
```

## Low Priority

### 7. Enhanced Input Path Validation
**Status**: Nice-to-have  
**Priority**: Low  
**Effort**: Low

**Current State:**
- Basic path validation exists
- Relies on user best practices
- Docker mitigates this when used

**Proposed Solution:**
- Add strict path validation with allowlists
- Prevent paths outside working directory
- Add `--allow-external-paths` flag for advanced users

**Benefits:**
- Extra safety layer for direct Python usage
- Prevents accidental path traversal

**Considerations:**
- May reduce flexibility
- Docker already provides this protection

### 8. Multi-Platform Binary Distribution
**Status**: Consideration  
**Priority**: Low  
**Effort**: High

**Current State:**
- Python package only (requires Python installation)
- Users must install dependencies

**Proposed Solution:**
- Create standalone binaries with PyInstaller/Nuitka
- Distribute via GitHub Releases
- Include all dependencies

**Benefits:**
- Easier for non-technical users
- No Python installation required
- Reduced setup complexity

**Considerations:**
- Large file sizes
- Additional maintenance burden
- Complexity with platform-specific code

### 9. Progress Indicators
**Status**: Nice-to-have  
**Priority**: Low  
**Effort**: Low

**Current State:**
- Basic progress messages
- No visual progress bars

**Proposed Solution:**
- Add progress bars for long operations
- Use `tqdm` or similar library
- Show time estimates

**Benefits:**
- Better user experience
- Visibility into processing status

### 10. Configuration File Support
**Status**: Consideration  
**Priority**: Low  
**Effort**: Medium

**Current State:**
- All options via command-line flags
- No way to save common configurations

**Proposed Solution:**
- Support `.wtsexporter.yml` configuration file
- Allow saving/loading common options
- Command-line flags override config file

**Benefits:**
- Easier for repeated exports
- Shareable configurations
- Reduced typing for complex options

## Future Considerations

### 11. GUI Interface
**Status**: Long-term  
**Priority**: Low  
**Effort**: Very High

**Proposed Solution:**
- Simple GUI for non-technical users
- Drag-and-drop file selection
- Visual security indicators

**Considerations:**
- Significant development effort
- Additional dependencies
- Maintenance complexity

### 12. Cloud-Free Export from iOS
**Status**: Research  
**Priority**: Low  
**Effort**: Very High

**Current State:**
- iOS exports require iTunes/Finder backup
- Full device backup contains more than just WhatsApp

**Proposed Solution:**
- Research direct WhatsApp extraction from iOS
- Minimize backup requirements
- Reduce exposure of other personal data

**Considerations:**
- iOS security restrictions
- May require jailbreak or special tools
- Apple's limitations

### 13. Diff/Compare Tool
**Status**: Nice-to-have  
**Priority**: Low  
**Effort**: Medium

**Proposed Solution:**
- Tool to compare two exports
- Highlight new/changed messages
- Incremental export support

**Benefits:**
- Useful for regular backups
- Only export what changed

## Implementation Notes

### How to Contribute
1. Review this roadmap
2. Pick an item to implement
3. Open an issue for discussion
4. Submit a pull request
5. Update this roadmap when complete

### Priority Definitions
- **High**: Security-critical or affects core functionality
- **Medium**: Improves security or user experience significantly
- **Low**: Nice-to-have enhancements

### Effort Estimates
- **Low**: < 1 day of work
- **Medium**: 1-3 days of work
- **High**: 1-2 weeks of work
- **Very High**: > 2 weeks of work

## Review Schedule

This roadmap should be reviewed:
- After each major version release
- When significant security issues are discovered
- Quarterly for priority updates
- When community feedback suggests new items

**Last Updated**: 2025-12-28  
**Next Review**: 2026-03-28 or upon v0.13.0 release
