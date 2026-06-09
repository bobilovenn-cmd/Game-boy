---
name: feedback-sync-memory
description: 记忆文件更新时同步复制到 /Users/guoweifeng/Game Boy/memory/ 目录
metadata:
  type: feedback
---

每次更新记忆文件后，同步复制到 /Users/guoweifeng/Game Boy/memory/ 目录。

**Why:** 用户希望在 Game Boy 项目文件夹中保留一份记忆文件的备份，方便查看和管理。

**How to apply:** 更新任何 .claude/projects/ 下的记忆文件后，用 cp 或 rsync 同步到 /Users/guoweifeng/Game Boy/memory/。
