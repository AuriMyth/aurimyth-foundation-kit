# 18. 对象存储指南

请参考 [00-quick-start.md](./00-quick-start.md) 第 18 章的基础用法。

## 初始化存储

### S3 兼容存储

```python
from aurimyth.foundation_kit.infrastructure.storage.factory import StorageFactory
from aurimyth.foundation_kit.infrastructure.storage.base import StorageFile

# 初始化 S3
storage = await StorageFactory.create(
    "s3",
    access_key_id="your_access_key",
    access_key_secret="your_secret_key",
    bucket_name="my-bucket",
    endpoint_url="https://s3.amazonaws.com",  # 可选
    region="us-east-1"  # 可选
)
```

### 本地存储

```python
# 本地文件系统
storage = await StorageFactory.create(
    "local",
    bucket_name="./uploads"  # 本地目录
)
```

## 基本操作

### 上传文件

```python
from pathlib import Path

# 上传单个文件
with open("avatar.png", "rb") as f:
    url = await storage.upload_file(
        StorageFile(
            data=f,
            object_name="avatars/user_123.png"
        )
    )
    print(f"文件已上传: {url}")
```

### 下载文件

```python
# 下载文件
content = await storage.download_file("avatars/user_123.png")

# 保存到本地
with open("downloaded_avatar.png", "wb") as f:
    f.write(content)
```

### 删除文件

```python
# 删除单个文件
await storage.delete_file("avatars/user_123.png")

# 批量删除
await storage.delete_files([
    "avatars/user_123.png",
    "avatars/user_456.png"
])
```

## 文件操作

### 检查文件存在

```python
exists = await storage.exists("avatars/user_123.png")
if exists:
    print("文件已存在")
```

### 获取文件信息

```python
# 获取文件大小
size = await storage.get_file_size("avatars/user_123.png")
print(f"文件大小: {size} bytes")

# 获取文件 URL
url = await storage.get_file_url("avatars/user_123.png")
print(f"文件 URL: {url}")

# 获取文件元数据
metadata = await storage.get_metadata("avatars/user_123.png")
print(f"最后修改: {metadata.last_modified}")
```

### 列出文件

```python
# 列出目录下的文件
files = await storage.list_files("avatars/")
for file in files:
    print(f"文件: {file.name}, 大小: {file.size}")

# 递归列出
files = await storage.list_files("avatars/", recursive=True)
```

## API 集成

### 头像上传

```python
from fastapi import File, UploadFile
from aurimyth.foundation_kit.application.interfaces.egress import BaseResponse

@router.post("/users/{user_id}/avatar")
async def upload_avatar(
    user_id: str,
    file: UploadFile = File(...)
):
    """用户上传头像"""
    
    # 验证文件类型
    if file.content_type not in ["image/jpeg", "image/png"]:
        raise ValueError("只支持 JPG 和 PNG 格式")
    
    # 验证文件大小（最大 5MB）
    content = await file.read()
    if len(content) > 5 * 1024 * 1024:
        raise ValueError("文件过大")
    
    # 上传到存储
    object_name = f"avatars/{user_id}.{file.filename.split('.')[-1]}"
    from io import BytesIO
    url = await storage.upload_file(
        StorageFile(
            data=BytesIO(content),
            object_name=object_name
        )
    )
    
    # 更新用户头像 URL
    await db.update_user(user_id, {"avatar_url": url})
    
    return BaseResponse(code=200, message="头像上传成功", data={"url": url})
```

### 批量上传

```python
@router.post("/projects/{project_id}/bulk-upload")
async def bulk_upload(
    project_id: str,
    files: list[UploadFile] = File(...)
):
    """批量上传文件"""
    
    results = []
    
    for file in files:
        try:
            content = await file.read()
            
            object_name = f"projects/{project_id}/{file.filename}"
            url = await storage.upload_file(
                StorageFile(
                    data=BytesIO(content),
                    object_name=object_name
                )
            )
            
            results.append({
                "filename": file.filename,
                "url": url,
                "status": "success"
            })
        
        except Exception as e:
            results.append({
                "filename": file.filename,
                "error": str(e),
                "status": "failed"
            })
    
    return BaseResponse(code=200, message="上传完成", data=results)
```

