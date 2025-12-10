# 6. 组件系统 - 完整指南

## 组件系统概述

组件是 Kit 的**生命周期管理单位**，统一抽象基础设施的初始化和清理。

### 为什么需要组件系统？

```python
# ❌ 传统做法：手动管理生命周期
@app.on_event("startup")
async def startup():
    global db, cache, logger
    db = await init_db()
    cache = await init_cache()
    logger = init_logger()

@app.on_event("shutdown")
async def shutdown():
    await db.close()
    await cache.close()
    logger.close()

# ✅ 使用组件系统：自动管理
class DatabaseComponent(Component):
    async def setup(self, app, config):
        app.db = await init_db()
    async def teardown(self, app):
        await app.db.close()

# 清晰、可复用、易于测试
```

## 组件结构

### 基类定义

```python
from aurimyth.foundation_kit.application.app.base import Component, FoundationApp
from aurimyth.foundation_kit.application.config import BaseConfig
from typing import ClassVar

class Component(ABC):
    name: str                            # 组件唯一标识
    enabled: bool = True                 # 是否启用
    depends_on: ClassVar[list[str]] = [] # 依赖的组件
    
    def can_enable(self, config: BaseConfig) -> bool:
        """条件启用：返回 False 则跳过此组件"""
        return self.enabled
    
    async def setup(self, app: FoundationApp, config: BaseConfig) -> None:
        """应用启动时调用"""
        pass
    
    async def teardown(self, app: FoundationApp) -> None:
        """应用关闭时调用"""
        pass
```

## 内置组件详解

### 1. RequestLoggingComponent

HTTP 请求日志中间件。

```python
from aurimyth.foundation_kit.application.app.components import RequestLoggingComponent

app = FoundationApp(config=config)
app.add_component(RequestLoggingComponent())

# 自动记录每个 HTTP 请求
# 日志格式包含：请求方法、路径、客户端IP、响应时间、Trace ID 等
```

### 2. DatabaseComponent

管理数据库连接和连接池。

```python
from aurimyth.foundation_kit.application.app.components import DatabaseComponent

app.add_component(DatabaseComponent())

# 自动初始化：
# - 创建异步引擎
# - 建立连接池
# - 创建会话工厂
# - 注册 SQLAlchemy 事件监听

# 在路由中使用
from aurimyth.foundation_kit.infrastructure.database import DatabaseManager

db_manager = DatabaseManager.get_instance()

@app.get("/users")
async def list_users(session=Depends(db_manager.get_session)):
    repo = UserRepository(session)
    return await repo.list()
```

### 3. CacheComponent

管理缓存系统（Redis 或内存）。

```python
from aurimyth.foundation_kit.application.app.components import CacheComponent

app.add_component(CacheComponent())

# 根据配置自动选择后端：
# CACHE_TYPE=memory    → 内存缓存（开发）
# CACHE_TYPE=redis     → Redis 缓存（生产）

from aurimyth.foundation_kit.infrastructure.cache import CacheManager

cache = CacheManager.get_instance()
await cache.set("key", "value", expire=300)
```

### 4. TaskComponent

管理异步任务队列。

```python
from aurimyth.foundation_kit.application.app.components import TaskComponent

app.add_component(TaskComponent())

# 在 API 模式下：作为生产者，提交任务到队列
# 在 Worker 模式下：消费队列中的任务

from aurimyth.foundation_kit.infrastructure.tasks.manager import TaskManager

tm = TaskManager.get_instance()

@tm.conditional_task(queue_name="default", max_retries=3)
async def send_email(email: str):
    pass

# 提交任务
send_email.send("user@example.com")
```

### 5. SchedulerComponent

管理定时任务调度。

```python
from aurimyth.foundation_kit.application.app.components import SchedulerComponent

app.add_component(SchedulerComponent())

# 在 API 模式下：嵌入式运行（embedded）
# 在 Scheduler 模式下：独立进程运行

from aurimyth.foundation_kit.infrastructure.scheduler.manager import SchedulerManager

scheduler = SchedulerManager.get_instance()

scheduler.add_job(
    func=daily_cleanup,
    trigger="cron",
    hour=2, minute=0
)
```

### 6. CORSComponent

处理 CORS 跨域请求。

```python
from aurimyth.foundation_kit.application.app.components import CORSComponent

app.add_component(CORSComponent())

# 配置 CORS
# CORS_ORIGINS=["http://localhost:3000"]
# CORS_ALLOW_CREDENTIALS=true
# CORS_ALLOW_METHODS=["GET", "POST"]
# CORS_ALLOW_HEADERS=["*"]
```

## 自定义组件

### 基本结构

```python
from aurimyth.foundation_kit.application.app.base import Component, FoundationApp
from aurimyth.foundation_kit.application.config import BaseConfig
from typing import ClassVar

class MyCustomComponent(Component):
    name = "my_custom"           # 唯一标识
    enabled = True               # 是否启用
    depends_on: ClassVar[list[str]] = ["database"]  # 依赖关系
    
    def can_enable(self, config: BaseConfig) -> bool:
        """条件启用：检查配置决定是否启用"""
        # 例如：仅在配置了某个值时才启用
        return config.my_feature_enabled if hasattr(config, 'my_feature_enabled') else True
    
    async def setup(self, app: FoundationApp, config: BaseConfig) -> None:
        """应用启动时调用"""
        print("🚀 初始化...")
        # 初始化逻辑
        app.state.my_resource = SomeResource()
    
    async def teardown(self, app: FoundationApp) -> None:
        """应用关闭时调用"""
        print("🛑 清理...")
        # 清理逻辑
        if hasattr(app.state, 'my_resource'):
            await app.state.my_resource.close()
```

### 实际示例：Redis 连接池

