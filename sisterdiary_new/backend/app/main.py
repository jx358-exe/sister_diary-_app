from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage
from pathlib import Path
import asyncio
import base64
import hashlib
import json
import re
import secrets
import smtplib
from typing import Literal
from urllib.parse import urlencode
from urllib.request import Request as UrlRequest, urlopen

from bson import ObjectId
from fastapi import Depends, FastAPI, File, Header, HTTPException, Query, Request, Response, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
import httpx
from pydantic import BaseModel, ConfigDict, Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from pymongo import ASCENDING, AsyncMongoClient


class Settings(BaseSettings):
    # Support both the backend root and this app directory regardless of the
    # process working directory. Values in backend/app/.env take precedence.
    model_config = SettingsConfigDict(
        env_file=(Path(__file__).resolve().parents[1] / ".env",
                  Path(__file__).resolve().parent / ".env"),
        extra="ignore",
    )

    mongodb_uri: str = "mongodb://127.0.0.1:27017"
    mongodb_database: str = "sister_diary"
    cors_origins: str = "http://127.0.0.1:8766,http://localhost:8766"
    auth_secret: str = "replace-this-before-deployment"
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = ""
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_from_number: str = ""
    deepseek_api_key: str = ""
    deepseek_base_url: str = "https://api.deepseek.com"
    deepseek_model: str = "deepseek-flash"

    @property
    def allowed_origins(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


settings = Settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.mongo_client = AsyncMongoClient(
        settings.mongodb_uri,
        serverSelectionTimeoutMS=5000,
    )
    app.state.database = app.state.mongo_client[settings.mongodb_database]
    await app.state.database.users.create_index("email", unique=True, sparse=True)
    await app.state.database.users.create_index("phone", unique=True, sparse=True)
    await app.state.database.users.create_index("userId", unique=True)
    await app.state.database.friendRequests.create_index(
        [("fromUserId", ASCENDING), ("toUserId", ASCENDING), ("status", ASCENDING)],
        unique=True,
        partialFilterExpression={"status": "pending"},
    )
    await app.state.database.friendships.create_index(
        [("userId", ASCENDING), ("friendId", ASCENDING)], unique=True
    )
    await app.state.database.dailyRecords.create_index(
        [("userId", ASCENDING), ("dateKey", ASCENDING)], unique=True
    )
    await app.state.database.dailyRecords.create_index("expiresAt", expireAfterSeconds=0)
    await app.state.database.sharingMoments.create_index("expiresAt", expireAfterSeconds=0)
    await app.state.database.gardenStates.create_index("expiresAt", expireAfterSeconds=0)
    await app.state.database.gardenStates.create_index("userId", unique=True)
    await app.state.database.schedules.create_index("expiresAt", expireAfterSeconds=0)
    await app.state.database.plans.create_index("expiresAt", expireAfterSeconds=0)
    await app.state.database.sessions.create_index("expiresAt", expireAfterSeconds=0)
    await app.state.database.verificationCodes.create_index("expiresAt", expireAfterSeconds=0)
    for collection_name in ("schedules", "plans", "dailyRecords"):
        collection = app.state.database[collection_name]
        async for document in collection.find({"expiresAt": {"$exists": False}}):
            created = document.get("createdAt") or document.get("date")
            if created is None:
                created = datetime.now(timezone.utc)
            if created.tzinfo is None:
                created = created.replace(tzinfo=timezone.utc)
            await collection.update_one(
                {"_id": document["_id"]},
                {"$set": {"expiresAt": created + timedelta(days=60)}},
            )
    async for share in app.state.database.sharingMoments.find(
        {"expiresAt": {"$exists": False}}
    ):
        created = share.get("createdAt") or datetime.now(timezone.utc)
        await app.state.database.sharingMoments.update_one(
            {"_id": share["_id"]},
            {"$set": {"expiresAt": created + timedelta(days=5)}},
        )
    async for garden in app.state.database.gardenStates.find(
        {"expiresAt": {"$exists": False}}
    ):
        updated = garden.get("updatedAt") or garden.get("createdAt") or datetime.now(timezone.utc)
        await app.state.database.gardenStates.update_one(
            {"_id": garden["_id"]},
            {"$set": {"expiresAt": updated + timedelta(days=30)}},
        )
    yield
    await app.state.mongo_client.close()


app = FastAPI(title="Sister Diary API", version="0.1.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
)


class ScheduleInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str = Field(min_length=1, max_length=200)
    time: str = Field(default="", max_length=80)
    note: str = Field(default="", max_length=5000)
    isDone: bool = False
    date: datetime

    @field_validator("title")
    @classmethod
    def title_must_not_be_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("title must not be blank")
        return value


class SchedulePatch(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str | None = Field(default=None, min_length=1, max_length=200)
    time: str | None = Field(default=None, max_length=80)
    note: str | None = Field(default=None, max_length=5000)
    isDone: bool | None = None
    date: datetime | None = None


class VerificationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    identity: str = Field(min_length=5, max_length=254)


class VerificationConfirm(BaseModel):
    model_config = ConfigDict(extra="forbid")
    identity: str = Field(min_length=5, max_length=254)
    code: str = Field(pattern=r"^\d{6}$")
    username: str = Field(min_length=1, max_length=50)
    password: str = Field(min_length=10, max_length=128)

    @field_validator("username")
    @classmethod
    def username_not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("username must not be blank")
        return value


class LoginInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    identity: str = Field(min_length=5, max_length=254)
    password: str = Field(min_length=1, max_length=128)


class ChangePasswordInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    currentPassword: str = Field(min_length=1, max_length=128)
    newPassword: str = Field(min_length=10, max_length=128)


class DailyRecordInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    diaryText: str = Field(default="", max_length=20000)
    chatText: str = Field(default="", max_length=20000)
    healthAnalysis: str = Field(default="", max_length=20000)
    healthAdvice: str = Field(default="", max_length=20000)


class GardenStateInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    seedName: str = Field(min_length=1, max_length=40)
    growthDay: int = Field(ge=0, le=3)
    hasPlanted: bool
    lastGrowthDate: datetime | None = None


class SharingMomentInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    text: str = Field(min_length=1, max_length=5000)

    @field_validator("text")
    @classmethod
    def share_text_not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("share text must not be blank")
        return value


class AIChatTurn(BaseModel):
    model_config = ConfigDict(extra="forbid")
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=4000)


class AIChatInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    message: str = Field(min_length=1, max_length=4000)
    history: list[AIChatTurn] = Field(default_factory=list, max_length=20)
    languageCode: Literal["zh", "en"] = "zh"

    @field_validator("message")
    @classmethod
    def chat_message_not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("message must not be blank")
        return value


class AIHealthInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    dateKey: str = Field(pattern=r"^\d{4}-\d{2}-\d{2}$")
    languageCode: Literal["zh", "en"] = "zh"


class AvatarInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    avatarId: str = Field(min_length=1, max_length=80)


class FriendRequestInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    friendUserId: str = Field(min_length=5, max_length=100)


def _collection(request: Request, kind: Literal["schedule", "plan"]):
    name = "schedules" if kind == "schedule" else "plans"
    return request.app.state.database[name]


def _serialize(document: dict) -> dict:
    return {
        "id": str(document["_id"]),
        "title": document["title"],
        "time": document.get("time", ""),
        "note": document.get("note", ""),
        "isDone": document.get("isDone", False),
        "date": document["date"].replace(tzinfo=timezone.utc).isoformat(),
    }


def _normalize_identity(raw: str) -> tuple[str, str]:
    value = raw.strip()
    if "@" in value:
        value = value.lower()
        if not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", value):
            raise HTTPException(status_code=422, detail="Enter a valid email address")
        return "email", value
    phone = re.sub(r"[\s()-]", "", value)
    if not re.fullmatch(r"\+[1-9]\d{7,14}", phone):
        raise HTTPException(
            status_code=422,
            detail="Enter a phone number with country code, such as +447700900123",
        )
    return "phone", phone


def _hash_code(identity: str, code: str) -> str:
    payload = f"{settings.auth_secret}:{identity}:{code}".encode()
    return hashlib.sha256(payload).hexdigest()


def _hash_password(password: str, salt: str | None = None) -> tuple[str, str]:
    salt = salt or secrets.token_hex(16)
    derived = hashlib.pbkdf2_hmac(
        "sha256", password.encode(), bytes.fromhex(salt), 310_000
    ).hex()
    return salt, derived


def _password_matches(password: str, salt: str, expected_hash: str) -> bool:
    _, actual = _hash_password(password, salt)
    return secrets.compare_digest(actual, expected_hash)


def _send_email_code(email: str, code: str) -> None:
    if not (settings.smtp_host and settings.smtp_from):
        raise HTTPException(status_code=503, detail="Email verification is not configured")
    message = EmailMessage()
    message["Subject"] = "Your Sister Diary verification code"
    message["From"] = settings.smtp_from
    message["To"] = email
    message.set_content(f"Your verification code is {code}. It expires in 10 minutes.")
    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as server:
        server.starttls()
        if settings.smtp_user:
            server.login(settings.smtp_user, settings.smtp_password)
        server.send_message(message)


def _send_sms_code(phone: str, code: str) -> None:
    if not all(
        [settings.twilio_account_sid, settings.twilio_auth_token, settings.twilio_from_number]
    ):
        raise HTTPException(status_code=503, detail="SMS verification is not configured")
    url = (
        "https://api.twilio.com/2010-04-01/Accounts/"
        f"{settings.twilio_account_sid}/Messages.json"
    )
    body = urlencode({"To": phone, "From": settings.twilio_from_number,
                      "Body": f"Your Sister Diary verification code is {code}."}).encode()
    credentials = base64.b64encode(
        f"{settings.twilio_account_sid}:{settings.twilio_auth_token}".encode()
    ).decode()
    request = UrlRequest(url, data=body, headers={"Authorization": f"Basic {credentials}"})
    with urlopen(request, timeout=15) as response:
        if response.status >= 300:
            raise RuntimeError("SMS provider rejected the request")


async def _deepseek_completion(messages: list[dict[str, str]]) -> str:
    if not settings.deepseek_api_key:
        raise HTTPException(status_code=503, detail="DeepSeek API is not configured")
    base_url = settings.deepseek_base_url.rstrip("/")
    url = base_url if base_url.endswith("/chat/completions") else f"{base_url}/chat/completions"
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(45.0, connect=10.0)) as client:
            response = await client.post(
                url,
                headers={
                    "Authorization": f"Bearer {settings.deepseek_api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": settings.deepseek_model,
                    "messages": messages,
                    "stream": False,
                },
            )
    except httpx.TimeoutException as exc:
        raise HTTPException(status_code=504, detail="AI response timed out") from exc
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail="Could not reach DeepSeek") from exc
    if response.is_error:
        if response.status_code == 401:
            raise HTTPException(status_code=502, detail="AI provider rejected its API key")
        if response.status_code == 402:
            raise HTTPException(status_code=402, detail="AI provider has insufficient credits")
        if response.status_code == 404:
            raise HTTPException(status_code=502, detail="Configured AI model is unavailable")
        if response.status_code == 429:
            raise HTTPException(status_code=429, detail="AI provider rate limit reached")
        raise HTTPException(status_code=502, detail="AI provider request failed")
    try:
        payload = response.json()
        content = payload["choices"][0]["message"]["content"]
    except (ValueError, KeyError, IndexError, TypeError) as exc:
        raise HTTPException(status_code=502, detail="DeepSeek returned an invalid response") from exc
    if not isinstance(content, str) or not content.strip():
        raise HTTPException(status_code=502, detail="DeepSeek returned an empty response")
    return content.strip()


