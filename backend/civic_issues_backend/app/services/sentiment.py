# in app/services/sentiment.py
from textblob import TextBlob

def analyze_sentiment(text: str) -> str:
    """
    Analyzes the sentiment of a given text string.
    Returns 'Positive', 'Negative', or 'Neutral'.
    """
    if not text or not isinstance(text, str):
        return "Neutral"

    analysis = TextBlob(text)
    if analysis.sentiment.polarity > 0.1:
        return "Positive"
    elif analysis.sentiment.polarity < -0.1:
        return "Negative"
    else:
        return "Neutral"
