# 2. 安装指南

## 系统要求

- **Python 版本**：>= 3.10
- **操作系统**：Linux, macOS, Windows
- **包管理工具**：uv（推荐）或 pip

## 安装方式

### 方式 1：使用 uv（推荐）

uv 是一个极速的 Python 包管理工具，比 pip 快 10-100 倍。

**安装 uv**：
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**创建新项目**：
```bash
uv init my-service
cd my-service
```

**安装 Kit（从 PyPI）**：
```bash
uv add aurimyth-foundation-kit
```

**安装 Kit（从 Git - 开发版本）**：
```bash
uv add git+https://github.com/AuriMythNeo/aurimyth-foundation-kit.git
```

### 方式 2：使用 pip

```bash
# 从 PyPI
pip install aurimyth-foundation-kit

# 从 Git
pip install git+https://github.com/AuriMythNeo/aurimyth-foundation-kit.git
```

### 方式 3：本地开发安装

如果你要修改 Kit 的代码：

```bash
# 克隆仓库
git clone https://github.com/AuriMythNeo/aurimyth-foundation-kit.git
cd aurimyth-foundation-kit

# 使用 uv 安装到本地可编辑模式
uv sync

# 在你的项目中引用本地路径
# pyproject.toml:
# dependencies = [
#     "aurimyth-foundation-kit @ file:///path/to/aurimyth-foundation-kit"
# ]
```

## 依赖安装

### 完整依赖

```toml
[project]
dependencies = [
    "aurimyth-foundation-kit>=0.1.0",
    "uvicorn[standard]>=0.24.0",
    "python-dotenv>=1.0.0",
]
```

### 可选依赖

```toml
[project.optional-dependencies]
# 数据库支持
postgres = [
    "asyncpg>=0.29.0",
    "psycopg[binary]>=3.14.0",
]

# Redis 支持
redis = [
    "redis>=5.0.0",
]

# RabbitMQ 支持
amqp = [
    "aio-pika>=10.0.0",
]

# 开发工具
dev = [
    "pytest>=7.4.0",
    "pytest-asyncio>=0.21.0",
    "pytest-cov>=4.1.0",
    "mypy>=1.5.0",
    "ruff>=0.1.0",
    "black>=23.0.0",
]
```

### 完整 pyproject.toml 示例

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "my-service"
version = "0.1.0"
description = "My AuriMyth service"
readme = "README.md"
requires-python = ">=3.10"
authors = [
    { name = "Your Name", email = "you@example.com" }
]

dependencies = [
    "aurimyth-foundation-kit @ git+https://github.com/AuriMythNeo/aurimyth-foundation-kit.git",
    "uvicorn[standard]>=0.24.0",
    "python-dotenv>=1.0.0",
    "sqlalchemy>=2.0.0",
    "asyncpg>=0.29.0",
    "redis>=5.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.4.0",
    "pytest-asyncio>=0.21.0",
    "mypy>=1.5.0",
    "ruff>=0.1.0",
]

[tool.uv]
python-version = "3.10"

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]

[tool.mypy]
python_version = "3.10"
strict = true
```

## 验证安装

创建 `test_install.py`：

```python
from aurimyth.foundation_kit.application.app.base import FoundationApp
from aurimyth.foundation_kit.application.config import BaseConfig

class Config(BaseConfig):
    pass

app = FoundationApp(
    title="Test App",
    version="0.1.0",
    config=Config()
)

@app.get("/health")
def health_check():
    return {"status": "ok"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

运行验证：
```bash
uv run python test_install.py
```

访问 http://localhost:8000/health 应该返回 `{"status": "ok"}`

## 常见问题

### Q: 能在 Python 3.9 上使用吗？

A: 不行。Kit 使用了 Python 3.10+ 的特性（如类型注解新语法）。必须升级到 3.10+。

### Q: uv 和 pip 有什么区别？

A: uv 更快、更可靠：
- 速度快 10-100 倍
- 自动管理虚拟环境
- 更好的依赖解析
- 内置锁定文件支持

### Q: 如何离线安装？

A: 先在有网的机器上生成 lock 文件：
```bash
uv lock
```

然后离线安装：
```bash
uv sync --frozen
```

### Q: 在 Docker 中安装

```dockerfile
FROM python:3.10-slim

WORKDIR /app

# 安装 uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

COPY pyproject.toml uv.lock ./

# 安装依赖
RUN /root/.local/bin/uv sync --no-dev

COPY . .

CMD ["uv", "run", "python", "main.py"]
```

## 下一步

- 查看 [03-project-structure.md](./03-project-structure.md) 建立项目结构
- 查看 [02-quick-start.md](../00-quick-start.md) 编写第一个应用


