from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Stream Chat
    stream_api_key: str = ""
    stream_api_secret: str = ""
    stream_api_base_url: str = "https://chat.stream-io-api.com/api/v1"

    # NVIDIA NIM (Claude-compatible API)
    nvidia_api_key: str = ""
    nvidia_base_url: str = "https://integrate.api.nvidia.com/v1"
    nvidia_model: str = "deepseek-ai/deepseek-v4-flash-0731"

    # Redis
    redis_url: str = "redis://localhost:6379/0"

    # External APIs
    google_places_api_key: str = ""
    tmdb_api_key: str = ""
    razorpay_key_id: str = ""
    razorpay_key_secret: str = ""

    # App
    app_host: str = "0.0.0.0"
    app_port: int = 8000
    webhook_secret: str = ""

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
