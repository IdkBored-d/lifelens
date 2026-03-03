"""
Configuration management for Lifelens backend
"""
from pydantic_settings import BaseSettings
from functools import lru_cache
import os


class Settings(BaseSettings):
    """Application settings"""
    
    # Gemini API
    gemini_api_key: str
    
    # Weaviate
    weaviate_url: str = "http://localhost:8080"
    weaviate_api_key: str = ""
    
    # Database
    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_db: str = "lifelens"
    postgres_user: str = "lifelens_user"
    postgres_password: str
    
    # Redis
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_password: str = ""
    
    # API
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    api_debug: bool = True
    api_reload: bool = True
    
    # Security
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    
    # ML Models
    embedding_model: str = "all-MiniLM-L6-v2"
    
    # Rate Limiting
    rate_limit_per_minute: int = 30
    
    # Logging
    log_level: str = "INFO"
    
    class Config:
        env_file = ".env"
        case_sensitive = False
    
    @property
    def database_url(self) -> str:
        """Construct PostgreSQL connection URL"""
        return (
            f"postgresql://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )
    
    @property
    def redis_url(self) -> str:
        """Construct Redis connection URL"""
        if self.redis_password:
            return f"redis://:{self.redis_password}@{self.redis_host}:{self.redis_port}"
        return f"redis://{self.redis_host}:{self.redis_port}"


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance"""
    return Settings()
