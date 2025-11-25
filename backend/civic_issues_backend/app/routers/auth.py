# in app/routers/auth.py
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from .. import database, schemas, models, utils

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/register", response_model=schemas.User, status_code=status.HTTP_201_CREATED)
async def register_client_user(user: schemas.UserCreate, db: AsyncSession = Depends(database.get_db)):
    """
    Register a new CLIENT. Public registration for workers or admins is disabled for security.
    """
    query = select(models.User).where(models.User.email == user.email)
    existing_user = (await db.execute(query)).scalar_one_or_none()
    
    if existing_user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email is already registered")

    hashed_password = utils.get_password_hash(user.password)
    
    # Create a new user with the hardcoded CLIENT role
    new_user = models.User(
        **user.model_dump(exclude={"password"}), 
        hashed_password=hashed_password, 
        role=models.RoleEnum.CLIENT
    )
    
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    return new_user

@router.post("/login", response_model=schemas.Token)
async def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(), 
    db: AsyncSession = Depends(database.get_db)
):
    """
    Login any type of user (client, worker, admin, super_admin) to get a JWT access token.
    """
    query = select(models.User).where(models.User.email == form_data.username)
    user = (await db.execute(query)).scalar_one_or_none()

    if not user or not user.is_active or not utils.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password, or user is inactive.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token = utils.create_access_token(data={"sub": user.email})
    return {"access_token": access_token, "token_type": "bearer"}


@router.post("/fcm-token", status_code=status.HTTP_200_OK)
async def update_fcm_token(
    fcm_token: str,
    current_user: models.User = Depends(utils.get_current_user),
    db: AsyncSession = Depends(database.get_db)
):
    """
    Update the user's FCM (Firebase Cloud Messaging) token for push notifications.
    This should be called after login when the app gets the FCM token from Firebase.
    """
    current_user.fcm_token = fcm_token
    await db.commit()
    return {"message": "FCM token updated successfully"}
