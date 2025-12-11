"""日志管理器 - 统一的日志配置和管理。

提供：
- 统一的日志配置（多日志级别、滚动机制）
- 性能监控装饰器
- 异常日志装饰器
- 链路追踪 ID 支持
- 自定义日志 sink 注册 API

日志文件：
- {service_type}_info_{date}.log  - INFO/WARNING/DEBUG 日志
- {service_type}_error_{date}.log - ERROR/CRITICAL 日志
- 可通过 register_log_sink() 注册自定义日志文件（如 access.log）

注意：HTTP 相关的日志功能（RequestLoggingMiddleware, log_request）已移至
application.middleware.logging
"""

from __future__ import annotations

from collections.abc import Callable
from contextvars import ContextVar
from enum import Enum
from functools import wraps
import os
import time
from typing import Any
import uuid

from loguru import logger

# 移除默认配置，由setup_logging统一配置
logger.remove()

# ============================================================
# 服务上下文（ContextVar）
# ============================================================

class ServiceContext(str, Enum):
    """日志用服务上下文常量（避免跨层依赖）。"""
    API = "api"
    SCHEDULER = "scheduler"
    WORKER = "worker"

# 当前服务上下文（用于决定日志写入哪个文件）
_service_context: ContextVar[ServiceContext] = ContextVar("service_context", default=ServiceContext.API)

# 链路追踪 ID
_trace_id_var: ContextVar[str] = ContextVar("trace_id", default="")


def get_service_context() -> ServiceContext:
    """获取当前服务上下文。"""
    return _service_context.get()


def _to_service_context(ctx: ServiceContext | str) -> ServiceContext:
    """将输入标准化为 ServiceContext。"""
    if isinstance(ctx, ServiceContext):
        return ctx
    val = str(ctx).strip().lower()
    if val == "app":  # 兼容旧值
        val = ServiceContext.API.value
    try:
        return ServiceContext(val)
    except ValueError:
        return ServiceContext.API


def set_service_context(context: ServiceContext | str) -> None:
    """设置当前服务上下文。

    在调度器任务执行前调用 set_service_context("scheduler")，
    后续该任务中的所有日志都会写入 scheduler_xxx.log。

    Args:
        context: 服务类型（api/scheduler/worker，或兼容 "app"）
    """
    _service_context.set(_to_service_context(context))


def get_trace_id() -> str:
    """获取当前链路追踪ID。

    如果尚未设置，则生成一个新的随机 ID。
    """
    trace_id = _trace_id_var.get()
    if not trace_id:
        trace_id = str(uuid.uuid4())
        _trace_id_var.set(trace_id)
    return trace_id


def set_trace_id(trace_id: str) -> None:
    """设置链路追踪ID。"""
    _trace_id_var.set(trace_id)


# ============================================================
# 日志配置
# ============================================================

# 全局日志配置状态
_log_config: dict[str, Any] = {
    "log_dir": "logs",
    "rotation": "00:00",
    "retention_days": 7,
    "file_format": "",
    "initialized": False,
}


def register_log_sink(
    name: str,
    *,
    filter_key: str | None = None,
    level: str = "INFO",
    sink_format: str | None = None,
) -> None:
    """注册自定义日志 sink。
    
    使用 logger.bind() 标记的日志会写入对应文件。
    
    Args:
        name: 日志文件名前缀（如 "access" -> access_2024-01-01.log）
        filter_key: 过滤键名，日志需要 logger.bind(key=True) 才会写入
        level: 日志级别
        sink_format: 自定义格式（默认使用简化格式）
    
    使用示例:
        # 注册 access 日志
        register_log_sink("access", filter_key="access")
        
        # 写入 access 日志
        logger.bind(access=True).info("GET /api/users 200 0.05s")
    """
    if not _log_config["initialized"]:
        raise RuntimeError("请先调用 setup_logging() 初始化日志系统")
    
    log_dir = _log_config["log_dir"]
    rotation = _log_config["rotation"]
    retention_days = _log_config["retention_days"]
    
    default_format = (
        "{time:YYYY-MM-DD HH:mm:ss} | "
        "{extra[trace_id]} | "
        "{message}"
    )
    
    # 创建 filter
    if filter_key:
        def sink_filter(record, key=filter_key):
            return record["extra"].get(key, False)
    else:
        sink_filter = None
    
    logger.add(
        os.path.join(log_dir, f"{name}_{{time:YYYY-MM-DD}}.log"),
        rotation=rotation,
        retention=f"{retention_days} days",
        level=level,
        format=sink_format or default_format,
        encoding="utf-8",
        enqueue=True,
        delay=True,
        filter=sink_filter,
    )
    
    logger.debug(f"注册日志 sink: {name} (filter_key={filter_key})")


