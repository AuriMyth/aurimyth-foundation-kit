# 9. 数据库完全指南

## 概述

Kit 使用 **SQLAlchemy 2.0+** 作为 ORM，支持异步操作和全功能的关系映射。

## 定义模型

### 基础模型

**重要**：不要直接继承 `Base` 类，应使用 Foundation Kit 提供的预定义模型。

**推荐使用**：
- `UUIDAuditableStateModel`：UUID 主键 + 时间戳 + 软删除（最常用）
- `UUIDModel`：UUID 主键 + 时间戳（不需要软删除时）
- `Model`：整数主键 + 时间戳（使用整数主键时）

```python
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, Integer, Boolean, DateTime, ForeignKey, Text
from aurimyth.foundation_kit.domain.models import UUIDAuditableStateModel

class User(UUIDAuditableStateModel):
    """用户模型 - 自动获得 UUID 主键、时间戳和软删除功能"""
    __tablename__ = "users"
    
    # UUIDAuditableStateModel 自动提供：
    # - id: UUID 主键
    # - created_at: 创建时间
    # - updated_at: 更新时间
    # - deleted_at: 软删除时间（0 未删除，>0 已删除时间戳）
    
    # 基本字段
    username: Mapped[str] = mapped_column(String(50), unique=True, nullable=False, index=True)
    email: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    
    # 可选字段
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    bio: Mapped[str | None] = mapped_column(Text, nullable=True)
    
    # 布尔字段
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    
    # 关系（一对多）
    posts: Mapped[list["Post"]] = relationship(back_populates="author")
    
    def __repr__(self) -> str:
        return f"<User(id={self.id}, username={self.username})>"
```

### 关系模型

```python
from aurimyth.foundation_kit.domain.models import UUIDAuditableStateModel

class Post(UUIDAuditableStateModel):
    """文章模型 - 自动获得 UUID 主键、时间戳和软删除功能"""
    __tablename__ = "posts"
    
    # UUIDAuditableStateModel 自动提供 id、created_at、updated_at、deleted_at
    
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    
    # 外键
    author_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    
    # 关系（多对一）
    author: Mapped["User"] = relationship(back_populates="posts")
    
    # 自定义时间戳
    published_at: Mapped[datetime | None] = mapped_column(nullable=True)
```

### 软删除模型

```python
from aurimyth.foundation_kit.domain.models.base import SoftDeleteModel

class Article(SoftDeleteModel):
    """支持软删除的模型"""
    __tablename__ = "articles"
    
    id: Mapped[str] = mapped_column(GUID, primary_key=True, default=lambda: str(uuid4()))
    title: Mapped[str] = mapped_column(String(200))
    content: Mapped[str] = mapped_column(Text)
    
    # SoftDeleteModel 自动提供：
    # deleted_at: Mapped[datetime | None]
    # is_deleted: Mapped[bool]
```

## 创建仓储

### BaseRepository

继承 `BaseRepository` 获得自动 CRUD 操作：

```python
from aurimyth.foundation_kit.domain.repository.impl import BaseRepository
from models import User

class UserRepository(BaseRepository[User]):
    """用户仓储"""
    
    # 继承的自动方法：
    # - create(data: dict) -> User
    # - get(id: str) -> User | None
    # - get_by(**kwargs) -> User | None
    # - list(**kwargs) -> list[User]
    # - paginate(page: int, size: int) -> tuple[list[User], int]
    # - update(id: str, data: dict) -> User
    # - delete(id: str) -> bool
    # - count(**kwargs) -> int
    
    # 自定义查询方法
    async def get_by_email(self, email: str) -> User | None:
        """根据邮箱查询"""
        return await self.get_by(email=email)
    
    async def get_active_users(self, limit: int = 100) -> list[User]:
        """获取活跃用户"""
        return await self.list(is_active=True, limit=limit)
    
    async def search(self, keyword: str) -> list[User]:
        """搜索用户"""
        from sqlalchemy import or_
        return await self.list(
            or_(
                User.username.contains(keyword),
                User.email.contains(keyword)
            )
        )
```

## 在 API 中使用

### 基本 CRUD

