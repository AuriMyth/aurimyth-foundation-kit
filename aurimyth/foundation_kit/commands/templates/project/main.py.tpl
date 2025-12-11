"""应用入口。

使用方式：
    # 开发模式
    aum server dev

    # 生产模式
    aum server prod
"""

from aurimyth.foundation_kit.application.app.base import FoundationApp
from aurimyth.foundation_kit.application.app.components import (
    CacheComponent,
    DatabaseComponent,
    MigrationComponent,
    SchedulerComponent,
)
from aurimyth.foundation_kit.application.interfaces.egress import BaseResponse

from {import_prefix}config import AppConfig

# 创建配置
config = AppConfig()

# 创建应用
app = FoundationApp(
    title="{project_name}",
    version="0.1.0",
    description="{project_name} - 基于 AuriMyth Foundation Kit",
    config=config,
)


# 注册 API 路由
from {import_prefix}api import router as api_router
app.include_router(api_router, prefix="/api")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)
