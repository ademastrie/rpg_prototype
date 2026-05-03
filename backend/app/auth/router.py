from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth.schemas import AuthRequest, TokenResponse, UserResponse
from app.auth.security import create_access_token, hash_password, verify_password
from app.db import get_db
from app.models.user import User


router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=UserResponse)
def register(payload: AuthRequest, db: Session = Depends(get_db)) -> User:
    email = payload.email.lower()
    existing_user = db.scalar(select(User).where(User.email == email))
    if existing_user is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email is already registered.",
        )

    user = User(email=email, hashed_password=hash_password(payload.password))
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/login", response_model=TokenResponse)
def login(payload: AuthRequest, db: Session = Depends(get_db)) -> TokenResponse:
    email = payload.email.lower()
    user = db.scalar(select(User).where(User.email == email))
    if user is None or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
        )

    return TokenResponse(access_token=create_access_token(str(user.id)))
