"""
Voice-to-Text Service
Converts audio recordings to text using Google Speech Recognition
"""

import speech_recognition as sr
from pydub import AudioSegment
import io
import os
import tempfile
from fastapi import HTTPException, status
import logging

logger = logging.getLogger(__name__)


async def convert_audio_to_text(audio_bytes: bytes, language: str = "en-IN") -> str:
    """
    Convert audio file to text using Google Speech Recognition.
    
    Supports:
    - English (en-IN for Indian English)
    - Hindi (hi-IN)
    - Multiple audio formats (webm, ogg, mp3, wav)
    
    Args:
        audio_bytes: Raw audio file bytes
        language: Language code (en-IN, hi-IN, etc.)
        
    Returns:
        str: Transcribed text
        
    Raises:
        HTTPException: If conversion fails
    """
    
    recognizer = sr.Recognizer()
    
    try:
        # Create temporary file for audio processing
        with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as temp_audio:
            temp_path = temp_audio.name
            
            try:
                # Try to load audio with pydub (handles multiple formats)
                audio = AudioSegment.from_file(io.BytesIO(audio_bytes))
                
                # Convert to WAV format (required by speech_recognition)
                # Set to mono, 16kHz sample rate for best recognition
                audio = audio.set_channels(1).set_frame_rate(16000)
                audio.export(temp_path, format="wav")
                
            except Exception as e:
                # If pydub fails, try direct WAV
                temp_audio.write(audio_bytes)
                temp_audio.flush()
            
            # Load audio file for recognition
            with sr.AudioFile(temp_path) as source:
                # Adjust for ambient noise
                recognizer.adjust_for_ambient_noise(source, duration=0.5)
                
                # Record audio
                audio_data = recognizer.record(source)
                
                # Recognize speech using Google Speech Recognition
                try:
                    # Try with specified language
                    text = recognizer.recognize_google(
                        audio_data,
                        language=language,
                        show_all=False
                    )
                    
                    if not text or len(text.strip()) == 0:
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail="No speech detected in audio. Please speak clearly and try again."
                        )
                    
                    logger.info(f"Speech recognized: {text[:50]}... (length: {len(text)})")
                    return text.strip()
                    
                except sr.UnknownValueError:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Could not understand audio. Please speak clearly and try again."
                    )
                    
                except sr.RequestError as e:
                    logger.error(f"Speech recognition service error: {str(e)}")
                    raise HTTPException(
                        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                        detail="Speech recognition service is temporarily unavailable. Please try again later."
                    )
    
    except HTTPException:
        raise
        
    except Exception as e:
        logger.error(f"Voice-to-text conversion error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to convert audio to text. Please ensure you uploaded a valid audio file."
        )
    
    finally:
        # Clean up temporary file
        try:
            if os.path.exists(temp_path):
                os.unlink(temp_path)
        except:
            pass


def get_supported_languages():
    """
    Get list of supported languages for voice recognition.
    
    Returns:
        dict: Language codes and names
    """
    return {
        "en-IN": "English (India)",
        "hi-IN": "Hindi (India)",
        "pa-IN": "Punjabi (India)",
        "en-US": "English (US)",
        "en-GB": "English (UK)"
    }

