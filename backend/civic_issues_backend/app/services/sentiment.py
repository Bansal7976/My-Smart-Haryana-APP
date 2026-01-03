# Enhanced Sentiment Analysis Service using Transformers
# Upgraded from TextBlob to RoBERTa-based model for better accuracy

from textblob import TextBlob
import logging

logger = logging.getLogger(__name__)

# Global transformer pipeline (initialized once)
_sentiment_pipeline = None

def _initialize_transformer_pipeline():
    """Initialize the transformer-based sentiment pipeline"""
    global _sentiment_pipeline
    if _sentiment_pipeline is None:
        try:
            from transformers import pipeline
            # Using RoBERTa model fine-tuned on Twitter data (good for short texts)
            _sentiment_pipeline = pipeline(
                "sentiment-analysis",
                model="cardiffnlp/twitter-roberta-base-sentiment-latest",
                return_all_scores=True
            )
            logger.info("✅ Transformer-based sentiment analysis initialized")
        except Exception as e:
            logger.warning(f"⚠️ Transformer initialization failed: {e}. Falling back to TextBlob.")
            _sentiment_pipeline = "fallback"
    return _sentiment_pipeline

def analyze_sentiment(text: str) -> str:
    """
    Analyzes the sentiment of a given text string using advanced transformers.
    
    Primary: RoBERTa-based transformer model (high accuracy)
    Fallback: TextBlob (if transformers fail)
    
    Args:
        text: Input text to analyze
        
    Returns:
        str: 'Positive', 'Negative', or 'Neutral'
    """
    if not text or not isinstance(text, str):
        return "Neutral"
    
    # Clean text
    text = text.strip()
    if len(text) == 0:
        return "Neutral"
    
    # Try transformer-based analysis first
    try:
        pipeline = _initialize_transformer_pipeline()
        
        if pipeline != "fallback":
            # Use transformer model
            results = pipeline(text)
            
            # Parse results - model returns [{'label': 'negative', 'score': 0.8}, ...]
            # Find the label with highest confidence
            best_result = max(results[0], key=lambda x: x['score'])
            
            if best_result['label'] == 'positive':
                return "Positive"
            elif best_result['label'] == 'negative':
                return "Negative"
            else:  # neutral
                return "Neutral"
                
    except Exception as e:
        logger.warning(f"Transformer sentiment analysis failed: {e}. Using TextBlob fallback.")
    
    # Fallback to TextBlob (original implementation)
    try:
        analysis = TextBlob(text)
        if analysis.sentiment.polarity > 0.1:
            return "Positive"
        elif analysis.sentiment.polarity < -0.1:
            return "Negative"
        else:
            return "Neutral"
    except Exception as e:
        logger.error(f"Both sentiment analysis methods failed: {e}")
        return "Neutral"

def analyze_sentiment_with_confidence(text: str) -> dict:
    """
    Enhanced sentiment analysis that returns confidence scores.
    
    Returns:
        dict: {
            'sentiment': str,
            'confidence': float,
            'method': str
        }
    """
    if not text or not isinstance(text, str):
        return {'sentiment': 'Neutral', 'confidence': 0.0, 'method': 'default'}
    
    text = text.strip()
    if len(text) == 0:
        return {'sentiment': 'Neutral', 'confidence': 0.0, 'method': 'default'}
    
    # Try transformer analysis
    try:
        pipeline = _initialize_transformer_pipeline()
        
        if pipeline != "fallback":
            results = pipeline(text)
            best_result = max(results[0], key=lambda x: x['score'])
            
            sentiment_map = {
                'negative': 'Negative',
                'neutral': 'Neutral', 
                'positive': 'Positive'
            }
            
            return {
                'sentiment': sentiment_map.get(best_result['label'], 'Neutral'),
                'confidence': round(best_result['score'], 3),
                'method': 'transformer'
            }
    except Exception as e:
        logger.warning(f"Transformer analysis failed: {e}")
    
    # Fallback to TextBlob
    try:
        analysis = TextBlob(text)
        polarity = analysis.sentiment.polarity
        
        if polarity > 0.1:
            sentiment = "Positive"
        elif polarity < -0.1:
            sentiment = "Negative"
        else:
            sentiment = "Neutral"
            
        # Convert polarity (-1 to 1) to confidence (0 to 1)
        confidence = abs(polarity)
        
        return {
            'sentiment': sentiment,
            'confidence': round(confidence, 3),
            'method': 'textblob'
        }
    except Exception as e:
        logger.error(f"TextBlob analysis failed: {e}")
        return {'sentiment': 'Neutral', 'confidence': 0.0, 'method': 'error'}