def _parse_health_analysis(content: str) -> tuple[str, str]:
    decoder = json.JSONDecoder()
    candidates = [content.strip()]
    start = content.find("{")
    if start > 0:
        candidates.append(content[start:])
    for candidate in candidates:
        cleaned = candidate.removeprefix("```json").removeprefix("```").strip()
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3].strip()
        try:
            result, _ = decoder.raw_decode(cleaned)
        except json.JSONDecodeError:
            continue
        if not isinstance(result, dict):
            continue
        analysis = result.get("analysis")
        advice = result.get("advice")
        if isinstance(analysis, str) and analysis.strip() and isinstance(advice, str) and advice.strip():
            return analysis.strip(), advice.strip()
    raise HTTPException(status_code=502, detail="AI returned an invalid health analysis")


async def require_user(
    request: Request,
    authorization: str | None = Header(default=None),
) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Sign in required")
    token = authorization.removeprefix("Bearer ").strip()
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    session = await request.app.state.database.sessions.find_one(
        {"tokenHash": token_hash, "expiresAt": {"$gt": datetime.now(timezone.utc)}}
    )
    if session is None:
        raise HTTPException(status_code=401, detail="Session expired")
    user = await request.app.state.database.users.find_one(
        {"userId": session["userId"]}, {"_id": 0, "avatarData": 0}
    )
    if user is None:
        raise HTTPException(status_code=401, detail="Account not found")
    return user


