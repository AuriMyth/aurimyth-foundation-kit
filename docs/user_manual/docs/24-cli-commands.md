# 24. CLI 命令参考

AuriMyth Foundation Kit 提供统一的命令行工具 `aum`（或 `aurimyth`），整合了项目脚手架、代码生成、服务器管理和数据库迁移功能。

## 安装命令行补全

```bash
# 安装 shell 补全（支持 bash/zsh/fish/powershell）
aum --install-completion

# 显示补全脚本（不安装）
aum --show-completion
```

## 命令概览

```bash
aum [OPTIONS] COMMAND [ARGS]...

Commands:
  init       🎯 初始化项目脚手架
  generate   ⚡ 代码生成器
  server     🖥️  服务器管理
  scheduler  🕐 独立运行调度器
  worker     ⚙️  运行任务队列 Worker
  migrate    🗃️  数据库迁移
  docker     🐳 Docker 配置生成

Options:
  -v, --version  显示版本信息
  --help         显示帮助信息
```

## aum init

在当前项目中初始化 AuriMyth 脚手架。

**前置条件**：已运行 `uv init` 创建项目并安装 aurimyth-foundation-kit。

```bash
# 前置步骤（必须先执行）
uv init . --name my_service --no-package --python 3.13
uv add "aurimyth-foundation-kit[recommended]"

# 然后初始化脚手架
aum init [PACKAGE_NAME] [OPTIONS]

Arguments:
  PACKAGE_NAME        可选，顶层包名（如 my_package）

Options:
  -y, --no-interactive  跳过交互，纯默认配置
  -f, --force           强制覆盖已存在的文件
  --docker              同时生成 Docker 配置
  --help                显示帮助信息
```

> **注意**：`init` 会覆盖 `uv init` 创建的默认 `main.py`，这是正常行为。

### 交互式模式（默认）

默认使用交互式模式，会询问以下配置：

- **项目结构**：平铺结构 vs 顶层包结构
- **数据库类型**：PostgreSQL（推荐）/ MySQL / SQLite
- **缓存类型**：内存缓存（开发）/ Redis（生产）
- **服务模式**：API / API+调度器 / 完整（API+调度器+任务）
- **可选功能**：对象存储、事件总线、国际化
- **开发工具**：pytest, ruff, mypy
- **Docker 配置**：Dockerfile + docker-compose.yml

使用 `-y` 或 `--no-interactive` 跳过交互，使用默认配置。

### 生成内容

**文件**：
- `main.py` - 应用入口
- `config.py` - 配置类
- `.env.example` - 环境变量模板
- `README.md` - 项目说明（如不存在）
- `tests/conftest.py` - pytest 配置

**目录**：
- `api/` - API 路由
- `services/` - 业务逻辑
- `models/` - SQLAlchemy 模型
- `repositories/` - 数据访问层
- `schemas/` - Pydantic 模型
- `tests/` - 测试

**pyproject.toml 配置**：
- `[tool.ruff]` - Ruff 代码检查配置
- `[tool.pytest.ini_options]` - pytest 配置

### 示例

```bash
# 前置步骤
uv init . --name my_service --no-package --python 3.13
uv add "aurimyth-foundation-kit[recommended]"

# 交互式模式（默认）
aum init

# 跳过交互，纯默认配置
aum init -y

# 使用顶层包结构
aum init my_package

# 包含 Docker 配置
aum init --docker

# 强制覆盖已存在的文件
aum init --force
```

## aum generate

代码生成器，生成符合 AuriMyth 规范的代码文件。

```bash
aum generate COMMAND [ARGS]...

Commands:
  model    生成 SQLAlchemy 模型
  repo     生成 Repository 数据访问层
  service  生成 Service 业务逻辑层
  api      生成 FastAPI 路由
  schema   生成 Pydantic Schema
  crud     一键生成完整 CRUD
```

### 字段定义语法

代码生成器支持通过命令行参数定义字段（AI 友好）或交互式模式（人类友好）。

**字段格式**：`name:type:modifiers`

**支持的类型**：

| 类型 | 说明 |
|------|------|
| `str`, `string` | 字符串（默认 255） |
| `str(100)` | 指定长度的字符串 |
| `text` | 长文本 |
| `int`, `integer` | 整数 |
| `bigint` | 大整数 |
| `float` | 浮点数 |
| `decimal` | 精确小数 |
| `bool`, `boolean` | 布尔值 |
| `datetime` | 日期时间 |
| `date` | 日期 |
| `json`, `dict` | JSON 对象 |