def setup_logging(
    log_level: str = "INFO",
    log_dir: str | None = None,
    service_type: ServiceContext | str = ServiceContext.API,
    enable_file_rotation: bool = True,
    rotation_time: str = "00:00",
    retention_days: int = 7,
    rotation_size: str = "100 MB",
    enable_console: bool = True,
) -> None:
    """设置日志配置。

    日志文件按服务类型分离：
    - {service_type}_info_{date}.log  - INFO/WARNING/DEBUG 日志
    - {service_type}_error_{date}.log - ERROR/CRITICAL 日志
    
    可通过 register_log_sink() 注册额外的日志文件（如 access.log）。

    Args:
        log_level: 日志级别（DEBUG/INFO/WARNING/ERROR/CRITICAL）
        log_dir: 日志目录（默认：./logs）
        service_type: 服务类型（app/scheduler/worker）
        enable_file_rotation: 是否启用每日滚动
        rotation_time: 每日滚动时间（默认：00:00）
        retention_days: 日志保留天数（默认：7 天）
        rotation_size: 单文件大小上限（默认：100 MB）
        enable_console: 是否输出到控制台
    """
    log_level = log_level.upper()
    log_dir = log_dir or "logs"
    os.makedirs(log_dir, exist_ok=True)
    
    # 滚动策略
    rotation = rotation_time if enable_file_rotation else rotation_size

    # 标准化服务类型
    service_type_enum = _to_service_context(service_type)

    # 清理旧的 sink，避免重复日志（idempotent）
    logger.remove()

    # 保存全局配置（供 register_log_sink 使用）
    _log_config.update({
        "log_dir": log_dir,
        "rotation": rotation,
        "retention_days": retention_days,
        "initialized": True,
    })

    # 设置默认服务上下文
    set_service_context(service_type_enum)

    console_format = (
        "<green>{time:YYYY-MM-DD HH:mm:ss}</green> | "
        "<cyan>[{extra[service]}]</cyan> | "
        "<level>{level: <8}</level> | "
        "<cyan>{name}:{function}:{line}</cyan> | "
        "{extra[trace_id]:.8} - "
        "<level>{message}</level>"
    )

    file_format = (
        "{time:YYYY-MM-DD HH:mm:ss} | "
        "{level: <8} | "
        "{name}:{function}:{line} | "
        "{extra[trace_id]} - "
        "{message}"
    )
    
    _log_config["file_format"] = file_format

    # 配置 patcher，确保每条日志都有 service 和 trace_id
    logger.configure(patcher=lambda record: (
        record["extra"].update({
            "trace_id": get_trace_id(),
            # 记录字符串值，便于过滤器比较
            "service": get_service_context().value,
        })
    ))

    # 控制台输出
    if enable_console:
        logger.add(
            lambda msg: print(msg, end=""),
            format=console_format,
            level=log_level,
            colorize=True,
        )

    # 为 app 和 scheduler 分别创建日志文件（通过 ContextVar 区分）
    # API 模式下会同时运行嵌入式 scheduler，需要两个文件
    contexts_to_create: list[str] = [service_type_enum.value]
    # API 模式下也需要 scheduler 日志文件
    if service_type_enum is ServiceContext.API:
        contexts_to_create.append(ServiceContext.SCHEDULER.value)
    
    for ctx in contexts_to_create:
        # INFO 级别文件
        if enable_file_rotation:
            logger.add(
                os.path.join(log_dir, f"{ctx}_info_{{time:YYYY-MM-DD}}.log"),
                rotation=rotation,
                retention=f"{retention_days} days",
                level=log_level,
                format=file_format,
                encoding="utf-8",
                enqueue=True,
                filter=lambda record, c=ctx: (
                    record["extra"].get("service") == c
                    and record["level"].name not in ("ERROR", "CRITICAL")
                    and not record["extra"].get("access", False)  # access 日志单独处理
                ),
            )
        else:
            logger.add(
                os.path.join(log_dir, f"{ctx}_info.log"),
                rotation=rotation,
                retention=f"{retention_days} days",
                level=log_level,
                format=file_format,
                encoding="utf-8",
                enqueue=True,
                filter=lambda record, c=ctx: (
                    record["extra"].get("service") == c
                    and record["level"].name not in ("ERROR", "CRITICAL")
                    and not record["extra"].get("access", False)
                ),
            )

        # ERROR 级别文件
        if enable_file_rotation:
            logger.add(
                os.path.join(log_dir, f"{ctx}_error_{{time:YYYY-MM-DD}}.log"),
                rotation=rotation,
                retention=f"{retention_days} days",
                level="ERROR",
                format=file_format,
                encoding="utf-8",
                enqueue=True,
                filter=lambda record, c=ctx: record["extra"].get("service") == c,
            )
        else:
            logger.add(
                os.path.join(log_dir, f"{ctx}_error.log"),
                rotation=rotation,
                retention=f"{retention_days} days",
                level="ERROR",
                format=file_format,
                encoding="utf-8",
                enqueue=True,
                filter=lambda record, c=ctx: record["extra"].get("service") == c,
            )

    logger.info(f"日志系统初始化完成 | 服务: {service_type} | 级别: {log_level} | 目录: {log_dir}")