def _check_user_scope(user: dict, requested_user_id: str | None) -> str:
    user_id = user["userId"]
    if requested_user_id and requested_user_id != user_id:
        raise HTTPException(status_code=403, detail="Account scope mismatch")
    return user_id


def _user_response(user: dict, token: str) -> dict:
    return {
        "token": token,
        "user": {
            "userId": user["userId"],
            "username": user.get("username", "Sister"),
            "email": user.get("email"),
            "phone": user.get("phone"),
            "avatarId": user.get("avatarId", "flower_rose"),
            "friendLimit": user.get("friendLimit", 20),
            "planTier": user.get("planTier", "free"),
        },
        "expiresInDays": 30,
    }


@app.post("/api/auth/request-code")
async def request_verification_code(body: VerificationRequest, request: Request):
    kind, identity = _normalize_identity(body.identity)
    codes = request.app.state.database.verificationCodes
    now = datetime.now(timezone.utc)
    previous = await codes.find_one({"identity": identity}, sort=[("createdAt", -1)])
    if previous and (now - previous["createdAt"].replace(tzinfo=timezone.utc)).total_seconds() < 60:
        raise HTTPException(status_code=429, detail="Wait before requesting another code")
    code = f"{secrets.randbelow(1_000_000):06d}"
    if kind == "email":
        try:
            await asyncio.to_thread(_send_email_code, identity, code)
        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(status_code=502, detail="Could not send email code") from exc
    else:
        try:
            await asyncio.to_thread(_send_sms_code, identity, code)
        except HTTPException:
            raise
        except Exception as exc:
            raise HTTPException(status_code=502, detail="Could not send SMS code") from exc
    await codes.insert_one({
        "identity": identity,
        "codeHash": _hash_code(identity, code),
        "attempts": 0,
        "createdAt": now,
        "expiresAt": now + timedelta(minutes=10),
    })
    return {"detail": "Verification code sent", "expiresInSeconds": 600}