**修饰符**：

| 修饰符 | 说明 | 示例 |
|--------|------|------|
| `?` 或 `nullable` | 可空 | `age:int?` |
| `unique` | 唯一约束 | `email:str:unique` |
| `index` | 索引 | `name:str:index` |
| `=value` | 默认值 | `status:str=active` |

**示例**：

```bash
# 完整示例
aum generate crud user email:str:unique age:int? status:str=active

# 文章模型
aum generate crud article title:str(200) content:text status:str=draft

# 商品模型
aum generate crud product name:str:unique price:decimal stock:int=0
```

### generate model

```bash
aum generate model NAME [FIELDS...] [OPTIONS]

Arguments:
  NAME       模型名称（如 user, UserProfile）
  FIELDS...  字段定义（可选）

Options:
  -i, --interactive   交互式添加字段
  -f, --force         强制覆盖
  --no-soft-delete    禁用软删除
  --no-timestamps     禁用时间戳
```

生成 `models/{name}.py`，默认继承 `UUIDAuditableStateModel`。

```bash
# 基本用法
aum generate model user

# 带字段定义
aum generate model user email:str:unique age:int? status:str=active

# 交互式
aum generate model user -i
```

### generate repo

```bash
aum generate repo NAME [FIELDS...] [OPTIONS]
```

生成 `repositories/{name}_repository.py`。如果指定了 `unique` 字段，会自动生成 `get_by_xxx` 方法。

```bash
aum generate repo user email:str:unique  # 生成 get_by_email 方法
```

### generate service

```bash
aum generate service NAME [FIELDS...] [OPTIONS]
```

生成 `services/{name}_service.py`。如果指定了 `unique` 字段，会自动生成重复检测逻辑。

```bash
aum generate service user email:str:unique  # 创建时检查 email 重复
```

### generate api

```bash
aum generate api NAME [OPTIONS]
```

生成 `api/{name}.py`，包含完整的 CRUD 路由。

### generate schema

```bash
aum generate schema NAME [FIELDS...] [OPTIONS]

Options:
  -i, --interactive  交互式添加字段
  -f, --force        强制覆盖
```

生成 `schemas/{name}.py`，包含 Create/Update/Response 模型。

### generate crud

```bash
aum generate crud NAME [FIELDS...] [OPTIONS]

Options:
  -i, --interactive   交互式添加字段
  -f, --force         强制覆盖
  --no-soft-delete    禁用软删除
```

一键生成完整 CRUD：model + repo + service + schema + api。

### 示例

```bash
# 基本用法（无字段）
aum generate crud user

# 带字段定义（AI 友好）
aum generate crud user email:str:unique age:int? status:str=active
aum generate crud article title:str(200) content:text published:bool=false

# 交互式（人类友好）
aum generate crud user -i

# 强制覆盖
aum generate crud user --force

# 禁用软删除
aum generate crud user --no-soft-delete
```

## aum server

服务器管理命令。

```bash
aum server COMMAND [ARGS]...

Commands:
  dev   启动开发服务器（热重载）
  prod  启动生产服务器（多进程）
  run   通用运行命令
```

### server dev

```bash
aum server dev [OPTIONS]

Options:
  -a, --app TEXT   应用模块路径（默认自动检测）
  -h, --host TEXT  监听地址
  -p, --port INT   监听端口
```

特点：自动启用热重载和调试模式。

### server prod

```bash
aum server prod [OPTIONS]

Options:
  -a, --app TEXT      应用模块路径
  -h, --host TEXT     监听地址（默认: 0.0.0.0）
  -p, --port INT      监听端口
  -w, --workers INT   工作进程数（默认: CPU 核心数）
```

特点：多进程，禁用热重载。

### server run

```bash
aum server run [OPTIONS]

Options:
  -a, --app TEXT         应用模块路径
  -h, --host TEXT        监听地址
  -p, --port INT         监听端口
  -w, --workers INT      工作进程数
  --reload               启用热重载
  --reload-dir TEXT      热重载监控目录（可多次指定）
  --debug                调试模式
  --loop TEXT            事件循环（auto/asyncio/uvloop）
  --http TEXT            HTTP 协议（auto/h11/httptools）
  --ssl-keyfile TEXT     SSL 密钥文件
  --ssl-certfile TEXT    SSL 证书文件
  --no-access-log        禁用访问日志
```