```python
from fastapi import APIRouter, Depends, HTTPException
from aurimyth.foundation_kit.infrastructure.database import DatabaseManager
from repositories import UserRepository
from schemas import UserCreateRequest, UserResponse

router = APIRouter()
db_manager = DatabaseManager.get_instance()

# 依赖注入
async def get_user_repo(session=Depends(db_manager.get_session)) -> UserRepository:
    return UserRepository(session)

# 创建
from aurimyth.foundation_kit.application.interfaces.egress import BaseResponse

@router.post("/users")
async def create_user(
    request: UserCreateRequest,
    repo: UserRepository = Depends(get_user_repo)
):
    # 检查重复
    if await repo.get_by_email(request.email):
        raise HTTPException(status_code=400, detail="邮箱已存在")
    
    user = await repo.create({
        "username": request.username,
        "email": request.email,
        "password_hash": hash_password(request.password)
    })
    return BaseResponse(code=200, message="用户创建成功", data=user)

# 读取
@router.get("/users/{user_id}")
async def get_user(user_id: str, repo: UserRepository = Depends(get_user_repo)):
    user = await repo.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")
    return BaseResponse(code=200, message="获取成功", data=user)

# 列表（分页）
from aurimyth.foundation_kit.application.interfaces.egress import PaginationResponse, Pagination

@router.get("/users")
async def list_users(
    page: int = 1,
    size: int = 20,
    repo: UserRepository = Depends(get_user_repo)
):
    items, total = await repo.paginate(page=page, size=size)
    pagination = Pagination(
        total=total,
        items=items,
        page=page,
        size=size
    )
    return PaginationResponse(code=200, message="获取列表成功", data=pagination)

# 更新
@router.put("/users/{user_id}")
async def update_user(
    user_id: str,
    request: UserUpdateRequest,
    repo: UserRepository = Depends(get_user_repo)
):
    user = await repo.get(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")
    
    user = await repo.update(user_id, request.dict(exclude_unset=True))
    return BaseResponse(code=200, message="更新成功", data=user)

# 删除
@router.delete("/users/{user_id}")
async def delete_user(user_id: str, repo: UserRepository = Depends(get_user_repo)):
    if not await repo.delete(user_id):
        raise HTTPException(status_code=404, detail="用户不存在")
    return BaseResponse(code=200, message="删除成功", data=None)
```

## 事务管理

Kit 提供了多种事务管理方式，推荐按场景选择：

### 方式 1：@transactional 装饰器（最简洁）

```python
from aurimyth.foundation_kit.domain.transaction import transactional
from sqlalchemy.ext.asyncio import AsyncSession

# 装饰器自动处理事务开启、提交、回滚
@transactional
async def create_order(session: AsyncSession, request: OrderRequest):
    """创建订单及关联的订单项"""
    order_repo = OrderRepository(session)
    order = await order_repo.create({
        "user_id": request.user_id,
        "total_amount": request.total_amount
    })
    
    # 创建订单项
    item_repo = OrderItemRepository(session)
    for item in request.items:
        await item_repo.create({
            "order_id": order.id,
            "product_id": item.product_id,
            "quantity": item.quantity
        })
    
    # 异常时自动回滚，成功时自动提交
    return order

# 在路由中调用
@router.post("/orders")
async def create_order_api(request: OrderRequest, session=Depends(db_manager.get_session)):
    order = await create_order(session, request)
    return BaseResponse(code=200, message="订单创建成功", data=order)
```

### 方式 2：transactional_context 上下文管理器

```python
from aurimyth.foundation_kit.domain.transaction import transactional_context
from aurimyth.foundation_kit.infrastructure.database import DatabaseManager

db_manager = DatabaseManager.get_instance()

async def create_order(request: OrderRequest):
    """使用上下文管理器管理事务"""
    async with db_manager.session() as session:
        # 自动开启、提交、回滚
        async with transactional_context(session) as txn_session:
            order_repo = OrderRepository(txn_session)
            order = await order_repo.create({
                "user_id": request.user_id,
                "total_amount": request.total_amount
            })
            
            item_repo = OrderItemRepository(txn_session)
            for item in request.items:
                await item_repo.create({
                    "order_id": order.id,
                    "product_id": item.product_id,
                    "quantity": item.quantity
                })
            
            return order
```

### 方式 3：TransactionManager 手动控制

```python
from aurimyth.foundation_kit.domain.transaction import TransactionManager

async def create_order(request: OrderRequest, session: AsyncSession):
    """手动控制事务，适合复杂场景"""
    tm = TransactionManager(session)
    
    try:
        await tm.begin()
        
        order_repo = OrderRepository(session)
        order = await order_repo.create({...})
        
        item_repo = OrderItemRepository(session)
        for item in request.items:
            await item_repo.create({...})
        
        await tm.commit()
        return order
    
    except Exception as e:
        await tm.rollback()
        raise

# 或使用上下文管理器形式
async def create_order_alt(request: OrderRequest, session: AsyncSession):
    tm = TransactionManager(session)
    async with tm:  # 自动 commit/rollback
        order_repo = OrderRepository(session)
        order = await order_repo.create({...})
        return order
```

### 方式 4：session.begin() 原始方式

```python
# 仍然支持原始 SQLAlchemy 方式
async with db_manager.session() as session:
    async with session.begin():
        repo = OrderRepository(session)
        order = await repo.create({...})
```

### 事务特性

