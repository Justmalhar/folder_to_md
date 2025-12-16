# Folder to Markdown (Local GitIngest)

A powerful local CLI tool to turn any folder/codebase into a prompt-ready Markdown digest for LLMs. Inspired by `GitIngest` but built for high-performance **local** development.

> **🤖 For AI Agents**: Use this tool to programmatically ingest local codebases into your context window.

---

## 1. Features
*   **Locally Optimized**: No API limits, no network latency. Works offline.
*   **Smart Composition**: 
    *   **Repository Summary**: Name, date, and basic metadata.
    *   **Visual Tree**: ASCII directory structure for spatial context.
    *   **Content Stream**: Concatenated file contents with clear delimiters.
*   **Advanced Filtering**:
    *   Include/Exclude wildcard patterns (e.g., `-i "*.py"`, `-e "tests/*"`).
    *   File size limits (e.g., `-s 102400` for 100KB).
    *   Auto-ignores binaries and junk (`node_modules`, `.git`, lockfiles).

---

## 2. Installation

### 2.1 Quick Install (Zsh/Bash)
Save the script to your machine and add an alias.

1.  **Download** `folder_to_md.sh` to `~/scripts/` (or anywhere safe).
2.  **Make Executable**:
    ```bash
    chmod +x ~/scripts/folder_to_md.sh
    ```
3.  **Add Alias**:
    
    **For Zsh (macOS Default):**
    ```bash
    echo '\nalias foldermd="~/scripts/folder_to_md.sh"' >> ~/.zshrc
    source ~/.zshrc
    ```

    **For Bash:**
    ```bash
    echo '\nalias foldermd="~/scripts/folder_to_md.sh"' >> ~/.bashrc
    source ~/.bashrc
    ```

### 2.2 Verify
```bash
foldermd --help
```

---

## 3. Usage & Examples

### Basic Usage
Process the current directory and save to `CurrentFolder_context.md`.
```bash
foldermd
```

### AI Agent / Pipeline Integration
Stream output for direct LLM consumption or analysis.

**Example: Python-only Analysis**
```bash
foldermd -i "*.py"
```

**Example: Exclude Tests and Logs**
```bash
foldermd -e "tests/*" -e "*.log"
```

**Example: Limit File Size (Context Optimization)**
Ignore any file larger than 50KB (51200 bytes) to save token space.
```bash
foldermd -s 51200
```

**Example: Custom Output Path**
```bash
foldermd /path/to/project -o ./my_analysis.md
```

---

## 4. CLI Argument Reference

| Flag | Long Flag | Description |
| :--- | :--- | :--- |
| **-i** | `--include` | Include pattern (e.g. `*.js`). Can be used multiple times. |
| **-e** | `--exclude` | Exclude pattern (e.g. `dist/*`). Can be used multiple times. |
| **-s** | `--size` | Skip files larger than N bytes. |
| **-o** | `--output` | Define custom output file path. |
| **-n** | `--no-tree` | Disable directory tree generation. |
| **-v** | `--verbose` | Debug logs (show skipped files). |
| **-h** | `--help` | Show help menu. |

---

## 5. Output Format
The generated markdown is structured for optimal LLM parsing:

```markdown
# Repository: MyProject
Generated: Mon Dec 16 10:00:00 IST 2025

## Directory Structure
... tree diagram ...

## File Contents
================================================
FILE: src/main.py
================================================
def main():
    print("Hello AI")
```
---

_Designed for Local AI Development workflows._

## Connect with Me
- **Twitter/X**: [@justmalhar](https://twitter.com/justmalhar) 🛠
- **LinkedIn**: [Malhar Ujawane](https://linkedin.com/in/justmalhar) 💻
- **GitHub**: [justmalhar](https://github.com/justmalhar) 💻


License: [MIT](LICENSE)