def log_performance(threshold: float = 1.0) -> Callable:
    """性能监控装饰器。
    
    记录函数执行时间，超过阈值时警告。
    
    Args:
        threshold: 警告阈值（秒）
    
    使用示例:
        @log_performance(threshold=0.5)
        async def slow_operation():
            # 如果执行时间超过0.5秒，会记录警告
            pass
    """
    def decorator[T](func: Callable[..., T]) -> Callable[..., T]:
        @wraps(func)
        async def wrapper(*args, **kwargs) -> T:
            start_time = time.time()
            try:
                result = await func(*args, **kwargs)
                duration = time.time() - start_time
                
                if duration > threshold:
                    logger.warning(
                        f"性能警告: {func.__module__}.{func.__name__} 执行耗时 {duration:.3f}s "
                        f"(阈值: {threshold}s)"
                    )
                else:
                    logger.debug(
                        f"性能: {func.__module__}.{func.__name__} 执行耗时 {duration:.3f}s"
                    )
                
                return result
            except Exception as exc:
                duration = time.time() - start_time
                logger.error(
                    f"执行失败: {func.__module__}.{func.__name__} | "
                    f"耗时: {duration:.3f}s | "
                    f"异常: {type(exc).__name__}: {exc}"
                )
                raise
        
        return wrapper
    return decorator


def log_exceptions[T](func: Callable[..., T]) -> Callable[..., T]:
    """异常日志装饰器。
    
    自动记录函数抛出的异常。
    
    使用示例:
        @log_exceptions
        async def risky_operation():
            # 如果抛出异常，会自动记录
            pass
    """
    @wraps(func)
    async def wrapper(*args, **kwargs) -> T:
        try:
            return await func(*args, **kwargs)
        except Exception as exc:
            logger.exception(
                f"异常捕获: {func.__module__}.{func.__name__} | "
                f"参数: args={args}, kwargs={kwargs} | "
                f"异常: {type(exc).__name__}: {exc}"
            )
            raise
    
    return wrapper


def get_class_logger(obj: object) -> Any:
    """获取类专用的日志器（函数式工具函数）。
    
    根据对象的类和模块名创建绑定的日志器。
    
    Args:
        obj: 对象实例或类
        
    Returns:
        绑定的日志器实例
        
    使用示例:
        class MyService:
            def do_something(self):
                log = get_class_logger(self)
                log.info("执行操作")
    """
    if isinstance(obj, type):
        class_name = obj.__name__
        module_name = obj.__module__
    else:
        class_name = obj.__class__.__name__
        module_name = obj.__class__.__module__
    return logger.bind(name=f"{module_name}.{class_name}")


__all__ = [
    "ServiceContext",
    "get_class_logger",
    "get_service_context",
    "get_trace_id",
    "log_exceptions",
    "log_performance",
    "logger",
    "register_log_sink",
    "set_service_context",
    "set_trace_id",
    "setup_logging",
]

