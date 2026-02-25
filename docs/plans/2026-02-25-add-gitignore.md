# 添加 .gitignore 实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 创建 `.gitignore` 文件，忽略所有构建产物、IDE 配置、平台缓存等无需提交的文件和目录。

**架构：** 单文件变更，覆盖 CMake 构建输出、Android Gradle 构建产物、iOS Xcode 构建产物、IDE 配置及 OS 级临时文件。

**技术栈：** Git

---

## 执行约束

- 单任务，直接创建并提交。

### 任务 1：创建 .gitignore

**文件：**
- 新建：`.gitignore`

**步骤 1：创建 .gitignore 文件**

```gitignore
# CMake 构建输出
build/
cmake-build-*/

# Android Gradle
android/.gradle/
android/**/build/
android/local.properties
android/.idea/
android/**/*.iml

# iOS / Xcode
ios/**/build/
ios/**/*.xcworkspace/xcuserdata/
ios/**/*.xcodeproj/xcuserdata/
ios/**/DerivedData/
ios/**/*.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist

# Swift Package Manager
.swiftpm/
Package.resolved

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Claude Code 本地配置
.claude/
```

**步骤 2：验证已追踪文件不受影响**

运行：`git status`
预期：`.gitignore` 显示为新未追踪文件；`build/` 和 `.claude/` 不再出现在未追踪列表中。

**步骤 3：提交**

```bash
git add .gitignore
git commit -m "chore: 添加 .gitignore 忽略构建产物与本地配置"
```