@app.post("/api/auth/verify-code")
async def verify_code(body: VerificationConfirm, request: Request):
    _, identity = _normalize_identity(body.identity)
    codes = request.app.state.database.verificationCodes
    now = datetime.now(timezone.utc)
    challenge = await codes.find_one_and_update(
        {"identity": identity, "expiresAt": {"$gt": now}, "consumedAt": {"$exists": False},
         "attempts": {"$lt": 5}},
        {"$inc": {"attempts": 1}},
        sort=[("createdAt", -1)],
    )
    if challenge is None or not secrets.compare_digest(
        challenge["codeHash"], _hash_code(identity, body.code)
    ):
        raise HTTPException(status_code=400, detail="Invalid or expired verification code")
    await codes.update_one({"_id": challenge["_id"]}, {"$set": {"consumedAt": now}})
    kind, _ = _normalize_identity(identity)
    field = "email" if kind == "email" else "phone"
    users = request.app.state.database.users
    user = await users.find_one({field: identity})
    if user is None:
        user_id = f"USER{secrets.token_hex(6).upper()}"
        user = {
            "userId": user_id,
            field: identity,
            "avatarId": "flower_rose",
            "avatarChanges": [],
            "planTier": "free",
            "friendLimit": 20,
            "createdAt": now,
        }
        try:
            await users.insert_one(user)
        except Exception as exc:
            user = await users.find_one({field: identity})
            if user is None:
                raise HTTPException(status_code=409, detail="Could not create account") from exc
    if user.get("passwordHash"):
        raise HTTPException(status_code=409, detail="Account already exists. Sign in with your password.")
    salt, password_hash = _hash_password(body.password)
    user.update({"username": body.username, "passwordSalt": salt,
                 "passwordHash": password_hash})
    await users.update_one({"_id": user["_id"]}, {"$set": {
        "username": body.username, "passwordSalt": salt,
        "passwordHash": password_hash,
    }})
    token = secrets.token_urlsafe(32)
    expires = now + timedelta(days=30)
    await request.app.state.database.sessions.insert_one({
        "tokenHash": hashlib.sha256(token.encode()).hexdigest(),
        "userId": user["userId"],
        "createdAt": now,
        "expiresAt": expires,
    })
    return _user_response(user, token)


@app.post("/api/auth/login")
async def login(body: LoginInput, request: Request):
    kind, identity = _normalize_identity(body.identity)
    field = "email" if kind == "email" else "phone"
    user = await request.app.state.database.users.find_one({field: identity})
    if user is None or not user.get("passwordHash") or not _password_matches(
        body.password, user.get("passwordSalt", ""), user.get("passwordHash", "")
    ):
        raise HTTPException(status_code=401, detail="Email/phone or password is incorrect")
    now = datetime.now(timezone.utc)
    token = secrets.token_urlsafe(32)
    await request.app.state.database.sessions.insert_one({
        "tokenHash": hashlib.sha256(token.encode()).hexdigest(),
        "userId": user["userId"], "createdAt": now,
        "expiresAt": now + timedelta(days=30),
    })
    return _user_response(user, token)


@app.post("/api/auth/change-password")
async def change_password(
    body: ChangePasswordInput,
    request: Request,
    user: dict = Depends(require_user),
):
    if not _password_matches(body.currentPassword, user.get("passwordSalt", ""),
                             user.get("passwordHash", "")):
        raise HTTPException(status_code=400, detail="Current password is incorrect")
    salt, password_hash = _hash_password(body.newPassword)
    await request.app.state.database.users.update_one(
        {"userId": user["userId"]},
        {"$set": {"passwordSalt": salt, "passwordHash": password_hash}},
    )
    return {"detail": "Password updated"}


