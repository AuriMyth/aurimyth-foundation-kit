# 🚀 AuriMyth Foundation Kit

欢迎使用 **AuriMyth Foundation Kit** - 现代化微服务基础架构框架！

这是一款专为构建高性能、可扩展微服务而设计的 Python 框架，提供了开箱即用的企业级功能。

## ⚡ 快速开始

### 安装

```bash
# 使用 uv（推荐）
uv add aurimyth-foundation-kit

# 或使用 pip
pip install aurimyth-foundation-kit
```

### Hello World

```python
from aurimyth.foundation_kit.application.app.base import FoundationApp
from aurimyth.foundation_kit.application.config import BaseConfig
from aurimyth.foundation_kit.application.server import run_app
from aurimyth.foundation_kit.application.interfaces.egress import BaseResponse

class AppConfig(BaseConfig):
    pass

app = FoundationApp(
    title="My Service",
    version="0.1.0",
    config=AppConfig()
)

@app.get("/")
def hello():
    return BaseResponse(code=200, message="Hello", data={"message": "Hello AuriMyth!"})

if __name__ == "__main__":
    run_app(app, host="0.0.0.0", port=8000)
```

### 运行

```bash
# 开发模式（热重载）
aurimyth-server dev

# 生产模式（多进程）
aurimyth-server prod
```

访问 http://localhost:8000

## 📚 文档结构

本文档共 22 个章节，分为四个主要部分：

### 基础部分（5 章）
- [快速开始](./00-quick-start.md) - 所有功能的速查手册
- [Framework 架构](./01-intro-detailed.md) - 理解设计理念
- [安装指南](./02-installation-guide.md) - 完整的依赖安装
- [服务器运行](./03-server-deployment.md) - 启动和部署应用
- [项目结构](./04-project-structure.md) - 推荐的项目组织
- [配置管理](./05-configuration-advanced.md) - 灵活的配置系统

### 核心功能（6 章）
- [依赖注入](./06-di-container-complete.md) - DI 容器系统
- [应用组件](./07-components-detailed.md) - 生命周期管理
- [HTTP 接口](./08-http-advanced.md) - Ingress/Egress 完整讲解
- [错误处理](./09-error-handling-guide.md) - 异常体系
- [事务管理](./10-transaction-management.md) - 4 种事务方式
- [数据库](./11-database-complete.md) - ORM 和数据访问

### 高级功能（10 章）
- [缓存系统](./12-caching-advanced.md)
- [异步任务](./13-async-tasks-guide.md)
- [事件驱动](./14-events-driven.md)
- [定时调度](./15-scheduler-guide.md)
- [RPC 微服务](./16-rpc-microservices.md)
- [WebSocket](./17-websocket-guide.md)
- [对象存储](./18-storage-guide.md)
- [国际化](./19-i18n-guide.md)
- [数据库迁移](./20-migration-guide.md)
- [日志系统](./21-logging-complete.md)

### 最佳实践（1 章）
- [最佳实践](./22-best-practices.md) - 架构、性能、测试

## ✨ 核心特性

### 统一的组件管理
```python
app.add_component(DatabaseComponent())
app.add_component(CacheComponent())
app.add_component(TaskComponent())
```

### 企业级 DI 容器
```python
container = Container.get_instance()
container.register_singleton(UserService)
service = container.resolve(UserService)
```

### 标准化 API 响应
```python
return BaseResponse(code=200, message="Success", data=user)
```

### 完整的事务支持
```python
@transactional
async def create_order(session: AsyncSession, request: OrderRequest):
    # 自动处理提交和回滚
    pass
```

### 微服务开箱即用
- 服务发现
- RPC 通信
- 分布式链路追踪
- 负载均衡

## 🎯 学习路径

### 5 分钟快速上手
1. 读 [快速开始](./00-quick-start.md)
2. 按照 Hello World 示例运行

### 30 分钟完整应用
1. [项目结构](./04-project-structure.md)
2. [HTTP 接口](./08-http-advanced.md)
3. [数据库](./11-database-complete.md)

### 深入理解框架
1. [Framework 架构](./01-intro-detailed.md)
2. [DI 容器](./06-di-container-complete.md)
3. [组件系统](./07-components-detailed.md)

## 🔍 快速查找

| 需求 | 文档 |
|------|------|
| 如何启动应用？ | [服务器运行](./03-server-deployment.md) |
| 如何定义 API？ | [HTTP 接口](./08-http-advanced.md) |
| 如何操作数据库？ | [数据库](./11-database-complete.md) |
| 如何处理错误？ | [错误处理](./09-error-handling-guide.md) |
| 如何组织项目？ | [项目结构](./04-project-structure.md) |
| 如何优化性能？ | [最佳实践](./22-best-practices.md) |

## 💡 常见问题

### Q: 我应该从哪里开始？
A: 从 [快速开始](./00-quick-start.md) 开始，这是所有功能的速查手册。

### Q: 如何连接数据库？
A: 查看 [项目结构](./04-project-structure.md) 和 [数据库](./11-database-complete.md)。

### Q: 如何部署到生产环境？
A: 查看 [服务器运行](./03-server-deployment.md) 中的生产模式配置。

## 🌟 框架优势

- ✅ **开箱即用** - 所有企业级功能都已集成
- ✅ **标准化** - 遵循微服务最佳实践
- ✅ **高性能** - 异步优先设计
- ✅ **可扩展** - 灵活的组件和 DI 系统
- ✅ **易维护** - 清晰的代码结构和完整文档

## 🚀 下一步

1. **[安装](./02-installation-guide.md)** - 按照步骤安装依赖
2. **[快速开始](./00-quick-start.md)** - 5 分钟了解所有功能
3. **[项目结构](./04-project-structure.md)** - 建立项目骨架
4. **[构建应用](./08-http-advanced.md)** - 开始编写代码

## 📞 支持

- 📖 [完整文档](./00-quick-start.md)
- 🐛 [GitHub Issues](https://github.com/AuriMythNeo/aurimyth-foundation-kit/issues)
- 💬 [GitHub Discussions](https://github.com/AuriMythNeo/aurimyth-foundation-kit/discussions)

---

**现在就开始构建高性能的微服务吧！** 🎉


