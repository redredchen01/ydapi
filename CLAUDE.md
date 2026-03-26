# test-ydapi — YDAPI 測試環境

**Priority:** P2
**狀態：** 🟢 Active
**最後更新：** 2026-03-25
**規模：** 3264 files, 137M

---

## 項目簡介

YDAPI 測試和驗證環境。用於測試 P1 主項目的功能和集成。

## 項目結構

```
test-ydapi/
├── tests/              # 測試用例
├── fixtures/           # 測試數據
├── integration/        # 集成測試
├── package.json        # Node.js 配置
└── CLAUDE.md           # 本檔案
```

## Build & Test

```bash
# 安裝依賴
npm install

# 運行所有測試
npm test

# 運行特定測試套件
npm test -- --grep "suite_name"

# 覆蓋率報告
npm run coverage
```

## Git 工作流

```bash
# 查看狀態
git status

# 提交規範
git commit -m "test: description"  # ≤72 chars
```

## 特定規則

- **測試優先：** 所有新功能需先在此環境驗證
- **與 P1 同步：** 定期同步 dexapi 的最新代碼
- **報告路徑：** 測試結果存放在 `test-results/`

## 相關文件

- 通用規則：見 `../CLAUDE.md`
- 工作流程：見 `../.obsidian-vault/areas/workflow.md`
- 項目進度：見 `~/.claude/projects/.../memory/project_test_ydapi.md`

---

*同步至 memory：~/.claude/projects/-Users-dex-YD-2026/memory/project_test_ydapi.md*