**自动提交/回滚**：
```python
@transactional
async def operation(session: AsyncSession):
    repo = UserRepository(session)
    
    # 成功执行：自动 commit
    user = await repo.create({"username": "john"})
    
    # 异常抛出：自动 rollback
    if not user:
        raise ValueError("创建失败")
    
    return user
```

**嵌套事务支持**：
```python
@transactional
async def outer_transaction(session: AsyncSession):
    repo1 = Repo1(session)
    result1 = await repo1.create({...})
    
    # 嵌套调用另一个 @transactional 函数
    result2 = await inner_transaction(session)  # 不会重复开启事务
    
    return result1, result2

@transactional
async def inner_transaction(session: AsyncSession):
    repo2 = Repo2(session)
    return await repo2.create({...})
```

**事务检查**：
```python
from aurimyth.foundation_kit.domain.transaction import (
    ensure_transaction,
    requires_transaction
)

# 检查是否在事务中
if ensure_transaction(session):
    print("已在事务中")

# 强制要求在事务中
class UserRepository(BaseRepository):
    @requires_transaction
    async def sensitive_update(self, data):
        # 此方法必须在事务中调用
        # 否则抛出 TransactionRequiredError
        return await self.update(data)
```

## 查询优化

### 避免 N+1 查询

❌ **错误**：
```python
users = await repo.list()
for user in users:
    posts = await post_repo.list(author_id=user.id)  # N 次查询！
```

✅ **正确**：使用 `selectinload`
```python
from sqlalchemy.orm import selectinload
from sqlalchemy import select

class UserRepository(BaseRepository[User]):
    async def list_with_posts(self):
        stmt = select(User).options(selectinload(User.posts))
        result = await self.session.execute(stmt)
        return result.scalars().all()

users = await repo.list_with_posts()
for user in users:
    # posts 已加载，不会再查询
    print(len(user.posts))
```

### 批量操作

```python
# 批量创建
users_data = [
    {"username": f"user{i}", "email": f"user{i}@example.com"}
    for i in range(1000)
]
await repo.bulk_create(users_data, batch_size=100)

# 批量更新
updates = [
    {"id": user_id, "is_active": False}
    for user_id in inactive_ids
]
await repo.bulk_update(updates)

# 批量删除
await repo.bulk_delete(ids_to_delete)
```

## 高级特性

### 自定义查询条件

```python
from sqlalchemy import and_, or_

async def advanced_search(
    repo: UserRepository,
    keyword: str | None = None,
    is_active: bool | None = None,
    created_after: datetime | None = None
):
    conditions = []
    
    if keyword:
        conditions.append(
            or_(
                User.username.contains(keyword),
                User.email.contains(keyword)
            )
        )
    
    if is_active is not None:
        conditions.append(User.is_active == is_active)
    
    if created_after:
        conditions.append(User.created_at >= created_after)
    
    if conditions:
        result = await repo.list(and_(*conditions))
    else:
        result = await repo.list()
    
    return result
```

### 聚合查询

```python
from sqlalchemy import func

async def get_statistics(repo: UserRepository):
    stmt = select(
        func.count(User.id).label("total_users"),
        func.sum(User.id.notexists()).label("active_users"),
    )
    result = await repo.session.execute(stmt)
    return result.first()
```

## 数据库连接配置

### PostgreSQL

```bash
DATABASE_URL=postgresql+asyncpg://user:password@localhost:5432/dbname
DATABASE_POOL_SIZE=10
DATABASE_MAX_OVERFLOW=20
DATABASE_POOL_RECYCLE=3600
DATABASE_ECHO=false  # 是否打印 SQL
```

### MySQL

```bash
DATABASE_URL=mysql+aiomysql://user:password@localhost:3306/dbname
```

### SQLite（开发用）

```bash
DATABASE_URL=sqlite+aiosqlite:///./test.db
```

## 常见问题

### Q: 如何处理大批量数据？

A: 分批处理：
```python
batch_size = 1000
for offset in range(0, total_count, batch_size):
    batch = await repo.list(offset=offset, limit=batch_size)
    await process_batch(batch)
```

### Q: 如何处理并发更新冲突？

A: 使用版本字段（乐观锁）：
```python
class Entity(Base):
    version: Mapped[int] = mapped_column(Integer, default=1)

# 更新时检查版本
async def update_with_version(repo, id, data, expected_version):
    entity = await repo.get(id)
    if entity.version != expected_version:
        raise VersionConflictError()
    
    await repo.update(id, {**data, "version": expected_version + 1})
```

### Q: 如何处理时区问题？

A: 总是使用 UTC：
```python
from datetime import datetime, timezone

def now() -> datetime:
    return datetime.now(timezone.utc)

class Entity(Base):
    created_at: Mapped[datetime] = mapped_column(default=now)
```

## 下一步

- 查看 [18-migration-guide.md](./18-migration-guide.md) 学习数据库迁移
- 查看 [20-best-practices.md](./20-best-practices.md) 查看最佳实践

