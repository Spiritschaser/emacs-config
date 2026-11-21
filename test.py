print("Hello, world!")

sql = """
WITH greetings AS (
    SELECT 'Hello, world!' AS message
)
SELECT message
FROM greetings;
"""
