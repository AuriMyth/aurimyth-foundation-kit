# {project_name}

基于 [AuriMyth Foundation Kit](https://github.com/AuriMythNeo/aurimyth-foundation-kit) 构建的微服务。

## 快速开始

### 安装依赖

```bash
uv sync
```

### 配置环境变量

```bash
cp .env.example .env
# 编辑 .env 文件
```

### 启动开发服务器

```bash
aum server dev
```

### 生成代码

```bash
# 生成完整 CRUD（交互式，推荐）
aum generate crud user -i

# 单独生成（添加 -i 参数可交互式配置）
aum generate model user -i     # SQLAlchemy 模型
aum generate repo user        # Repository
aum generate service user     # Service
aum generate api user         # API 路由
aum generate schema user      # Pydantic Schema
```

### 数据库迁移

```bash
# 生成迁移
aum migrate make -m "add user table"

# 执行迁移
aum migrate up

# 查看状态
aum migrate status
```

### 调度器和 Worker

```bash
# 独立运行调度器
aum scheduler

# 运行任务队列 Worker
aum worker
```

## 项目结构

```
{project_name}/
├── main.py              # 应用入口
├── config.py            # 配置定义
├── api/                 # API 路由
├── services/            # 业务逻辑
├── models/              # SQLAlchemy 模型
├── repositories/        # 数据访问层
├── schemas/             # Pydantic 模型
├── exceptions/          # 自定义异常
├── migrations/          # 数据库迁移
└── tests/               # 测试
```

## 文档

- [DEVELOPMENT.md](./DEVELOPMENT.md) - 开发指南
- [AuriMyth Foundation Kit 文档](https://github.com/AuriMythNeo/aurimyth-foundation-kit)