### 文件下载

```python
from fastapi.responses import StreamingResponse
import io

@router.get("/files/{file_id}/download")
async def download_file(file_id: str):
    """下载文件"""
    
    # 获取文件元数据
    file_info = await db.get_file(file_id)
    if not file_info:
        raise NotFoundError("文件不存在")
    
    # 从存储下载
    content = await storage.download_file(file_info.object_name)
    
    # 返回流
    return StreamingResponse(
        iter([content]),
        media_type="application/octet-stream",
        headers={"Content-Disposition": f"attachment; filename={file_info.filename}"}
    )
```

## 高级用法

### 生成签名 URL

```python
# 生成临时访问链接（有效期 1 小时）
signed_url = await storage.generate_presigned_url(
    "avatars/user_123.png",
    expires_in=3600
)
print(f"临时链接: {signed_url}")
```

### 文件版本管理

```python
# 保存多个版本
async def upload_document_version(doc_id: str, version: int, content: bytes):
    """上传文档版本"""
    
    object_name = f"documents/{doc_id}/v{version}.pdf"
    
    url = await storage.upload_file(
        StorageFile(
            data=BytesIO(content),
            object_name=object_name
        )
    )
    
    # 记录版本
    await db.save_document_version(doc_id, version, url)
    
    return url
```

### 缩略图生成

```python
from PIL import Image
import io

async def upload_image_with_thumbnail(user_id: str, image_data: bytes):
    """上传图片并生成缩略图"""
    
    # 上传原图
    original_url = await storage.upload_file(
        StorageFile(
            data=BytesIO(image_data),
            object_name=f"images/{user_id}/original.jpg"
        )
    )
    
    # 生成缩略图（200x200）
    image = Image.open(BytesIO(image_data))
    image.thumbnail((200, 200))
    
    thumbnail_buffer = io.BytesIO()
    image.save(thumbnail_buffer, format="JPEG")
    thumbnail_buffer.seek(0)
    
    # 上传缩略图
    thumbnail_url = await storage.upload_file(
        StorageFile(
            data=thumbnail_buffer,
            object_name=f"images/{user_id}/thumbnail.jpg"
        )
    )
    
    return {
        "original": original_url,
        "thumbnail": thumbnail_url
    }
```

## 环境配置

### S3 配置

```bash
# .env
STORAGE_TYPE=s3
STORAGE_ACCESS_KEY_ID=your_access_key
STORAGE_ACCESS_KEY_SECRET=your_secret_key
STORAGE_BUCKET_NAME=my-bucket
STORAGE_ENDPOINT_URL=https://s3.amazonaws.com
STORAGE_REGION=us-east-1
```

### 本地存储配置

```bash
# .env
STORAGE_TYPE=local
STORAGE_BUCKET_NAME=./uploads
```

## 常见场景

### 用户头像管理

```python
class AvatarService:
    async def upload_avatar(self, user_id: str, file: UploadFile):
        # 删除旧头像
        user = await db.get_user(user_id)
        if user.avatar_url:
            try:
                await storage.delete_file(user.avatar_url)
            except Exception:
                pass
        
        # 上传新头像
        content = await file.read()
        url = await storage.upload_file(
            StorageFile(
                data=BytesIO(content),
                object_name=f"avatars/{user_id}.jpg"
            )
        )
        
        # 更新用户
        await db.update_user(user_id, {"avatar_url": url})
        
        return url
```

### 文档管理

```python
class DocumentService:
    async def upload_document(self, project_id: str, file: UploadFile):
        """上传项目文档"""
        
        content = await file.read()
        
        # 上传到存储
        object_name = f"projects/{project_id}/docs/{file.filename}"
        url = await storage.upload_file(
            StorageFile(
                data=BytesIO(content),
                object_name=object_name
            )
        )
        
        # 记录文档
        document = Document(
            project_id=project_id,
            filename=file.filename,
            url=url,
            size=len(content),
            content_type=file.content_type
        )
        await db.save_document(document)
        
        return document
```

---

**总结**：对象存储适合处理大文件（图片、文档、视频等）。使用 S3 兼容的服务可以实现云存储，使用本地存储便于开发测试。