@app.post("/api/auth/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    request: Request,
    authorization: str | None = Header(default=None),
    user: dict = Depends(require_user),
):
    del user
    token = authorization.removeprefix("Bearer ").strip() if authorization else ""
    await request.app.state.database.sessions.delete_one(
        {"tokenHash": hashlib.sha256(token.encode()).hexdigest()}
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@app.get("/api/auth/me")
async def get_me(user: dict = Depends(require_user)):
    return _user_response(user, "")


@app.get("/health")
async def health(request: Request):
    try:
        await request.app.state.database.command("ping")
    except Exception as exc:
        raise HTTPException(status_code=503, detail="MongoDB is unavailable") from exc
    return {"status": "ok", "database": settings.mongodb_database}


@app.post("/api/ai/chat")
async def ai_chat(
    body: AIChatInput,
    user: dict = Depends(require_user),
):
    if body.languageCode == "zh":
        system_prompt = (
            "你是 Sister Diary 里的 AI 闺蜜/兄弟，温暖、自然、平等地倾听并交流，"
            "回复简洁，先回应用户的感受，再给实际建议；不评判、不冒充真人，"
            "不制造情感依赖。涉及诊断、用药或紧急健康问题时，建议联系专业人员。"
        )
    else:
        system_prompt = (
            "You are the warm, supportive AI best friend in Sister Diary. Be natural, "
            "concise, non-judgmental, and practical. Acknowledge feelings before offering "
            "ideas. Never pretend to be human or encourage emotional dependency. For "
            "diagnosis, medication, or urgent health concerns, direct the user to a professional."
        )
    messages = [{"role": "system", "content": system_prompt}]
    messages.extend(turn.model_dump() for turn in body.history)
    messages.append({"role": "user", "content": body.message})
    answer = await _deepseek_completion(messages)
    return {"answer": answer, "model": settings.deepseek_model}


@app.post("/api/ai/health-analysis")
async def ai_health_analysis(
    body: AIHealthInput,
    request: Request,
    user: dict = Depends(require_user),
):
    try:
        selected = datetime.strptime(body.dateKey, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail="Invalid date") from exc
    next_day = selected + timedelta(days=1)
    daily = await request.app.state.database.dailyRecords.find_one(
        {"userId": user["userId"], "dateKey": body.dateKey}, {"_id": 0}
    ) or {}
    schedules = [
        {"time": item.get("time", ""), "title": item.get("title", ""),
         "done": item.get("isDone", False)}
        async for item in request.app.state.database.schedules.find(
            {"userId": user["userId"], "date": {"$gte": selected, "$lt": next_day}},
            {"_id": 0, "time": 1, "title": 1, "isDone": 1},
        ).sort("date", ASCENDING).limit(100)
    ]
    context_data = {
        "date": body.dateKey,
        "schedules": schedules,
        "diary": str(daily.get("diaryText", ""))[:12000],
        "chat": str(daily.get("chatText", ""))[:12000],
    }
    if not schedules and not context_data["diary"] and not context_data["chat"]:
        raise HTTPException(status_code=400, detail="Add a schedule, diary, or chat before analysis")
    if body.languageCode == "zh":
        system_prompt = (
            "你是日常健康习惯整理助手。根据用户提供的当天日程、日记和聊天内容，"
            "总结可观察到的作息、活动和压力习惯，并给出温和、可执行的建议。"
            "不要推断或诊断疾病，不要给药物剂量或替代医生意见；区分事实与推测。"
            "只返回严格 JSON，不要代码围栏，格式为："
            "{\"analysis\":\"简短总结\",\"advice\":\"具体建议\"}。"
        )
    else:
        system_prompt = (
            "You review daily habits using the provided schedule, diary, and chat. "
            "Summarize observable routines, activity and stress patterns, then offer "
            "gentle, actionable suggestions. Do not infer or diagnose disease, prescribe "
            "medication, or replace a clinician; distinguish observations from guesses. "
            "Return only strict JSON, no code fence, in this format: "
            "{\"analysis\":\"brief summary\",\"advice\":\"practical suggestions\"}."
        )
    content = await _deepseek_completion([
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": json.dumps(context_data, ensure_ascii=False)},
    ])
    analysis, advice = _parse_health_analysis(content)
    now = datetime.now(timezone.utc)
    await request.app.state.database.dailyRecords.update_one(
        {"userId": user["userId"], "dateKey": body.dateKey},
        {"$set": {
            "date": body.dateKey,
            "healthAnalysis": analysis,
            "healthAdvice": advice,
            "updatedAt": now,
            "expiresAt": now + timedelta(days=60),
        }, "$setOnInsert": {"createdAt": now, "dateKey": body.dateKey}},
        upsert=True,
    )
    return {"analysis": analysis, "advice": advice, "model": settings.deepseek_model}


@app.get("/api/schedules")
async def list_schedules(
    request: Request,
    user_id: str | None = Query(default=None, max_length=100),
    kind: Literal["schedule", "plan"] = "schedule",
    user: dict = Depends(require_user),
):
    user_id = _check_user_scope(user, user_id)
    collection = _collection(request, kind)
    cursor = collection.find({"userId": user_id}).sort("date", ASCENDING).limit(500)
    return [_serialize(doc) async for doc in cursor]


@app.post("/api/schedules", status_code=status.HTTP_201_CREATED)
async def create_schedule(
    item: ScheduleInput,
    request: Request,
    user_id: str | None = Query(default=None, max_length=100),
    kind: Literal["schedule", "plan"] = "schedule",
    user: dict = Depends(require_user),
):
    user_id = _check_user_scope(user, user_id)
    document = item.model_dump()
    now = datetime.now(timezone.utc)
    document.update({"userId": user_id, "createdAt": now,
                     "expiresAt": now + timedelta(days=60)})
    result = await _collection(request, kind).insert_one(document)
    document["_id"] = result.inserted_id
    return _serialize(document)


@app.put("/api/schedules/{item_id}")
async def update_schedule(
    item_id: str,
    patch: SchedulePatch,
    request: Request,
    user_id: str | None = Query(default=None, max_length=100),
    kind: Literal["schedule", "plan"] = "schedule",
    user: dict = Depends(require_user),
):
    user_id = _check_user_scope(user, user_id)
    if not ObjectId.is_valid(item_id):
        raise HTTPException(status_code=400, detail="Invalid item id")
    updates = patch.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")
    collection = _collection(request, kind)
    result = await collection.find_one_and_update(
        {"_id": ObjectId(item_id), "userId": user_id},
        {"$set": {**updates, "expiresAt": datetime.now(timezone.utc) + timedelta(days=60)}},
        return_document=True,
    )
    if result is None:
        raise HTTPException(status_code=404, detail="Schedule item not found")
    return _serialize(result)


@app.delete("/api/schedules/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_schedule(
    item_id: str,
    request: Request,
    user_id: str | None = Query(default=None, max_length=100),
    kind: Literal["schedule", "plan"] = "schedule",
    user: dict = Depends(require_user),
):
    user_id = _check_user_scope(user, user_id)
    if not ObjectId.is_valid(item_id):
        raise HTTPException(status_code=400, detail="Invalid item id")
    result = await _collection(request, kind).delete_one(
        {"_id": ObjectId(item_id), "userId": user_id}
    )
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Schedule item not found")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@app.get("/api/daily-records/{date_key}")
async def get_daily_record(
    date_key: str,
    request: Request,
    user: dict = Depends(require_user),
):
    try:
        datetime.strptime(date_key, "%Y-%m-%d")
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Date must use YYYY-MM-DD") from exc
    record = await request.app.state.database.dailyRecords.find_one(
        {"userId": user["userId"], "dateKey": date_key}, {"_id": 0}
    )
    if record is None:
        return {"date": date_key, "diaryText": "", "chatText": "",
                "healthAnalysis": "", "healthAdvice": ""}
    return {key: record.get(key, "") for key in
            ("date", "diaryText", "chatText", "healthAnalysis", "healthAdvice")}


@app.put("/api/daily-records/{date_key}")
async def put_daily_record(
    date_key: str,
    body: DailyRecordInput,
    request: Request,
    user: dict = Depends(require_user),
):
    try:
        datetime.strptime(date_key, "%Y-%m-%d")
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Date must use YYYY-MM-DD") from exc
    now = datetime.now(timezone.utc)
    document = {
        **body.model_dump(), "date": date_key, "dateKey": date_key,
        "updatedAt": now, "expiresAt": now + timedelta(days=60),
    }
    await request.app.state.database.dailyRecords.update_one(
        {"userId": user["userId"], "dateKey": date_key},
        {"$set": document, "$setOnInsert": {"createdAt": now}}, upsert=True,
    )
    return {key: document[key] for key in
            ("date", "diaryText", "chatText", "healthAnalysis", "healthAdvice")}


@app.delete("/api/daily-records/{date_key}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_daily_record(
    date_key: str,
    request: Request,
    user: dict = Depends(require_user),
):
    try:
        selected = datetime.strptime(date_key, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Date must use YYYY-MM-DD") from exc
    next_day = selected + timedelta(days=1)
    await request.app.state.database.dailyRecords.delete_one(
        {"userId": user["userId"], "dateKey": date_key}
    )
    await request.app.state.database.schedules.delete_many(
        {"userId": user["userId"], "date": {"$gte": selected, "$lt": next_day}}
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@app.delete("/api/records/old", status_code=status.HTTP_200_OK)
async def delete_old_records(
    request: Request,
    category: Literal["schedule", "plan"] = Query(),
    older_than_days: int = Query(ge=1, le=60),
    user: dict = Depends(require_user),
):
    cutoff = datetime.now(timezone.utc) - timedelta(days=older_than_days)
    date_cutoff = cutoff.strftime("%Y-%m-%d")
    if category == "schedule":
        daily_result = await request.app.state.database.dailyRecords.delete_many({
            "userId": user["userId"], "dateKey": {"$lt": date_cutoff},
        })
        item_result = await request.app.state.database.schedules.delete_many({
            "userId": user["userId"], "date": {"$lt": cutoff},
        })
        deleted = daily_result.deleted_count + item_result.deleted_count
    else:
        item_result = await request.app.state.database.plans.delete_many({
            "userId": user["userId"], "date": {"$lt": cutoff},
        })
        deleted = item_result.deleted_count
    return {"category": category, "deletedRecords": deleted, "cutoff": date_cutoff}


@app.get("/api/garden")
async def get_garden(request: Request, user: dict = Depends(require_user)):
    garden = await request.app.state.database.gardenStates.find_one(
        {"userId": user["userId"]}, {"_id": 0, "userId": 0, "expiresAt": 0}
    )
    return garden or {"seedName": "向日葵", "growthDay": 0,
                      "hasPlanted": False, "lastGrowthDate": None}


@app.put("/api/garden")
async def save_garden(
    body: GardenStateInput,
    request: Request,
    user: dict = Depends(require_user),
):
    if body.seedName not in {"向日葵", "玫瑰", "风信子", "牡丹花", "紫罗兰"}:
        raise HTTPException(status_code=422, detail="Choose a supported flower seed")
    now = datetime.now(timezone.utc)
    values = {**body.model_dump(), "updatedAt": now,
              "expiresAt": now + timedelta(days=30)}
    await request.app.state.database.gardenStates.update_one(
        {"userId": user["userId"]},
        {"$set": values, "$setOnInsert": {"createdAt": now}}, upsert=True,
    )
    return body.model_dump()


@app.get("/api/sharing-moments")
async def list_sharing_moments(request: Request, user: dict = Depends(require_user)):
    db = request.app.state.database
    friends = [doc["friendId"] async for doc in db.friendships.find(
        {"userId": user["userId"]}, {"friendId": 1}
    )]
    visible_user_ids = [user["userId"], *friends]
    now = datetime.now(timezone.utc)
    cursor = db.sharingMoments.find(
        {"userId": {"$in": visible_user_ids}, "expiresAt": {"$gt": now}},
        {"_id": 0, "userId": 0, "expiresAt": 0},
    ).sort("createdAt", -1).limit(100)
    return [item async for item in cursor]


@app.post("/api/sharing-moments", status_code=status.HTTP_201_CREATED)
async def create_sharing_moment(
    body: SharingMomentInput,
    request: Request,
    user: dict = Depends(require_user),
):
    now = datetime.now(timezone.utc)
    item = {
        "userId": user["userId"], "username": user.get("username", "Sister"),
        "text": body.text, "createdAt": now,
        "expiresAt": now + timedelta(days=5),
    }
    await request.app.state.database.sharingMoments.insert_one(item)
    return {"username": item["username"], "text": item["text"],
            "createdAt": now.isoformat(), "expiresInDays": 5}


@app.post("/api/profile/avatar")
async def set_avatar(
    body: AvatarInput,
    request: Request,
    user: dict = Depends(require_user),
):
    allowed = {"flower_rose", "sunflower", "violet", "peony", "hyacinth", "custom"}
    if body.avatarId not in allowed:
        raise HTTPException(status_code=422, detail="Choose a supported avatar")
    now = datetime.now(timezone.utc)
    current_year = now.year
    changes = [item for item in user.get("avatarChanges", [])
               if item.get("year") == current_year]
    if len(changes) >= 3:
        raise HTTPException(status_code=409, detail="Avatar change limit reached for this year")
    changes.append({"year": current_year, "changedAt": now})
    await request.app.state.database.users.update_one(
        {"userId": user["userId"]},
        {"$set": {"avatarId": body.avatarId, "avatarChanges": changes}},
    )
    return {"avatarId": body.avatarId, "changesLeft": 3 - len(changes)}


@app.post("/api/profile/avatar/photo")
async def upload_avatar_photo(
    request: Request,
    photo: UploadFile = File(...),
    user: dict = Depends(require_user),
):
    if photo.content_type not in {"image/jpeg", "image/png", "image/webp"}:
        raise HTTPException(status_code=415, detail="Choose a JPEG, PNG, or WebP image")
    image = await photo.read(5 * 1024 * 1024 + 1)
    if not image or len(image) > 5 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Avatar image must be under 5 MB")
    digest = hashlib.sha256(image).hexdigest()
    if user.get("avatarHash") == digest:
        return {"avatarId": "custom", "changesLeft": 3}
    now = datetime.now(timezone.utc)
    current_year = now.year
    changes = [item for item in user.get("avatarChanges", [])
               if item.get("year") == current_year]
    if len(changes) >= 3:
        raise HTTPException(status_code=409, detail="Avatar change limit reached for this year")
    changes.append({"year": current_year, "changedAt": now})
    await request.app.state.database.users.update_one(
        {"userId": user["userId"]},
        {"$set": {
            "avatarId": "custom", "avatarChanges": changes,
            "avatarData": image, "avatarMime": photo.content_type,
            "avatarHash": digest,
        }},
    )
    return {"avatarId": "custom", "changesLeft": 3 - len(changes)}


@app.get("/api/profile/avatar/photo")
async def get_avatar_photo(
    request: Request,
    user: dict = Depends(require_user),
):
    image = await request.app.state.database.users.find_one(
        {"userId": user["userId"]}, {"avatarData": 1, "avatarMime": 1}
    )
    if not image or not image.get("avatarData"):
        raise HTTPException(status_code=404, detail="No custom avatar")
    return Response(content=bytes(image["avatarData"]),
                    media_type=image.get("avatarMime", "image/jpeg"),
                    headers={"Cache-Control": "private, max-age=3600"})


@app.get("/api/friends")
async def list_friends(
    request: Request,
    user: dict = Depends(require_user),
):
    db = request.app.state.database
    friendships = [doc async for doc in db.friendships.find({"userId": user["userId"]})]
    friends = []
    for relation in friendships:
        friend = await db.users.find_one({"userId": relation["friendId"]},
                                         {"_id": 0, "email": 0, "phone": 0, "avatarData": 0})
        if friend:
            friends.append(friend)
    incoming = [doc async for doc in db.friendRequests.find(
        {"toUserId": user["userId"], "status": "pending"}, {"_id": 0}
    )]
    return {"friends": friends, "incomingRequests": incoming,
            "friendCount": user.get("friendCount", 0),
            "friendLimit": user.get("friendLimit", 20)}


@app.post("/api/friend-requests", status_code=status.HTTP_201_CREATED)
async def create_friend_request(
    body: FriendRequestInput,
    request: Request,
    user: dict = Depends(require_user),
):
    if body.friendUserId == user["userId"]:
        raise HTTPException(status_code=400, detail="You cannot add yourself")
    db = request.app.state.database
    friend = await db.users.find_one({"userId": body.friendUserId})
    if friend is None:
        raise HTTPException(status_code=404, detail="Friend account not found")
    if await db.friendships.find_one({"userId": user["userId"], "friendId": body.friendUserId}):
        raise HTTPException(status_code=409, detail="Already friends")
    try:
        await db.friendRequests.insert_one({
            "fromUserId": user["userId"], "toUserId": body.friendUserId,
            "status": "pending", "createdAt": datetime.now(timezone.utc),
        })
    except Exception as exc:
        raise HTTPException(status_code=409, detail="Friend request already pending") from exc
    return {"status": "pending"}


@app.post("/api/friend-requests/{request_id}/accept")
async def accept_friend_request(
    request_id: str,
    request: Request,
    user: dict = Depends(require_user),
):
    if not ObjectId.is_valid(request_id):
        raise HTTPException(status_code=400, detail="Invalid request id")
    db = request.app.state.database
    friend_request = await db.friendRequests.find_one({
        "_id": ObjectId(request_id), "toUserId": user["userId"], "status": "pending"
    })
    if friend_request is None:
        raise HTTPException(status_code=404, detail="Friend request not found")
    sender = await db.users.find_one({"userId": friend_request["fromUserId"]})
    if sender is None:
        raise HTTPException(status_code=404, detail="Friend account not found")
    now = datetime.now(timezone.utc)
    first = await db.users.update_one(
        {"userId": user["userId"], "$expr": {"$lt": [
            {"$ifNull": ["$friendCount", 0]}, {"$ifNull": ["$friendLimit", 20]}
        ]}}, {"$inc": {"friendCount": 1}}
    )
    if first.modified_count != 1:
        raise HTTPException(status_code=409, detail="Your friend limit has been reached")
    second = await db.users.update_one(
        {"userId": sender["userId"], "$expr": {"$lt": [
            {"$ifNull": ["$friendCount", 0]}, {"$ifNull": ["$friendLimit", 20]}
        ]}}, {"$inc": {"friendCount": 1}}
    )
    if second.modified_count != 1:
        await db.users.update_one({"userId": user["userId"]}, {"$inc": {"friendCount": -1}})
        raise HTTPException(status_code=409, detail="The other account has reached its friend limit")
    changed = await db.friendRequests.update_one(
        {"_id": ObjectId(request_id), "status": "pending"},
        {"$set": {"status": "accepted", "acceptedAt": now}},
    )
    if changed.modified_count != 1:
        await db.users.update_one({"userId": user["userId"]}, {"$inc": {"friendCount": -1}})
        await db.users.update_one({"userId": sender["userId"]}, {"$inc": {"friendCount": -1}})
        raise HTTPException(status_code=409, detail="Friend request was already processed")
    await db.friendships.insert_many([
        {"userId": user["userId"], "friendId": sender["userId"], "createdAt": now},
        {"userId": sender["userId"], "friendId": user["userId"], "createdAt": now},
    ])
    return {"status": "accepted", "friendCount": user.get("friendCount", 0) + 1,
            "friendLimit": user.get("friendLimit", 20)}