### 示例

```bash
# 开发模式
aum server dev
aum server dev --port 9000

# 生产模式
aum server prod
aum server prod --workers 8

# 自定义运行
aum server run --reload --workers 4
aum server run --ssl-keyfile key.pem --ssl-certfile cert.pem
```

## aum scheduler

独立运行调度器进程。

```bash
aum scheduler [OPTIONS]

Options:
  -a, --app TEXT   应用模块路径（默认自动检测）
  --help           显示帮助信息
```

调度器会加载应用中定义的所有定时任务，独立运行（不启动 HTTP 服务）。

```bash
# 基本用法
aum scheduler

# 指定应用模块
aum scheduler --app mypackage.main:app
```

## aum worker

运行任务队列 Worker 进程。

```bash
aum worker [OPTIONS]

Options:
  -a, --app TEXT        应用模块路径（默认自动检测）
  -c, --concurrency INT 并发 worker 数量（默认: 4）
  -q, --queues TEXT     要处理的队列名称（逗号分隔）
  --help                显示帮助信息
```

Worker 会消费任务队列中的异步任务并执行。

```bash
# 基本用法
aum worker

# 指定并发数
aum worker -c 8

# 只处理指定队列
aum worker -q high,default

# 指定应用模块
aum worker --app mypackage.main:app
```

## aum migrate

数据库迁移命令。

```bash
aum migrate COMMAND [ARGS]...

Commands:
  make     生成迁移文件
  up       执行迁移
  down     回滚迁移
  status   查看迁移状态
  show     显示所有迁移
  check    检查迁移
  history  显示迁移历史
  merge    合并迁移
```

### migrate make

```bash
aum migrate make [OPTIONS]

Options:
  -m, --message TEXT           迁移消息（必需）
  --autogenerate/--no-autogenerate  是否自动生成
  --dry-run                    干运行
  --config TEXT                Alembic 配置文件路径
```

### migrate up

```bash
aum migrate up [OPTIONS]

Options:
  -r, --revision TEXT  目标版本（默认: head）
  --dry-run            干运行
  --config TEXT        Alembic 配置文件路径
```

### migrate down

```bash
aum migrate down REVISION [OPTIONS]

Arguments:
  REVISION  目标版本（previous, -1, 或具体版本号）

Options:
  --dry-run      干运行
  --config TEXT  Alembic 配置文件路径
```

### migrate status

```bash
aum migrate status [OPTIONS]
```

显示当前迁移状态、待执行迁移和已执行迁移。

### 示例

```bash
# 生成迁移
aum migrate make -m "add user table"
aum migrate make -m "check changes" --dry-run

# 执行迁移
aum migrate up
aum migrate up -r "abc123"

# 回滚迁移
aum migrate down previous
aum migrate down -1

# 查看状态
aum migrate status
aum migrate show
```

## 环境变量

所有命令都支持通过环境变量配置：

```bash
# 服务配置
SERVICE_NAME=my-service
SERVICE_TYPE=api  # api, worker

# 服务器
SERVER_HOST=0.0.0.0
SERVER_PORT=8000
SERVER_WORKERS=4

# 应用模块
APP_MODULE=main:app

# 调度器（内嵌在 API 服务中）
SCHEDULER_ENABLED=true  # 默认 true，设为 false 可禁用
```

**服务运行模式说明**：

- `SERVICE_TYPE=api` + `SCHEDULER_ENABLED=true`（默认）：API 服务 + 内嵌调度器
- `SERVICE_TYPE=api` + `SCHEDULER_ENABLED=false`：纯 API 服务
- `aum scheduler`：独立调度器进程（无需配置）
- `aum worker`：独立 Worker 进程（无需配置）

## 下一步

- 查看 [25-scaffold-guide.md](./25-scaffold-guide.md) 了解脚手架使用指南
- 查看 [03-server-deployment.md](./03-server-deployment.md) 了解服务器部署
- 查看 [21-migration-guide.md](./21-migration-guide.md) 了解数据库迁移
