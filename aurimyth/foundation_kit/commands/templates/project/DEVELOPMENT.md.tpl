# {project_name} 开发指南

本文档基于 [AuriMyth Foundation Kit](https://github.com/AuriMythNeo/aurimyth-foundation-kit) 框架。

## CLI 命令参考

### 服务器命令

```bash
# 开发模式（自动重载）
aum server dev

# 生产模式
aum server prod

# 自定义运行
aum server run --host 0.0.0.0 --port 8000 --workers 4
```

### 代码生成

```bash
# 生成完整 CRUD
aum generate crud user

# 交互式生成（推荐）：逐步选择字段、类型、约束等
aum generate crud user -i
aum generate model user -i

# 单独生成
aum generate model user      # SQLAlchemy 模型
aum generate repo user       # Repository
aum generate service user    # Service
aum generate api user        # API 路由
aum generate schema user     # Pydantic Schema

# 指定字段（非交互式）
aum generate model user --fields "name:str,email:str,age:int"

# 指定模型基类（继承不同的基类获得不同功能）
aum generate model user --base UUIDAuditableStateModel  # UUID主键 + 软删除（推荐）
aum generate model user --base UUIDModel                # UUID主键 + 时间戳
aum generate model user --base Model                    # int主键 + 时间戳
aum generate model user --base VersionedUUIDModel       # UUID + 乐观锁 + 时间戳

# 可用基类说明：
# - Model: int主键 + created_at/updated_at
# - UUIDModel: UUID主键 + created_at/updated_at
# - UUIDAuditableStateModel: UUID主键 + 软删除 + 时间戳（推荐）
# - VersionedModel: int主键 + version（乐观锁）
# - VersionedUUIDModel: UUID主键 + version + 时间戳
# - FullFeaturedUUIDModel: UUID主键 + 软删除 + 时间戳 + version
```

### 数据库迁移

```bash
aum migrate make -m "add user table"  # 创建迁移
aum migrate up                        # 执行迁移
aum migrate down                      # 回滚迁移
aum migrate status                    # 查看状态
aum migrate show                      # 查看历史
```

### 调度器和 Worker

```bash
aum scheduler    # 独立运行调度器
aum worker       # 运行 Dramatiq Worker
```

## 配置参考

所有配置项都可通过环境变量设置，优先级：命令行参数 > 环境变量 > .env 文件 > 默认值

### 主要环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `DATABASE_URL` | 数据库连接 URL | `sqlite+aiosqlite:///./dev.db` |
| `CACHE_TYPE` | 缓存类型 (memory/redis) | `memory` |
| `CACHE_URL` | Redis URL | - |
| `LOG_LEVEL` | 日志级别 | `INFO` |
| `LOG_DIR` | 日志目录 | `logs` |
| `SCHEDULER_ENABLED` | 启用内嵌调度器 | `true` |
| `TASK_BROKER_URL` | 任务队列 Broker URL | - |

## 核心组件使用

### 1. 数据库事务

#### 1.1 事务装饰器（推荐）

```python
from aurimyth.foundation_kit.domain.transaction import transactional
from sqlalchemy.ext.asyncio import AsyncSession

# 自动识别 session 参数，自动提交/回滚
@transactional
async def create_user(session: AsyncSession, name: str, email: str):
    """创建用户，自动在事务中执行。"""
    repo = UserRepository(session)
    user = await repo.create({"name": name, "email": email})
    # 成功：自动 commit
    # 异常：自动 rollback
    return user

# 在类方法中使用（自动识别 self.session）
class UserService:
    def __init__(self, session: AsyncSession):
        self.session = session
    
    @transactional
    async def create_with_profile(self, name: str):
        """自动使用 self.session。"""
        user = await self.repo.create({"name": name})
        await self.profile_repo.create({"user_id": user.id})
        return user
```

#### 1.2 事务上下文管理器

```python
from aurimyth.foundation_kit.domain.transaction import transactional_context
from aurimyth.foundation_kit.infrastructure.database import DatabaseManager

db = DatabaseManager.get_instance()

async with db.session() as session:
    async with transactional_context(session):
        repo1 = UserRepository(session)
        repo2 = ProfileRepository(session)
        
        user = await repo1.create({"name": "Alice"})
        await repo2.create({"user_id": user.id})
        # 自动提交或回滚
```

#### 1.3 事务传播（嵌套事务）

框架自动支持嵌套事务，内层事务会复用外层事务：

```python
@transactional
async def outer_operation(session: AsyncSession):
    """外层事务。"""
    repo1 = UserRepository(session)
    user = await repo1.create({"name": "Alice"})
    
    # 嵌套调用另一个 @transactional 函数
    result = await inner_operation(session)
    # 不会重复开启事务，复用外层事务
    # 只有外层事务提交时才会真正提交
    
    return user, result

@transactional
async def inner_operation(session: AsyncSession):
    """内层事务，自动复用外层事务。"""
    repo2 = OrderRepository(session)
    return await repo2.create({"user_id": 1})
    # 检测到已在事务中，直接执行，不重复提交
```

**传播行为**：
- 如果已在事务中：直接执行，不开启新事务
- 如果不在事务中：开启新事务，自动提交/回滚
- 嵌套事务共享同一个数据库连接和事务上下文

#### 1.4 非事务的数据库使用

对于只读操作或不需要事务的场景，可以直接使用 session：

```python
from aurimyth.foundation_kit.infrastructure.database import DatabaseManager

db = DatabaseManager.get_instance()

# 方式 1：使用 session 上下文管理器（推荐）
async with db.session() as session:
    repo = UserRepository(session)
    # 只读操作，不需要事务
    users = await repo.list(skip=0, limit=10)
    user = await repo.get(1)

# 方式 2：在 FastAPI 路由中使用（自动注入）
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

@router.get("/users")
async def list_users(
    session: AsyncSession = Depends(db.get_session),
):
    """只读操作，不需要事务。"""
    repo = UserRepository(session)
    return await repo.list()

# 方式 3：手动控制（需要手动关闭）
session = await db.create_session()
try:
    repo = UserRepository(session)
    users = await repo.list()
finally:
    await session.close()
```

**何时使用非事务**：
- 只读查询（SELECT）
- 不需要原子性的操作
- 性能敏感的场景（避免事务开销）

**何时必须使用事务**：
- 写操作（INSERT/UPDATE/DELETE）
- 需要原子性的多个操作
- 需要回滚的场景

### 2. 缓存

```python
from aurimyth.foundation_kit.infrastructure.cache import CacheManager, cached

# 方式 1：装饰器
@cached(ttl=300)  # 缓存 5 分钟
async def get_user(user_id: int):
    ...

# 方式 2：手动操作
cache = CacheManager.get_instance()
await cache.set("key", value, ttl=300)
value = await cache.get("key")
await cache.delete("key")
```

### 3. 定时任务

```python
from aurimyth.foundation_kit.common.logging import logger
from aurimyth.foundation_kit.infrastructure.scheduler import SchedulerManager

scheduler = SchedulerManager.get_instance()

@scheduler.scheduled_job("interval", seconds=60)
async def every_minute():
    """每 60 秒执行。"""
    logger.info("定时任务执行中...")

@scheduler.scheduled_job("cron", cron="0 0 * * *")
async def daily_task():
    """每天凌晨执行。"""
    logger.info("每日任务执行中...")
```

### 4. 异步任务（Dramatiq）

```python
from aurimyth.foundation_kit.infrastructure.tasks import conditional_task

@conditional_task
def send_email(to: str, subject: str):
    """异步发送邮件。"""
    ...

# 调用
send_email.send("user@example.com", "Hello")
```

### 5. S3 存储

```python
from aurimyth.foundation_kit.infrastructure.storage import StorageManager

storage = StorageManager.get_instance()

# 上传文件
await storage.upload("path/to/file.txt", content)

# 下载文件
content = await storage.download("path/to/file.txt")

# 获取预签名 URL
url = await storage.presigned_url("path/to/file.txt", expires=3600)

# 删除文件
await storage.delete("path/to/file.txt")
```

### 6. 日志

```python
from aurimyth.foundation_kit.common.logging import logger

logger.info("操作成功")
logger.warning("警告信息")
logger.error("错误信息", exc_info=True)

# 绑定上下文
logger.bind(user_id=123).info("用户操作")
```

### 7. 异常处理

在 `exceptions/` 目录中定义业务异常，框架会自动转换为 HTTP 响应。

```python
from fastapi import status
from aurimyth.foundation_kit.application.errors import (
    BaseError,
    NotFoundError,
    ValidationError,
    UnauthorizedError,
)

# 自定义异常（只需设置类属性）
class OrderError(BaseError):
    default_message = "订单错误"
    default_code = "ORDER_ERROR"
    default_status_code = status.HTTP_400_BAD_REQUEST

class OrderNotFoundError(OrderError):
    default_message = "订单不存在"
    default_code = "ORDER_NOT_FOUND"
    default_status_code = status.HTTP_404_NOT_FOUND

# 使用
raise OrderNotFoundError()  # 使用默认值
raise OrderError(message="订单ID无效")  # 自定义消息
raise NotFoundError(message="用户不存在", resource=user_id)
```

### 8. Repository 模式

```python
from aurimyth.foundation_kit.domain.repository import BaseRepository
from sqlalchemy.ext.asyncio import AsyncSession

class UserRepository(BaseRepository[User]):
    def __init__(self, session: AsyncSession):
        super().__init__(User, session)

# 使用
repo = UserRepository(session)
user = await repo.get(1)
users = await repo.get_multi(skip=0, limit=10)
await repo.create({"name": "Alice"})
await repo.update(1, {"name": "Bob"})
await repo.delete(1)
```

## 最佳实践

1. **配置管理**：使用 `.env` 文件管理环境变量，不要提交到版本库
2. **分层架构**：API -> Service -> Repository -> Model
3. **事务管理**：在 Service 层使用 `@requires_transaction`
4. **错误处理**：使用框架提供的异常类，全局异常处理器会统一处理
5. **日志记录**：使用框架的 logger，支持结构化日志和链路追踪