```python
class RedisConnectionComponent(Component):
    name = "redis"
    enabled = True
    depends_on = []
    
    def can_enable(self, config: BaseConfig) -> bool:
        """仅当配置了 Redis 时启用"""
        return bool(config.cache.redis_url if hasattr(config.cache, 'redis_url') else False)
    
    async def setup(self, app: FoundationApp, config: BaseConfig) -> None:
        """初始化 Redis 连接"""
        import redis.asyncio as redis
        
        pool = redis.ConnectionPool.from_url(
            config.cache.redis_url,
            max_connections=config.cache.max_connections if hasattr(config.cache, 'max_connections') else 50
        )
        app.state.redis_pool = pool
        
        logger.info(f"✅ Redis 已连接: {config.cache.redis_url}")
    
    async def teardown(self, app: FoundationApp) -> None:
        """关闭 Redis 连接"""
        if hasattr(app.state, 'redis_pool'):
            await app.state.redis_pool.disconnect()
            logger.info("✅ Redis 已断开连接")
```

## 组件注册方式

### 方式 1：在 FoundationApp 的 items 中注册（推荐）

```python
from aurimyth.foundation_kit.application.app.base import FoundationApp
from aurimyth.foundation_kit.application.app.components import (
    RequestLoggingComponent,
    DatabaseComponent,
    CacheComponent,
)

class MyApp(FoundationApp):
    """自定义应用类"""
    items = [
        RequestLoggingComponent,
        DatabaseComponent,
        CacheComponent,
        MyCustomComponent,  # 自定义组件
    ]

app = MyApp(config=config)
```

### 方式 2：直接添加（临时注册）

```python
app = FoundationApp(config=config)

# 添加单个组件
app.add_component(MyCustomComponent())

# 或
app.items.append(MyCustomComponent)
app._register_components()  # 重新注册
```

### 方式 3：条件注册

```python
class MyApp(FoundationApp):
    items = [
        RequestLoggingComponent,
        DatabaseComponent,
    ]
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        
        # 根据条件动态添加
        if self.config.enable_redis:
            self.add_component(RedisConnectionComponent())
        
        if self.config.enable_tasks:
            self.add_component(TaskComponent())
```

## 组件依赖管理

### 依赖关系声明

```python
class ComponentA(Component):
    name = "a"
    depends_on = []

class ComponentB(Component):
    name = "b"
    depends_on = ["a"]  # 依赖 A

class ComponentC(Component):
    name = "c"
    depends_on = ["a", "b"]  # 依赖 A 和 B

# 启动顺序：A → B → C
# 关闭顺序：C → B → A（反向）
```

### 循环依赖检测

```python
class ComponentX(Component):
    name = "x"
    depends_on = ["y"]

class ComponentY(Component):
    name = "y"
    depends_on = ["x"]  # 循环依赖！

# 框架会抛出异常：
# "Circular dependency detected: x -> y -> x"
```

## 访问其他组件的资源

```python
class ComponentWithDependency(Component):
    name = "dependent"
    depends_on = ["database", "cache"]
    
    async def setup(self, app: FoundationApp, config: BaseConfig) -> None:
        # 访问其他组件初始化的资源
        db_manager = app.state.db_manager  # 由 DatabaseComponent 初始化
        cache = app.state.cache            # 由 CacheComponent 初始化
        
        # 使用它们
        app.state.my_service = MyService(db_manager, cache)
```

## 组件生命周期钩子

### 启动事件

```python
@app.on_event("startup")
async def on_startup():
    """应用启动完全完成后调用"""
    # 所有组件已初始化
    logger.info("应用已完全启动")

# 与组件的 setup() 区别：
# - setup()：在每个组件启动时调用
# - on_event("startup")：在所有组件启动后调用
```

### 关闭事件

```python
@app.on_event("shutdown")
async def on_shutdown():
    """应用关闭前调用"""
    logger.info("应用正在关闭")
```

## 最佳实践

### ✅ 推荐做法

1. **单一职责**：每个组件只管理一个资源
   ```python
   # ✅ 好
   class DatabaseComponent(Component): ...
   class CacheComponent(Component): ...
   
   # ❌ 不好
   class InfrastructureComponent(Component):
       async def setup(self, ...):
           app.state.db = ...
           app.state.cache = ...
   ```

2. **明确声明依赖**
   ```python
   # ✅ 好
   depends_on = ["database", "cache"]
   
   # ❌ 不好
   depends_on = []  # 但实际依赖 database
   ```

3. **条件启用**
   ```python
   # ✅ 好
   def can_enable(self, config):
       return bool(config.redis_url)
   
   # ❌ 不好
   def can_enable(self, config):
       return True  # 即使配置不完整
   ```

4. **异常处理**
   ```python
   # ✅ 好
   async def setup(self, app, config):
       try:
           app.state.resource = await init_resource()
           logger.info("Resource initialized")
       except Exception as e:
           logger.error(f"Failed to initialize resource: {e}")
           raise
   
   # ❌ 不好
   async def setup(self, app, config):
       app.state.resource = await init_resource()  # 异常会导致应用启动失败
   ```

### ❌ 避免的做法

1. **在 setup() 中执行长时间操作**
   - 会导致应用启动缓慢
   - 使用后台任务代替

2. **在 teardown() 中忽略异常**
   - 可能导致资源泄漏
   - 总是捕获和处理异常

3. **组件间直接通信**
   - 应该通过应用状态通信
   - 不要直接依赖其他组件实例

## 下一步

- 查看 [09-database-complete.md](./09-database-complete.md) 了解 DatabaseComponent 的详细用法
- 查看 [05-di-container-complete.md](./05-di-container-complete.md) 了解如何与 DI 容器配合

